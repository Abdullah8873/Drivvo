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

/// Cells a spreadsheet would treat as a formula when the CSV is opened:
/// starting with `=`, `+`, `-`, `@`, a tab or a carriage return (after any
/// number of `'`, so escaping stays reversible).
final _formulaStart = RegExp(r"^'*[=+\-@\t\r]");

/// A number exactly as `num.toString()` writes it (`-12.5`, `1e-7`), which
/// is safe to leave alone even though it may start with `-`.
final _plainNumber = RegExp(r'^-?\d+(\.\d+)?([eE][+-]?\d+)?$');

/// [cell] made safe for a spreadsheet ("CSV/formula injection"): text a
/// user typed — a note, a place name, a shared member's record — that
/// starts like a formula (`=HYPERLINK("http://evil…")`, `@SUM(…)`,
/// `=cmd|…`) gets a leading `'`, which Excel/LibreOffice/Sheets show as
/// text instead of running it. Plain numbers are left as they are.
/// [csvUnescapeCell] undoes it exactly when MotoLog imports the file.
String csvSafeCell(String cell) =>
    _formulaStart.hasMatch(cell) && !_plainNumber.hasMatch(cell)
    ? "'$cell"
    : cell;

/// Reverses [csvSafeCell] (one leading `'` before a formula character).
String csvUnescapeCell(String cell) =>
    cell.startsWith("'") && _formulaStart.hasMatch(cell)
    ? cell.substring(1)
    : cell;

/// One [section] as CSV bytes (UTF-8 with a BOM). Commas, quotes and
/// newlines inside a cell (e.g. multi-line notes) are escaped by the `csv`
/// package the same way a spreadsheet app expects, and formula-like cells
/// by [csvSafeCell]. (The Excel export needs neither: its cells are typed
/// as text, which spreadsheets never evaluate.)
Uint8List sectionToCsvBytes(ExportSection section) {
  final text = _csvCodec.encode([
    section.headers,
    for (final row in section.rows) [for (final cell in row) csvSafeCell(cell)],
  ]);
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
