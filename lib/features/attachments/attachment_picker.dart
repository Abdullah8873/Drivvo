import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/sync/remote_file_store.dart';
import 'attachment_queries.dart';

/// Thrown by an [AttachmentPicker] when the picked file is bigger than
/// [RemoteFileStore.maxBytes] — checked from the file's size before its
/// bytes are read, so a huge PDF never has to fit in memory.
class AttachmentTooLargeException implements Exception {
  const AttachmentTooLargeException();
}

/// Where attachments come from: the camera, the photo gallery or a PDF
/// file. Behind an interface (like [FileSharer]) so forms can be
/// widget-tested with a fake instead of opening real system pickers.
abstract class AttachmentPicker {
  /// Whether "Take photo" is offered (phones only: web/desktop have no
  /// reliable camera capture through `image_picker`).
  bool get canTakePhoto;

  /// Each returns null when the user cancelled.
  Future<PendingAttachment?> takePhoto();
  Future<PendingAttachment?> pickImage();
  Future<PendingAttachment?> pickPdf();
}

/// Real implementation: `image_picker` for photos (downscaled to 1920 px
/// and JPEG quality 80, so a phone photo is typically well under 1 MB) and
/// `file_picker` for PDFs (which returns bytes on every platform, the web
/// included).
class DeviceAttachmentPicker implements AttachmentPicker {
  const DeviceAttachmentPicker();

  @override
  bool get canTakePhoto =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<PendingAttachment?> takePhoto() => _image(ImageSource.camera);

  @override
  Future<PendingAttachment?> pickImage() => _image(ImageSource.gallery);

  Future<PendingAttachment?> _image(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 80,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    // image_picker on web renames resized images to `scaled_<name>`.
    final picked = file.name.replaceFirst(RegExp(r'^scaled_'), '');
    final name = picked.isEmpty ? 'photo.jpg' : picked;
    return PendingAttachment(
      fileName: name,
      mimeType: file.mimeType ?? mimeTypeForName(name),
      bytes: bytes,
    );
  }

  @override
  Future<PendingAttachment?> pickPdf() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a PDF',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null) return null;
    final size = file.lengthSync() ?? await file.length();
    if (size != null && size > RemoteFileStore.maxBytes) {
      throw const AttachmentTooLargeException();
    }
    return PendingAttachment(
      fileName: file.name,
      mimeType: 'application/pdf',
      bytes: await file.readAsBytes(),
    );
  }
}

/// MIME type guessed from a file name's extension (images and PDF — the
/// only types the Storage bucket accepts).
String mimeTypeForName(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'pdf' => 'application/pdf',
    _ => 'image/jpeg', // image_picker output without an extension
  };
}

/// Overridden in tests with a fake picker.
final attachmentPickerProvider = Provider<AttachmentPicker>(
  (ref) => const DeviceAttachmentPicker(),
);
