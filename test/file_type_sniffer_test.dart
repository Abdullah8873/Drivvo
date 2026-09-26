import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/files/file_type_sniffer.dart';

Uint8List _bytes(List<int> head, [int pad = 32]) =>
    Uint8List.fromList([...head, ...List.filled(pad, 0)]);

void main() {
  test('recognises every type the attachments bucket accepts', () {
    expect(
      sniffAttachmentMimeType(_bytes([0xFF, 0xD8, 0xFF, 0xE0])),
      'image/jpeg',
    );
    expect(
      sniffAttachmentMimeType(
        _bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      ),
      'image/png',
    );
    expect(sniffAttachmentMimeType(_bytes('GIF89a'.codeUnits)), 'image/gif');
    expect(sniffAttachmentMimeType(_bytes('GIF87a'.codeUnits)), 'image/gif');
    expect(
      sniffAttachmentMimeType(
        _bytes([...'RIFF'.codeUnits, 1, 2, 3, 4, ...'WEBPVP8 '.codeUnits]),
      ),
      'image/webp',
    );
    expect(
      sniffAttachmentMimeType(_bytes([0, 0, 0, 24, ...'ftypheic'.codeUnits])),
      'image/heic',
    );
    expect(
      sniffAttachmentMimeType(_bytes([0, 0, 0, 24, ...'ftypmif1'.codeUnits])),
      'image/heif',
    );
    expect(
      sniffAttachmentMimeType(_bytes('%PDF-1.4'.codeUnits)),
      'application/pdf',
    );
  });

  test('a PDF header after a little junk still counts', () {
    expect(
      sniffAttachmentMimeType(
        _bytes([...List.filled(100, 0x20), ...'%PDF-1.7'.codeUnits]),
      ),
      'application/pdf',
    );
    expect(
      sniffAttachmentMimeType(
        _bytes([...List.filled(2000, 0x20), ...'%PDF-1.7'.codeUnits]),
      ),
      isNull,
    );
  });

  test('anything else is refused', () {
    expect(sniffAttachmentMimeType(Uint8List(0)), isNull);
    expect(
      sniffAttachmentMimeType(_bytes('<svg onload=alert(1)>'.codeUnits)),
      isNull,
    );
    expect(
      sniffAttachmentMimeType(_bytes('<!DOCTYPE html>'.codeUnits)),
      isNull,
    );
    expect(sniffAttachmentMimeType(_bytes('PK\x03\x04'.codeUnits)), isNull);
    expect(
      sniffAttachmentMimeType(_bytes([0, 0, 0, 24, ...'ftypavif'.codeUnits])),
      isNull,
    );
    expect(sniffAttachmentMimeType(_bytes([0xFF, 0xD8])), isNull);
  });
}
