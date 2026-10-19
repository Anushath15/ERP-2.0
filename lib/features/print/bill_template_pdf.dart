import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/logo_image.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart' show PaperSize, PrintTextSize;
import 'bill_template.dart';
import 'print_layout.dart';

/// Fixed widths (points) of the item columns; the Goods column takes the rest.
const templateColWidths = <double>[38, 0, 42, 54, 30, 36, 62, 36, 56];

/// The bill / estimate in the shop's template as a real PDF (A4 or A5, several pages when the bill is long).
Future<Uint8List> buildTemplatePdf({required BillTemplate t, required String number, required PaperSize paper, required ShopProfile shop, required PrintTextSize size}) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Variable.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  final m = PrintMetrics.of(size);
  final a5 = paper == PaperSize.a5;
  // small rows, so that many products fit on one page (paper is not wasted)
  final fs = (a5 ? m.row - 3.5 : m.row - 2.0).clamp(6.0, 12.0).toDouble();
  final margin = paperMarginPt(paper);
  pw.TextStyle st({bool b = false, double? size}) => pw.TextStyle(font: b ? bold : font, fontSize: size ?? fs, lineSpacing: 1.3);
  pw.Widget txt(String s, {bool b = false, double? size, pw.TextAlign? align}) => pw.Text(s, style: st(b: b, size: size), textAlign: align);
  const border = pw.TableBorder(left: pw.BorderSide(width: 0.6), right: pw.BorderSide(width: 0.6), top: pw.BorderSide(width: 0.6), bottom: pw.BorderSide(width: 0.6), horizontalInside: pw.BorderSide(width: 0.4), verticalInside: pw.BorderSide(width: 0.4));
  pw.Widget cell(String s, {bool b = false, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 0.8), child: txt(s, b: b, align: align));
  pw.TableRow totalRow(String label, {String qty = '', String mid = '', required String amount, bool b = false, bool shaded = false}) => pw.TableRow(
        decoration: shaded ? const pw.BoxDecoration(color: PdfColors.grey200) : null,
        children: [
          for (final i in t.cols) [cell(''), cell(label, b: b), cell(''), cell(''), cell(qty, align: pw.TextAlign.right), cell(''), cell(mid, align: pw.TextAlign.right), cell(''), cell(amount, b: b, align: pw.TextAlign.right)][i],
        ],
      );

  final logo = t.showShop ? logoBytes(shop.logoPng) : null;
  final children = <pw.Widget>[
    if (t.heading.isNotEmpty) ...[
      pw.Center(child: pw.Text(t.heading, style: st(b: true, size: m.title).copyWith(decoration: pw.TextDecoration.underline))),
      pw.SizedBox(height: 4),
    ],
    if (t.showShop)
      pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
        padding: const pw.EdgeInsets.all(6),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (logo != null) ...[pw.Image(pw.MemoryImage(logo), height: 40), pw.SizedBox(width: 8)],
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            for (var i = 0; i < t.shopLeft.length; i++) txt(t.shopLeft[i], b: i == 0, size: i == 0 ? m.shop + 1 : null),
          ])),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [for (final r in t.shopRight) txt(r, b: true, align: pw.TextAlign.right)]),
        ]),
      ),
    pw.Container(
      decoration: const pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(width: 0.6), right: pw.BorderSide(width: 0.6), bottom: pw.BorderSide(width: 0.6), top: pw.BorderSide(width: 0.6))),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (t.title.isNotEmpty) ...[for (final line in t.metaLines) txt(line), pw.SizedBox(height: 4)],
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [txt('${t.toLabel}: ', b: true), pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [txt(t.to), for (final x in t.toLines) txt(x)]))]),
          ]),
        ),
        // the heading sits in the middle of the first row, underlined (the two sides take equal room, so it is truly centred)
        if (t.title.isNotEmpty) pw.Text(t.title, style: st(b: true, size: m.title).copyWith(decoration: pw.TextDecoration.underline)),
        pw.Expanded(
          child: pw.Align(
            alignment: pw.Alignment.topRight,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (t.title.isEmpty) for (final line in t.metaLines) txt(line),
              if (t.status.isNotEmpty) txt(t.status, b: true),
            ]),
          ),
        ),
      ]),
    ),
    pw.Table(
      border: border,
      columnWidths: {for (var k = 0; k < t.cols.length; k++) k: t.cols[k] == 1 ? const pw.FlexColumnWidth() : pw.FixedColumnWidth(templateColWidths[t.cols[k]] * (a5 ? 0.8 : 1))},
      children: [
        pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [for (final i in t.cols) cell(t.head[i], b: true, align: i == 1 ? pw.TextAlign.left : pw.TextAlign.center)]),
        for (final r in t.rows)
          pw.TableRow(children: [
            for (final i in t.cols) cell(r.cells[i], align: i == 1 ? pw.TextAlign.left : (i == 0 || i == 3 ? pw.TextAlign.center : pw.TextAlign.right)),
          ]),
      ],
    ),
    pw.Table(
      border: border,
      columnWidths: {for (var k = 0; k < t.cols.length; k++) k: t.cols[k] == 1 ? const pw.FlexColumnWidth() : pw.FixedColumnWidth(templateColWidths[t.cols[k]] * (a5 ? 0.8 : 1))},
      children: [
        totalRow(t.totalLabel, qty: t.totalQty, amount: t.totalAmount, b: true),
        if (t.discountLabel.isNotEmpty) totalRow(t.discountLabel, amount: t.discountValue, b: true),
        totalRow(t.roundLabel, mid: t.beforeRound, amount: t.roundOff),
        totalRow(t.netLabel, amount: t.net, b: true, shaded: true),
        if (t.paidLabel.isNotEmpty) totalRow(t.paidLabel, amount: t.paidValue),
        if (t.balanceLabel.isNotEmpty) totalRow(t.balanceLabel, amount: t.balanceValue, b: true),
      ],
    ),
    if (t.showGst) pw.SizedBox(height: 6),
    if (t.showGst)
    pw.Table(
      border: border,
      columnWidths: {0: const pw.FlexColumnWidth(1.4), 1: const pw.FlexColumnWidth(0.8), 2: const pw.FlexColumnWidth(1), 3: const pw.FlexColumnWidth(0.8), 4: const pw.FlexColumnWidth(1), 5: const pw.FlexColumnWidth(0.8), 6: const pw.FlexColumnWidth(1), 7: const pw.FlexColumnWidth(1.4)},
      children: [
        pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
          cell(t.gstHead[0], b: true, align: pw.TextAlign.center),
          cell(t.gstHead[1], b: true, align: pw.TextAlign.center),
          cell('', b: true),
          cell(t.gstHead[2], b: true, align: pw.TextAlign.center),
          cell('', b: true),
          cell(t.gstHead[3], b: true, align: pw.TextAlign.center),
          cell('', b: true),
          cell(t.gstHead[4], b: true, align: pw.TextAlign.center),
        ]),
        pw.TableRow(children: [cell(''), for (var i = 0; i < 3; i++) ...[cell(t.pctLabel, b: true, align: pw.TextAlign.center), cell(t.amountLabel, b: true, align: pw.TextAlign.center)], cell('')]),
        for (final g in t.gstRows)
          pw.TableRow(children: [
            cell(g.salesAmt, align: pw.TextAlign.right),
            cell(g.pct, align: pw.TextAlign.right),
            cell(g.cgst, align: pw.TextAlign.right),
            cell(g.pct, align: pw.TextAlign.right),
            cell(g.sgst, align: pw.TextAlign.right),
            cell('', align: pw.TextAlign.right),
            cell(g.igst, align: pw.TextAlign.right),
            cell(g.net, b: true, align: pw.TextAlign.right),
          ]),
      ],
    ),
    pw.SizedBox(height: 8),
    txt(t.words, b: true),
    if (t.showShop) ...[
      pw.SizedBox(height: 10),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Expanded(
          child: t.upiData.isEmpty
              ? pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [for (final b in t.bankLines) txt(b)])
              : pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                  pw.BarcodeWidget(barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium), data: t.upiData, width: 64, height: 64, drawText: false),
                  pw.SizedBox(width: 8),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [txt(t.upiLabel, b: true), txt(t.upiAnyApp)]),
                ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [txt(t.forShop, b: true), pw.SizedBox(height: 34), txt(t.signatory)]),
      ]),
    ],
    if (t.note.isNotEmpty) ...[pw.SizedBox(height: 10), pw.Center(child: txt(t.note, align: pw.TextAlign.center))],
  ];

  final pdf = pw.Document(title: '${t.title.isNotEmpty ? t.title : t.status} $number', author: shop.name, creator: 'ASK ERP 2.0', producer: 'ASK ERP 2.0');
  final base = a5 ? PdfPageFormat.a5 : PdfPageFormat.a4;
  pdf.addPage(pw.MultiPage(
    pageFormat: base.copyWith(marginLeft: margin, marginRight: margin, marginTop: margin, marginBottom: margin),
    maxPages: 100,
    build: (_) => children,
  ));
  return pdf.save();
}
