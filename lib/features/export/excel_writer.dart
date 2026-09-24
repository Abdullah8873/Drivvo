import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

import 'export_rows.dart';

/// One .xlsx workbook with one sheet per section, header row bold — the
/// Excel equivalent of what `csv_writer.dart` does for CSV/zip.
Uint8List buildExcelBytes(List<ExportSection> sections) {
  final workbook = xls.Excel.createExcel();
  // `Excel.createExcel()` starts with one default sheet; drop it once the
  // real sheets are in, so the workbook doesn't ship an empty extra tab.
  final defaultSheetName = workbook.getDefaultSheet();

  for (final section in sections) {
    final sheet = workbook[_sheetName(section.title)];
    for (var c = 0; c < section.headers.length; c++) {
      final cell = sheet.cell(
        xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.value = xls.TextCellValue(section.headers[c]);
      cell.cellStyle = xls.CellStyle(bold: true);
    }
    for (final row in section.rows) {
      sheet.appendRow([for (final cell in row) xls.TextCellValue(cell)]);
    }
  }

  if (defaultSheetName != null && workbook.sheets.length > 1) {
    workbook.delete(defaultSheetName);
  }

  final bytes = workbook.encode();
  return Uint8List.fromList(bytes ?? const []);
}

/// Excel sheet names can't exceed 31 characters or contain `: \ / ? * [ ]`;
/// every title here is short and plain, but sanitize anyway in case a
/// future record type isn't.
String _sheetName(String title) {
  final cleaned = title.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
  return cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
}
