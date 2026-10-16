/// An export table as a PDF (A4 landscape, header row repeated on every page). A PDF is for reading and printing: it holds at
/// most [maxPdfRows] rows; Excel and CSV hold everything.
library;

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/export/export_table.dart';

const maxPdfRows = 5000;

Future<Uint8List> encodePdf(ExportTable t, {required String shopName, required DateTime now}) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Variable.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  final rows = t.rows.length > maxPdfRows ? t.rows.sublist(0, maxPdfRows) : t.rows;
  pw.TextStyle st(bool b) => pw.TextStyle(font: b ? bold : font, fontSize: 7.5);
  final money = {for (var c = 0; c < t.headers.length; c++) c: t.rows.isNotEmpty && t.rows.first.length > c && (t.rows.first[c] is Rupees || t.rows.first[c] is Qty || t.rows.first[c] is num)};

  final doc = pw.Document(title: t.name, author: shopName);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    maxPages: 400,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('${shopName.isEmpty ? '' : '$shopName  -  '}${t.name}', style: pw.TextStyle(font: bold, fontSize: 11)),
        pw.Text(plainCell(now), style: st(false)),
      ]),
    ),
    footer: (c) => pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('${c.pageNumber} / ${c.pagesCount}', style: st(false))),
    build: (_) => [
      pw.TableHelper.fromTextArray(
        headers: t.headers,
        data: [
          for (final r in rows) [for (final c in r) plainCell(c)],
        ],
        headerStyle: st(true),
        cellStyle: st(false),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {for (final e in money.entries) e.key: e.value ? pw.Alignment.centerRight : pw.Alignment.centerLeft},
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey400, width: 0.3)),
        headerAlignments: {for (final e in money.entries) e.key: e.value ? pw.Alignment.centerRight : pw.Alignment.centerLeft},
      ),
    ],
  ));
  return doc.save();
}
