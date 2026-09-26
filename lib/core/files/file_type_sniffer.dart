import 'dart:typed_data';

/// The attachment type [bytes] really are, read from the file's first
/// bytes ("magic numbers"), or null when it's none of the types the
/// `attachments` Storage bucket accepts (JPEG, PNG, GIF, WebP, HEIC/HEIF,
/// PDF).
///
/// Why: the picker's file extension and MIME type are only claims — a file
/// named `bill.pdf` can hold anything. Checking the content before a file
/// is attached means what gets uploaded (and later opened on another
/// member's device) is what its type says. Like checking `file.type` *and*
/// the first bytes of an upload on a web server.
String? sniffAttachmentMimeType(Uint8List bytes) {
  bool at(int offset, List<int> magic) {
    if (bytes.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[offset + i] != magic[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (at(0, _ascii('GIF87a')) || at(0, _ascii('GIF89a'))) return 'image/gif';
  if (at(0, _ascii('RIFF')) && at(8, _ascii('WEBP'))) return 'image/webp';
  if (at(4, _ascii('ftyp')) && bytes.length >= 12) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (const {
      'heic',
      'heix',
      'hevc',
      'hevx',
      'heim',
      'heis',
    }.contains(brand)) {
      return 'image/heic';
    }
    if (const {'mif1', 'msf1', 'heif'}.contains(brand)) return 'image/heif';
    return null;
  }
  // The PDF header may follow a little junk (the spec tolerates it within
  // the first 1024 bytes, and real scanners/printers produce it).
  final head = bytes.length < 1024 ? bytes : bytes.sublist(0, 1024);
  final pdf = _ascii('%PDF-');
  for (var i = 0; i + pdf.length <= head.length; i++) {
    if (at(i, pdf)) return 'application/pdf';
  }
  return null;
}

List<int> _ascii(String s) => s.codeUnits;
