import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/theme/record_module.dart';
import 'package:motolog/features/export/csv_writer.dart';
import 'package:motolog/features/export/excel_writer.dart';
import 'package:motolog/features/export/export_rows.dart';
import 'package:motolog/features/export/pdf_writer.dart';

ExportSection _section(
  String title,
  RecordModule module,
  List<List<String>> rows,
) {
  return ExportSection(
    module: module,
    title: title,
    headers: const ['A', 'B'],
    rows: rows,
    recordCount: rows.length,
    moneyTotal: 0,
  );
}

void main() {
  group('CSV writer', () {
    test('escapes commas, quotes and newlines, and adds a BOM', () {
      final section = _section('Reading', RecordModule.reading, [
        ['has, comma', 'has "quote"'],
        ['multi\nline', 'plain'],
      ]);
      final bytes = sectionToCsvBytes(section);

      // UTF-8 BOM.
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      final text = utf8.decode(bytes.skip(3).toList());
      expect(text, contains('"has, comma"'));
      expect(text, contains('"has ""quote"""'));
      expect(text, contains('"multi\nline"'));
    });

    test('single section produces plain CSV bytes (not a zip)', () {
      final section = _section('Reading', RecordModule.reading, [
        ['x', 'y'],
      ]);
      final bytes = buildCsvOrZipBytes([section]);
      // A CSV starts with its (BOM-prefixed) header text, not the zip magic
      // number (0x50 0x4B).
      expect(bytes[0], isNot(0x50));
    });

    test('several sections bundle into a zip with one CSV per type', () {
      final sections = [
        _section('Refueling', RecordModule.refueling, [
          ['1', '2'],
        ]),
        _section('Reading', RecordModule.reading, [
          ['3', '4'],
        ]),
      ];
      final bytes = buildCsvOrZipBytes(sections);
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(
        archive.files.map((f) => f.name),
        unorderedEquals(['Refueling.csv', 'Reading.csv']),
      );
      for (final file in archive.files) {
        final text = utf8.decode((file.content as List<int>).skip(3).toList());
        expect(text, contains('A,B'));
      }
    });
  });

  group('Excel writer', () {
    test('one sheet per section, header row bold, readable back', () {
      final sections = [
        _section('Refueling', RecordModule.refueling, [
          ['293.03', '5.125'],
        ]),
        _section('Reading', RecordModule.reading, [
          ['x', 'y'],
        ]),
      ];
      final bytes = buildExcelBytes(sections);
      final workbook = xls.Excel.decodeBytes(bytes);

      expect(workbook.tables.keys, unorderedEquals(['Refueling', 'Reading']));
      final sheet = workbook.tables['Refueling']!;
      expect(sheet.rows.length, 2); // header + 1 data row
      expect(sheet.rows[0][0]?.value.toString(), 'A');
      expect(sheet.rows[0][0]?.cellStyle?.isBold, isTrue);
      expect(sheet.rows[1][0]?.value.toString(), '293.03');
    });
  });

  group('PDF writer', () {
    test('produces a valid PDF (starts with the %PDF magic bytes)', () async {
      final sections = [
        _section('Refueling', RecordModule.refueling, [
          ['1', '2'],
        ]),
      ];
      final bytes = await buildPdfBytes(
        sections: sections,
        vehicleLabel: 'Honda',
        periodLabel: 'All time',
        currencyCode: 'PKR',
      );
      expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    });

    test('handles an empty section list without crashing', () async {
      final bytes = await buildPdfBytes(
        sections: const [],
        vehicleLabel: 'All vehicles',
        periodLabel: 'All time',
        currencyCode: 'PKR',
      );
      expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    });
  });

  group('CSV formula injection', () {
    test('formula-like cells get a leading quote, numbers do not', () {
      expect(csvSafeCell('=HYPERLINK("http://x")'), '\'=HYPERLINK("http://x")');
      expect(csvSafeCell('+1+cmd|calc'), "'+1+cmd|calc");
      expect(csvSafeCell('-2+3'), "'-2+3");
      expect(csvSafeCell('@SUM(A1)'), "'@SUM(A1)");
      expect(csvSafeCell('\tx'), "'\tx");
      expect(csvSafeCell('\r=x'), "'\r=x");
      expect(csvSafeCell("'=x"), "''=x");
      for (final safe in [
        '-12.5',
        '-3',
        '1e-7',
        '-1.5e+21',
        'Oil change',
        '',
        "'quoted",
      ]) {
        expect(csvSafeCell(safe), safe, reason: safe);
      }
    });

    test('unescaping restores every original exactly', () {
      for (final original in [
        '=1+1',
        "'=1+1",
        "''@x",
        '-5',
        '-5+1',
        "'plain",
        'plain',
        '',
      ]) {
        expect(
          csvUnescapeCell(csvSafeCell(original)),
          original,
          reason: original,
        );
      }
    });

    test('the CSV writer escapes cells but not headers', () {
      final section = _section('Reading', RecordModule.reading, [
        ['=cmd|" /C calc"!A0', '-7'],
      ]);
      final text = utf8.decode(sectionToCsvBytes(section).skip(3).toList());
      expect(text, startsWith('A,B'));
      expect(text, contains("'=cmd|"));
      expect(text, contains(',-7'));
    });
  });
}
