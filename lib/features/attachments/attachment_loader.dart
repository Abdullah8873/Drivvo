import 'dart:typed_data';

import '../../core/db/app_database.dart';
import '../../core/sync/remote_file_store.dart';
import 'attachment_queries.dart';

/// Why an attachment's bytes can't be shown; [message] is ready for the UI.
class AttachmentUnavailable implements Exception {
  const AttachmentUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The bytes of a saved attachment: the local copy when there is one,
/// otherwise downloaded from cloud storage on demand and cached locally
/// (like a service worker's cache-first fetch).
///
/// Throws [AttachmentUnavailable] when the file only exists on another
/// device ([Attachment.storagePath] still null), when this device can't
/// reach the cloud ([files] null or [signedIn] false), or when the download
/// fails.
Future<Uint8List> loadAttachmentBytes(
  AppDatabase db,
  Attachment attachment, {
  required RemoteFileStore? files,
  required bool signedIn,
}) async {
  final local = await db.localAttachmentBytes(attachment.id);
  if (local != null) return local;
  final path = attachment.storagePath;
  if (path == null) {
    throw const AttachmentUnavailable(
      "This file isn't on this device and hasn't been uploaded yet. Sync "
      'the device that added it, then try again.',
    );
  }
  if (files == null || !signedIn) {
    throw const AttachmentUnavailable(
      'This file is stored in the cloud. Sign in to download it.',
    );
  }
  final Uint8List bytes;
  try {
    bytes = await files.download(path);
  } catch (_) {
    throw const AttachmentUnavailable(
      "Couldn't download this file. Check your internet connection and try "
      'again.',
    );
  }
  await db.cacheAttachmentBytes(attachment.id, bytes);
  return bytes;
}
