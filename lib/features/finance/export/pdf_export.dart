import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Everything the PDF shows, already formatted in the app language. The PDF is
/// tables only: exact figures, a small file, nothing to misread in a picture.
class ReportPdfData {
  const ReportPdfData({
    required this.localeCode,
    required this.title,
    required this.range,
    required this.scope,
    required this.summaryTitle,
    required this.summary,
    required this.categoryTitle,
    required this.categories,
    required this.debtsTitle,
    required this.debts,
    this.note,
  });

  final String localeCode;
  final String title;
  final String range;
  final String scope;
  final String summaryTitle;
  final List<(String, String)> summary;
  final String categoryTitle;
  final List<(String, String)> categories;
  final String debtsTitle;
  final List<(String, String)> debts;

  /// The "left out, no rate" line, when the report had to skip rows.
  final String? note;
}

Future<pw.Font> _font(String name) async => pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-$name.ttf'));

/// An A4 report in the bundled Vazirmatn, right to left for Arabic and Kurdish.
Future<Uint8List> reportPdf(ReportPdfData d) async {
  final rtl = d.localeCode == 'ar' || d.localeCode == 'ckb';
  final doc = pw.Document(
    title: d.title,
    theme: pw.ThemeData.withFont(base: await _font('Regular'), bold: await _font('Bold')),
  );
  const ink = PdfColor.fromInt(0xFF0B1224);
  const muted = PdfColor.fromInt(0xFF5B667D);
  const rule = PdfColor.fromInt(0xFFD5DAE5);

  pw.Widget section(String title, List<(String, String)> rows) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(height: 18),
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: ink),
      ),
      pw.SizedBox(height: 6),
      pw.Table(
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: rule, width: 0.5)),
        columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
        children: [
          for (final (label, value) in rows)
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text(label)),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 5),
                  child: pw.Text(
                    value,
                    textDirection: pw.TextDirection.ltr,
                    textAlign: rtl ? pw.TextAlign.left : pw.TextAlign.right,
                  ),
                ),
              ],
            ),
        ],
      ),
    ],
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      build: (_) => [
        pw.Text(
          d.title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: ink),
        ),
        pw.SizedBox(height: 4),
        pw.Text(d.range, style: const pw.TextStyle(color: muted)),
        pw.Text(d.scope, style: const pw.TextStyle(color: muted)),
        if (d.note != null) ...[pw.SizedBox(height: 6), pw.Text(d.note!, style: const pw.TextStyle(color: muted))],
        section(d.summaryTitle, d.summary),
        if (d.categories.isNotEmpty) section(d.categoryTitle, d.categories),
        if (d.debts.isNotEmpty) section(d.debtsTitle, d.debts),
      ],
    ),
  );
  return doc.save();
}
