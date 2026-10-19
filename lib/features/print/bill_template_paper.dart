import 'package:flutter/material.dart';
import '../../core/logo_image.dart';
import '../../design/tokens.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart' show PaperSize, PrintTextSize;
import '../../design/qr_view.dart';
import 'bill_template.dart';
import 'bill_template_pdf.dart' show templateColWidths;
import 'print_layout.dart';

/// The A4 / A5 bill or estimate on the screen: the shop's template (see bill_template.dart), drawn the same way the PDF draws it.
/// Always white with dark text, whatever the app theme.
class TemplatePaper extends StatelessWidget {
  const TemplatePaper({super.key, required this.t, required this.paper, required this.shop, required this.size});
  final BillTemplate t;
  final PaperSize paper;
  final ShopProfile shop;
  final PrintTextSize size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = PrintMetrics.of(size);
    final a5 = paper == PaperSize.a5;
    // small rows, so that many products fit on one page (paper is not wasted)
    final fs = (a5 ? m.row - 3.5 : m.row - 2.0).clamp(6.0, 12.0).toDouble();
    final margin = paperMarginPt(paper);
    TextStyle st({bool b = false, double? size}) => TextStyle(fontFamily: 'Inter', color: c.onPaper, fontSize: size ?? fs, fontWeight: b ? FontWeight.w700 : FontWeight.w400, height: 1.3);
    Widget txt(String s, {bool b = false, double? size, TextAlign? align, Key? key}) => Text(s, key: key, style: st(b: b, size: size), textAlign: align);
    final line = BorderSide(color: c.onPaper, width: 0.6);
    final thin = BorderSide(color: c.onPaper, width: 0.4);
    final border = TableBorder(left: line, right: line, top: line, bottom: line, horizontalInside: thin, verticalInside: thin);
    Widget cell(String s, {bool b = false, TextAlign align = TextAlign.left, Key? key}) => Padding(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.8), child: txt(s, b: b, align: align, key: key));
    final shade = c.onPaper.withValues(alpha: 0.08);
    final logo = t.showShop ? logoBytes(shop.logoPng) : null;

    TableRow totalRow(String label, {String qty = '', String mid = '', required String amount, bool b = false, bool shaded = false, Key? key}) => TableRow(
          decoration: shaded ? BoxDecoration(color: shade) : null,
          children: [
            for (final i in t.cols) [cell(''), cell(label, b: b), cell(''), cell(''), cell(qty, align: TextAlign.right), cell(''), cell(mid, align: TextAlign.right), cell(''), cell(amount, b: b, align: TextAlign.right, key: key)][i],
          ],
        );
    final cols = <int, TableColumnWidth>{for (var k = 0; k < t.cols.length; k++) k: t.cols[k] == 1 ? const FlexColumnWidth() : FixedColumnWidth(templateColWidths[t.cols[k]] * (a5 ? 0.8 : 1))};
    final body = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (t.heading.isNotEmpty) ...[
        Center(child: Text(t.heading, key: const ValueKey('paperHeading'), style: st(b: true, size: m.title).copyWith(decoration: TextDecoration.underline, decorationColor: c.onPaper))),
        const SizedBox(height: 4),
      ],
      if (t.showShop)
        Container(
          decoration: BoxDecoration(border: Border.all(color: c.onPaper, width: 0.6)),
          padding: const EdgeInsets.all(6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (logo != null) ...[Image.memory(logo, height: 40, fit: BoxFit.contain), const SizedBox(width: 8)],
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i = 0; i < t.shopLeft.length; i++) txt(t.shopLeft[i], b: i == 0, size: i == 0 ? m.shop + 1 : null, key: i == 0 ? const ValueKey('shopName') : null)])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [for (final r in t.shopRight) txt(r, b: true, align: TextAlign.right)]),
          ]),
        ),
      Container(
        decoration: BoxDecoration(border: Border(left: line, right: line, bottom: line, top: t.showShop ? BorderSide.none : line)),
        padding: const EdgeInsets.all(6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (t.title.isNotEmpty) ...[
                for (var i = 0; i < t.metaLines.length; i++) txt(t.metaLines[i], key: i == 0 ? const ValueKey('paperNumber') : (i == 1 ? const ValueKey('paperDate') : const ValueKey('paperEdited'))),
                const SizedBox(height: 4),
              ],
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [txt('${t.toLabel}: ', b: true), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [txt(t.to), for (var i = 0; i < t.toLines.length; i++) txt(t.toLines[i], key: ValueKey('paperTo$i'))]))]),
            ]),
          ),
          // the heading sits in the middle of the first row, underlined (the two sides take equal room, so it is truly centred)
          if (t.title.isNotEmpty) Text(t.title, key: const ValueKey('paperTitle'), style: st(b: true, size: m.title).copyWith(decoration: TextDecoration.underline, decorationColor: c.onPaper)),
          Expanded(
            child: Align(
              alignment: Alignment.topRight,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (t.title.isEmpty) for (var i = 0; i < t.metaLines.length; i++) txt(t.metaLines[i], key: i == 0 ? const ValueKey('paperNumber') : (i == 1 ? const ValueKey('paperDate') : const ValueKey('paperEdited'))),
                if (t.status.isNotEmpty) txt(t.status, b: true, key: const ValueKey('paperStatus')),
              ]),
            ),
          ),
        ]),
      ),
      Table(
        border: border,
        columnWidths: cols,
        children: [
          TableRow(decoration: BoxDecoration(color: shade), children: [for (final i in t.cols) cell(t.head[i], b: true, align: i == 1 ? TextAlign.left : TextAlign.center)]),
          for (final r in t.rows) TableRow(children: [for (final i in t.cols) cell(r.cells[i], align: i == 1 ? TextAlign.left : (i == 0 || i == 3 ? TextAlign.center : TextAlign.right))]),
        ],
      ),
      Table(
        border: border,
        columnWidths: cols,
        children: [
          totalRow(t.totalLabel, qty: t.totalQty, amount: t.totalAmount, b: true),
          if (t.discountLabel.isNotEmpty) totalRow(t.discountLabel, amount: t.discountValue, b: true, key: const ValueKey('paperDiscount')),
          totalRow(t.roundLabel, mid: t.beforeRound, amount: t.roundOff),
          totalRow(t.netLabel, amount: t.net, b: true, shaded: true, key: const ValueKey('paperTotal')),
          if (t.paidLabel.isNotEmpty) totalRow(t.paidLabel, amount: t.paidValue, key: const ValueKey('paperReceived')),
          if (t.balanceLabel.isNotEmpty) totalRow(t.balanceLabel, amount: t.balanceValue, b: true, key: const ValueKey('paperBalance')),
        ],
      ),
      if (t.showGst) const SizedBox(height: 6),
      if (t.showGst)
      Table(
        border: border,
        columnWidths: const {0: FlexColumnWidth(1.4), 1: FlexColumnWidth(0.8), 2: FlexColumnWidth(1), 3: FlexColumnWidth(0.8), 4: FlexColumnWidth(1), 5: FlexColumnWidth(0.8), 6: FlexColumnWidth(1), 7: FlexColumnWidth(1.4)},
        children: [
          TableRow(decoration: BoxDecoration(color: shade), children: [
            cell(t.gstHead[0], b: true, align: TextAlign.center),
            cell(t.gstHead[1], b: true, align: TextAlign.center),
            cell(''),
            cell(t.gstHead[2], b: true, align: TextAlign.center),
            cell(''),
            cell(t.gstHead[3], b: true, align: TextAlign.center),
            cell(''),
            cell(t.gstHead[4], b: true, align: TextAlign.center),
          ]),
          TableRow(children: [cell(''), for (var i = 0; i < 3; i++) ...[cell(t.pctLabel, b: true, align: TextAlign.center), cell(t.amountLabel, b: true, align: TextAlign.center)], cell('')]),
          for (final g in t.gstRows)
            TableRow(children: [
              cell(g.salesAmt, align: TextAlign.right),
              cell(g.pct, align: TextAlign.right),
              cell(g.cgst, align: TextAlign.right),
              cell(g.pct, align: TextAlign.right),
              cell(g.sgst, align: TextAlign.right),
              cell('', align: TextAlign.right),
              cell(g.igst, align: TextAlign.right),
              cell(g.net, b: true, align: TextAlign.right),
            ]),
        ],
      ),
      const SizedBox(height: 8),
      txt(t.words, b: true, key: const ValueKey('paperWords')),
      if (t.showShop) ...[
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: t.upiData.isEmpty
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final b in t.bankLines) txt(b)])
                : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    QrView(key: const ValueKey('paperUpiQr'), data: t.upiData, size: 64),
                    const SizedBox(width: 8),
                    Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [txt(t.upiLabel, b: true, key: const ValueKey('paperUpi')), txt(t.upiAnyApp)])),
                  ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [txt(t.forShop, b: true), const SizedBox(height: 34), txt(t.signatory)]),
        ]),
      ],
      if (t.note.isNotEmpty) ...[const SizedBox(height: 10), Center(child: txt(t.note, align: TextAlign.center))],
    ]);
    return Container(color: c.paper, padding: EdgeInsets.all(margin), child: body);
  }
}
