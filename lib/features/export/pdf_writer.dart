import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/theme/record_module.dart';
import 'export_rows.dart';

/// Modules whose `moneyTotal` is meaningful (Reading/Reminder don't carry a
/// cost, so their summary row shows "-" instead of a misleading "0").
const _moneyModules = {
  RecordModule.refueling,
  RecordModule.expense,
  RecordModule.service,
  RecordModule.income,
  RecordModule.route,
};

/// A4-portrait PDF report: title, vehicle(s)/period header, a totals
/// summary (count + money total per record type), then one paginated table
/// per [sections] entry. Built with the `pdf` package's own `Document`/
/// `MultiPage` widgets (not `printing`, since this only needs the bytes —
/// `FileSharer` hands them to the platform).
Future<Uint8List> buildPdfBytes({
  required List<ExportSection> sections,
  required String vehicleLabel,
  required String periodLabel,
  required String currencyCode,
}) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => context.pageNumber != 1
          ? pw.SizedBox()
          : pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MotoLog export',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Vehicle: $vehicleLabel'),
                pw.Text('Period: $periodLabel'),
                pw.Divider(),
              ],
            ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        if (sections.isNotEmpty) ...[
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Type', 'Count', 'Total ($currencyCode)'],
            data: [
              for (final s in sections)
                [
                  s.title,
                  s.recordCount.toString(),
                  _moneyModules.contains(s.module)
                      ? s.moneyTotal.toString()
                      : '-',
                ],
            ],
          ),
          pw.SizedBox(height: 18),
        ],
        for (final section in sections) ...[
          pw.Text(
            section.title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          section.rows.isEmpty
              ? pw.Text(
                  'No records.',
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                )
              : pw.TableHelper.fromTextArray(
                  headers: section.headers,
                  data: section.rows,
                  cellStyle: pw.TextStyle(fontSize: 7),
                  headerStyle: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellAlignment: pw.Alignment.centerLeft,
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                ),
          pw.SizedBox(height: 18),
        ],
      ],
    ),
  );

  return doc.save();
}
