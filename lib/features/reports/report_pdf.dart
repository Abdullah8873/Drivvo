import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One-page PDF wrapping a captured report screenshot — used by the Reports
/// share sheet's "Share as PDF" option (`ReportsScreen`). Kept separate from
/// `features/export/pdf_writer.dart`, which builds tabular record exports,
/// not a single embedded image.
Future<Uint8List> buildReportImagePdf({
  required Uint8List pngBytes,
  required String title,
}) async {
  final doc = pw.Document();
  final image = pw.MemoryImage(pngBytes);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Expanded(
            child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}
