import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/date_fmt.dart';
import '../../strings.dart';

/// One small A4 page for "Test print": the shop name, the date and a frame near the paper edge, so the person can see at once
/// that the printer works and that nothing is cut off.
Future<Uint8List> buildTestPagePdf({required String shopName, required DateTime now, required String printerName, required Strings l}) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Variable.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  final doc = pw.Document(title: l.printTestTitle);
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(24),
    build: (_) => pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
      child: pw.Center(
        child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
          pw.Text(shopName.isEmpty ? 'ASK ERP 2.0' : shopName, style: pw.TextStyle(font: bold, fontSize: 22)),
          pw.SizedBox(height: 8),
          pw.Text(l.printTestTitle, style: pw.TextStyle(font: bold, fontSize: 16)),
          pw.SizedBox(height: 6),
          pw.Text(l.printTestBody, style: pw.TextStyle(font: font, fontSize: 11)),
          pw.SizedBox(height: 10),
          pw.Text('${formatDateTime(now)}   ${printerName.isEmpty ? l.printDefault : printerName}', style: pw.TextStyle(font: font, fontSize: 10)),
          pw.SizedBox(height: 18),
          pw.Container(
            width: 360,
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
            child: pw.Column(children: [
              pw.Container(color: const PdfColor.fromInt(0xFFE8E8E8), padding: const pw.EdgeInsets.all(4), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [for (final h in ['Sl.No', 'Goods', 'Qty', 'Rate', 'Total']) pw.Text(h, style: pw.TextStyle(font: bold, fontSize: 8))])),
              pw.Divider(height: 0.5, thickness: 0.5),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('0123456789   Rs. 1,23,456.78   (7 pt)', style: pw.TextStyle(font: font, fontSize: 7))),
            ]),
          ),
          pw.SizedBox(height: 4),
          pw.Text(l.printTestGrey, style: pw.TextStyle(font: font, fontSize: 9)),
        ]),
      ),
    ),
  ));
  return doc.save();
}
