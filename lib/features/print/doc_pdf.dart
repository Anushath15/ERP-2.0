import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/logo_image.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart' show PaperSize, PrintTextSize;
import '../../strings.dart';
import '../billing/cart.dart';
import 'bill_template.dart';
import 'bill_template_pdf.dart';
import 'print_layout.dart';

/// The printed bill or estimate as a real PDF (pure Dart, no plugin), from the same layout the on-screen paper uses.
///  * A4 and A5 tax invoices: a normal page (several pages when the bill is long).
///  * Roll paper (80 mm, 58 mm) and ESTIMATES: the page is exactly as long as the content, so there is no big blank space at the bottom.
Future<Uint8List> buildDocPdf({
  required PrintDoc doc,
  required PaperSize paper,
  required ShopProfile shop,
  required PrintTextSize size,
  required Strings l,
}) async {
  if (!isRoll(paper)) {
    return buildTemplatePdf(t: buildBillTemplate(doc: doc, shop: shop, l: l), number: doc.number, paper: paper, shop: shop, size: size);
  }
  final lay = buildPrintLayout(doc: doc, shop: shop, l: l);
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Variable.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  final m = PrintMetrics.of(size);
  final w = paperWidthPt(paper);
  final margin = paperMarginPt(paper);
  final roll = isRoll(paper);

  pw.TextStyle s({bool b = false, double? fs}) => pw.TextStyle(font: b ? bold : font, fontSize: fs ?? m.row, lineSpacing: 1.5);

  pw.Widget txt(String t, {bool b = false, double? fs, pw.TextAlign? align}) => pw.Text(t, style: s(b: b, fs: fs), textAlign: align);

  pw.Widget text(PrintText t, {pw.TextAlign? align}) => txt(t.text, b: t.bold, fs: t.id == 'shopName' ? m.shop : null, align: align);
  final line = pw.Divider(height: roll ? 9 : 12, thickness: 0.6);

  const wNum = 22.0, wQty = 56.0, wRate = 58.0, wAmt = 68.0;
  pw.Widget cell(String t, double w, {bool b = false}) => pw.SizedBox(width: w, child: txt(t, b: b, align: pw.TextAlign.right));
  pw.Widget item(PrintItem i) => roll
      ? pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(i.name, style: s()),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(i.qtyTimesRate, style: s()), pw.Text(i.amount, style: s())]),
          ]),
        )
      : pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(width: wNum, child: pw.Text(i.number, style: s())),
            pw.Expanded(child: pw.Text(i.name, style: s())),
            cell(i.qty, wQty),
            cell(i.rate, wRate),
            cell(i.amount, wAmt),
          ]),
        );
  pw.Widget total(TotalLine t) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Expanded(child: txt(t.label, b: t.bold, fs: t.big ? m.total : null)),
        pw.SizedBox(width: 6),
        txt(t.value, b: t.bold, fs: t.big ? m.total : null),
      ]);

  final children = <pw.Widget>[
    if (!roll && logoBytes(shop.logoPng) != null) ...[
      pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Image(pw.MemoryImage(logoBytes(shop.logoPng)!), height: 44)),
      pw.SizedBox(height: 4),
    ],
    if (lay.header.isNotEmpty) ...[
      pw.Column(crossAxisAlignment: roll ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start, children: [for (final h in lay.header) text(h, align: roll ? pw.TextAlign.center : pw.TextAlign.left)]),
      pw.SizedBox(height: roll ? 4 : 8),
    ],
    pw.Center(child: txt(lay.title, b: true, fs: m.title)),
    line,
    if (roll)
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [for (final t in [...lay.metaRight, ...lay.metaLeft]) text(t)])
    else
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [for (final t in lay.metaLeft) text(t)])),
        pw.SizedBox(width: 12),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [for (final t in lay.metaRight) text(t, align: pw.TextAlign.right)]),
      ]),
    line,
    if (!roll) ...[
      pw.Row(children: [
        pw.SizedBox(width: wNum, child: txt(lay.tableHead[0], b: true)),
        pw.Expanded(child: txt(lay.tableHead[1], b: true)),
        cell(lay.tableHead[2], wQty, b: true),
        cell(lay.tableHead[3], wRate, b: true),
        cell(lay.tableHead[4], wAmt, b: true),
      ]),
      line,
    ],
    for (final i in lay.items) item(i),
    line,
    pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: roll ? double.infinity : (paper == PaperSize.a5 ? 215 : 230),
        child: pw.Column(children: [
          for (final t in lay.totals) total(t),
          if (lay.paidInFull) pw.Align(alignment: pw.Alignment.centerRight, child: txt(l.rcPaidInFull, b: true)),
        ]),
      ),
    ),
    pw.SizedBox(height: roll ? 8 : 12),
    pw.Center(child: pw.Text(lay.note, style: s(), textAlign: pw.TextAlign.center)),
  ];

  final pdf = pw.Document(title: '${lay.title} ${doc.number}', author: shop.name, creator: 'ASK ERP 2.0', producer: 'ASK ERP 2.0');
  final fitToContent = roll || lay.estimate;
  if (fitToContent) {
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat(w, double.infinity, marginAll: margin),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, mainAxisSize: pw.MainAxisSize.min, children: children),
    ));
  } else {
    final base = paper == PaperSize.a5 ? PdfPageFormat.a5 : PdfPageFormat.a4;
    pdf.addPage(pw.MultiPage(pageFormat: base.copyWith(marginLeft: margin, marginRight: margin, marginTop: margin, marginBottom: margin), build: (_) => children));
  }
  return pdf.save();
}
