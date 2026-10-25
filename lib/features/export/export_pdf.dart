/// An export table as a ready-to-print PDF report: the shop's logo, name and details, the report title and date, figure boxes (totals), a numbered table
/// whose header repeats on every page, a totals row, and "Page x of y" at the foot. A PDF is for reading and printing: it holds at most [maxPdfRows] rows;
/// Excel and CSV hold everything. The page turns sideways when the table is wide.
library;

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/date_fmt.dart';
import '../../core/logo_image.dart';
import '../../core/money.dart';
import '../../domain/export/export_table.dart';
import '../../fake/shop_profile.dart';

const maxPdfRows = 5000;

bool _isNumber(Object? v) => v is Rupees || v is Qty || v is num;

/// What one cell shows on paper: money with Indian digit grouping, quantities without trailing zeros, dates as dd-mm-yyyy.
String pdfCell(Object? v) => switch (v) {
      null => '',
      Rupees r => formatPaise(r.paise),
      Qty q => formatQty(q.milli),
      int i => groupIndian(i),
      double d => d == d.roundToDouble() ? d.toInt().toString() : d.toString(),
      DateTime d => formatDate(d),
      _ => v.toString(),
    };

Future<Uint8List> encodePdf(ExportTable t, {required String shopName, required DateTime now, ShopProfile? shop}) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Variable.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  final shown = t.rows.length > maxPdfRows ? t.rows.sublist(0, maxPdfRows) : t.rows;

  // the shop's own logo, else the program's
  final own = shop == null ? null : logoBytes(shop.logoPng);
  Uint8List? logo = own;
  if (logo == null) {
    try {
      logo = (await rootBundle.load('assets/branding/ask-logo-256.png')).buffer.asUint8List();
    } catch (_) {
      logo = null;
    }
  }
  final name = shop?.name.trim().isNotEmpty == true ? shop!.name.trim() : shopName;
  final details = <String>[
    if (shop != null && shop.address.trim().isNotEmpty) shop.address.trim(),
    [if (shop != null && shop.phone.trim().isNotEmpty) 'Phone: ${shop.phone.trim()}', if (shop != null && shop.gstin.trim().isNotEmpty) 'GSTIN: ${shop.gstin.trim()}'].join('    '),
  ].where((x) => x.isNotEmpty).toList();

  // columns: which are numbers (right-aligned), and how wide each needs to be
  final cols = t.headers.length;
  final numeric = [for (var c = 0; c < cols; c++) shown.any((r) => c < r.length && _isNumber(r[c])) || (t.totalsRow != null && c < t.totalsRow!.length && _isNumber(t.totalsRow![c]))];
  final sample = shown.length > 300 ? shown.sublist(0, 300) : shown;
  final chars = <double>[
    for (var c = 0; c < cols; c++)
      () {
        var m = t.headers[c].length.toDouble();
        for (final r in sample) {
          if (c < r.length) {
            final n = pdfCell(r[c]).length.toDouble();
            if (n > m) m = n;
          }
        }
        if (t.totalsRow != null && c < t.totalsRow!.length) {
          final n = pdfCell(t.totalsRow![c]).length.toDouble();
          if (n > m) m = n;
        }
        return m.clamp(4, numeric[c] ? 16 : 30).toDouble();
      }(),
  ];
  const serialW = 26.0;
  final need = serialW + chars.fold<double>(0, (s, x) => s + x * 4.1 + 7);
  final landscape = need > 520;
  final format = landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
  final size = landscape ? 7.5 : 8.0;

  pw.TextStyle st({bool b = false, double? sz, PdfColor? color}) => pw.TextStyle(font: b ? bold : font, fontSize: sz ?? size, color: color);
  const ink = PdfColor.fromInt(0xFF1F2937);
  const soft = PdfColor.fromInt(0xFF6B7280);
  const band = PdfColor.fromInt(0xFFF3F4F6);
  const head = PdfColor.fromInt(0xFF1F2937);
  const line = PdfColor.fromInt(0xFFD1D5DB);

  final stamp = '${formatDate(now)}  ${formatTime(now)}';

  pw.Widget logoBox(double h) => logo == null ? pw.SizedBox(width: 0) : pw.Padding(padding: const pw.EdgeInsets.only(right: 10), child: pw.Image(pw.MemoryImage(logo), height: h));

  final bigHeader = pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: ink, width: 1))),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      logoBox(46),
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(name.isEmpty ? 'ASK ERP 2.0' : name, style: st(b: true, sz: 16, color: ink)),
          for (final d in details) pw.Padding(padding: const pw.EdgeInsets.only(top: 1.5), child: pw.Text(d, style: st(sz: 8.5, color: soft))),
        ]),
      ),
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text('${t.name} report', style: st(b: true, sz: 15, color: ink)),
        pw.SizedBox(height: 2),
        pw.Text('Generated: $stamp', style: st(sz: 8.5, color: soft)),
        pw.Text('${shown.length} ${shown.length == 1 ? 'row' : 'rows'}${t.rows.length > shown.length ? ' of ${t.rows.length}' : ''}', style: st(sz: 8.5, color: soft)),
      ]),
    ]),
  );

  pw.Widget figure((String, String) f) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: pw.BoxDecoration(color: band, borderRadius: pw.BorderRadius.circular(4), border: pw.Border.all(color: line, width: 0.5)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisSize: pw.MainAxisSize.min, children: [
          pw.Text(f.$1, style: st(sz: 7.5, color: soft)),
          pw.SizedBox(height: 2),
          pw.Text(f.$2, style: st(b: true, sz: 12, color: ink)),
        ]),
      );

  pw.Widget cell(String s, {bool right = false, bool b = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 2.6),
        child: pw.Text(s, textAlign: right ? pw.TextAlign.right : pw.TextAlign.left, style: st(b: b, color: color)),
      );

  // the first text column of the totals row says "Total" (unless the report gave it its own words)
  List<Object?>? totals = t.totalsRow;
  if (totals != null && !totals.any((x) => x is String && x.isNotEmpty)) {
    final firstText = [for (var c = 0; c < cols; c++) if (!numeric[c]) c].firstOrNull;
    if (firstText != null && firstText < totals.length) {
      totals = [...totals]..[firstText] = 'Total';
    }
  }

  final rowsOut = <pw.TableRow>[
    pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: head),
      children: [cell('S.No', b: true, color: PdfColors.white), for (var c = 0; c < cols; c++) cell(t.headers[c], b: true, right: numeric[c], color: PdfColors.white)],
    ),
    for (var i = 0; i < shown.length; i++)
      pw.TableRow(
        decoration: i.isOdd ? const pw.BoxDecoration(color: band) : null,
        children: [
          cell('${i + 1}', right: true, color: soft),
          for (var c = 0; c < cols; c++) cell(c < shown[i].length ? pdfCell(shown[i][c]) : '', right: numeric[c]),
        ],
      ),
    if (totals != null)
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE5E7EB), border: pw.Border(top: pw.BorderSide(color: ink, width: 1), bottom: pw.BorderSide(color: ink, width: 1))),
        children: [cell(''), for (var c = 0; c < cols; c++) cell(c < totals.length ? pdfCell(totals[c]) : '', right: numeric[c], b: true)],
      ),
  ];

  final doc = pw.Document(title: '${t.name} report', author: name);
  doc.addPage(pw.MultiPage(
    pageFormat: format,
    maxPages: 400,
    margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 30),
    header: (c) => c.pageNumber == 1
        ? pw.SizedBox()
        : pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Row(children: [logoBox(18), pw.Text(name, style: st(b: true, sz: 10, color: ink))]),
              pw.Text('${t.name} report  -  $stamp', style: st(sz: 8.5, color: soft)),
            ]),
          ),
    footer: (c) => pw.Container(
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: line, width: 0.5))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('${name.isEmpty ? '' : '$name  -  '}${t.name}', style: st(sz: 7.5, color: soft)),
        pw.Text('Made with ASK ERP 2.0', style: st(sz: 7.5, color: soft)),
        pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: st(sz: 7.5, color: soft)),
      ]),
    ),
    build: (_) => [
      bigHeader,
      pw.SizedBox(height: 10),
      if (t.summary.isNotEmpty) ...[
        pw.Wrap(spacing: 8, runSpacing: 8, children: [for (final f in t.summary) figure(f)]),
        pw.SizedBox(height: 10),
      ],
      if (t.note.isNotEmpty) ...[pw.Text(t.note, style: st(sz: 8, color: soft)), pw.SizedBox(height: 6)],
      if (t.rows.length > shown.length) ...[pw.Text('Only the first $maxPdfRows of ${t.rows.length} rows are in this PDF. Excel or CSV holds all of them.', style: st(sz: 8, color: soft)), pw.SizedBox(height: 6)],
      pw.Table(
        border: const pw.TableBorder(left: pw.BorderSide(color: line, width: 0.5), right: pw.BorderSide(color: line, width: 0.5), bottom: pw.BorderSide(color: line, width: 0.5), horizontalInside: pw.BorderSide(color: line, width: 0.3), verticalInside: pw.BorderSide(color: line, width: 0.3)),
        columnWidths: {
          0: const pw.FixedColumnWidth(serialW),
          for (var c = 0; c < cols; c++) c + 1: pw.FlexColumnWidth(chars[c] * 4.1 + 7),
        },
        children: rowsOut,
      ),
    ],
  ));
  return doc.save();
}
