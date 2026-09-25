import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a file's bytes to the platform so the user can save or send it —
/// the mobile/desktop equivalent of a browser's `Blob` + `<a download>`.
///
/// Behind an interface (like a small repository) so export/backup screens
/// can be widget-tested with a fake instead of touching the real share
/// sheet: read it with `ref.watch(fileSharerProvider)` and override
/// [fileSharerProvider] in tests.
abstract class FileSharer {
  /// Shares [bytes] as a file named [filename] with MIME type [mimeType].
  /// On web this triggers a download; on Android/iOS it opens the share
  /// sheet (Files, Drive, email, …); on desktop it opens a save dialog.
  Future<void> shareBytes({
    required String filename,
    required Uint8List bytes,
    required String mimeType,
    String? subject,
  });

  /// Shares plain [text] (e.g. "Share app", feedback without an email
  /// client) through the platform share sheet — no file involved.
  Future<void> shareText(String text, {String? subject});
}

/// Real implementation, backed by `share_plus`.
class SharePlusFileSharer implements FileSharer {
  const SharePlusFileSharer();

  @override
  Future<void> shareBytes({
    required String filename,
    required Uint8List bytes,
    required String mimeType,
    String? subject,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: filename, mimeType: mimeType)],
        // `XFile.fromData`'s `name` is only honoured on web; every other
        // platform needs the override to keep the extension/name intact.
        fileNameOverrides: [filename],
        subject: subject,
      ),
    );
  }

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
  }
}

/// Overridden in tests with a fake that records calls instead of opening
/// the real share sheet.
final fileSharerProvider = Provider<FileSharer>(
  (ref) => const SharePlusFileSharer(),
);
