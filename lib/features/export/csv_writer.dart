import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart' as csv;

import 'export_rows.dart';

/// `addBom: true` prepends a UTF-8 byte-order-mark character to the encoded
/// string, so Excel (which otherwise guesses the system codepage) reads
/// accented characters correctly — the same trick a web app uses when it
/// hands `Blob(['﻿', csvText])` to `<a download>`.
final _csvCodec = csv.Csv(addBom: true);

/// One [section] as CSV bytes (UTF-8 with a BOM). Commas, quotes and
/// newlines inside a cell (e.g. multi-line notes) are escaped by the `csv`
/// package the same way a spreadsheet app expects.
Uint8List sectionToCsvBytes(ExportSection section) {
  final text = _csvCodec.encode([section.headers, ...section.rows]);
  return Uint8List.fromList(utf8.encode(text));
}

/// `sections.length == 1`: plain CSV bytes for that one section.
/// Otherwise: a .zip with one `<title>.csv` per section (each with its own
/// BOM), since a single CSV can only hold one table.
Uint8List buildCsvOrZipBytes(List<ExportSection> sections) {
  if (sections.length == 1) return sectionToCsvBytes(sections.single);

  final archive = Archive();
  for (final section in sections) {
    final bytes = sectionToCsvBytes(section);
    archive.addFile(ArchiveFile('${section.title}.csv', bytes.length, bytes));
  }
  final zipped = ZipEncoder().encode(archive) ?? const <int>[];
  return Uint8List.fromList(zipped);
}
