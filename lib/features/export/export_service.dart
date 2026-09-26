import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../core/files/file_sharer.dart';
import 'csv_writer.dart';
import 'excel_writer.dart';
import 'export_data.dart';
import 'export_models.dart';
import 'export_rows.dart';
import 'pdf_writer.dart';

final _fileDateFmt = DateFormat('yyyyMMdd');
final _periodDateFmt = DateFormat('yyyy-MM-dd');

/// Turns [ExportOptions] into a file and hands it to [sharer] — the one
/// place that ties the data loader, the pure row builders and a format
/// writer together. Called from the Export screen; kept out of the widget
/// so the orchestration itself doesn't need a `BuildContext`.
class ExportService {
  const ExportService(this.sharer);

  final FileSharer sharer;

  /// [currencyCode] comes from the app's Settings (`AppSettings.currencyCode`
  /// — the Export screen doesn't collect its own currency) and is written
  /// into a currency column instead of a symbol in numeric cells (see the
  /// column layout note in export_rows.dart).
  Future<void> export(
    AppDatabase db,
    ExportOptions options,
    String currencyCode,
  ) async {
    final data = await loadExportData(db, options);
    final sections = buildExportSections(data, options.modules, currencyCode);
    final bytes = await _buildBytes(
      options.format,
      sections,
      options,
      currencyCode,
    );
    if (bytes.isEmpty) return;
    await sharer.shareBytes(
      filename: _filename(options),
      bytes: bytes,
      mimeType: _mimeType(options),
    );
  }

  Future<Uint8List> _buildBytes(
    ExportFormat format,
    List<ExportSection> sections,
    ExportOptions options,
    String currencyCode,
  ) async {
    switch (format) {
      case ExportFormat.csv:
        return buildCsvOrZipBytes(sections);
      case ExportFormat.excel:
        return buildExcelBytes(sections);
      case ExportFormat.pdf:
        return buildPdfBytes(
          sections: sections,
          vehicleLabel: options.vehicleLabel,
          periodLabel: options.period == null
              ? 'All time'
              : '${_periodDateFmt.format(options.period!.from)} – '
                    '${_periodDateFmt.format(options.period!.to)}',
          currencyCode: currencyCode,
        );
    }
  }

  String _mimeType(ExportOptions options) {
    if (options.format == ExportFormat.csv && options.modules.length > 1) {
      return 'application/zip';
    }
    return switch (options.format) {
      ExportFormat.csv => 'text/csv',
      ExportFormat.excel =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ExportFormat.pdf => 'application/pdf',
    };
  }

  String _filename(ExportOptions options) {
    final vehiclePart = options.vehicleIds.length == 1
        ? _slug(options.vehicleLabel)
        : 'all';
    final datePart = _fileDateFmt.format(DateTime.now());
    final ext = options.format == ExportFormat.csv && options.modules.length > 1
        ? 'zip'
        : options.format.fileExtension;
    // A single-type CSV names its record type (`…-expense.csv`): Expense,
    // Service and Income share one column layout, so the CSV importer reads
    // the type from the file name (inside a .zip it's the entry name).
    final typePart =
        options.format == ExportFormat.csv && options.modules.length == 1
        ? '-${options.modules.single.name}'
        : '';
    return 'motolog-$vehiclePart-$datePart$typePart.$ext';
  }

  static String _slug(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'vehicle' : cleaned;
  }
}

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(ref.watch(fileSharerProvider)),
);
