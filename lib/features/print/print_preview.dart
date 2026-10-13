import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain_lite/bill_calc.dart';
import '../../fake/models.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart';
import '../../strings.dart';
import '../billing/cart.dart';

/// A sample document so the preview works from the menu too (no bill needed).
PrintDoc samplePrintDoc(List<Product> products, DateTime now, {DocMode mode = DocMode.invoice, bool edited = false}) {
  final lines = [
    for (var i = 0; i < 6; i++) CartLine(product: products[(i * 37 + 5) % products.length], qtyMilli: 1000 * (1 + i % 3)),
  ];
  return PrintDoc(
    mode: mode,
    number: mode == DocMode.invoice ? 'A-020001' : 'EST-00231',
    date: mode == DocMode.invoice ? now : now.subtract(const Duration(days: 3)),
    editedOn: edited ? now : null,
    customer: 'Murugan Electricals',
    lines: lines,
    calc: calcBill(lines),
    pay: PayMode.cash,
    // the sample invoice shows a part payment: ₹1,000 received, the rest added to credit
    receivedPaise: mode == DocMode.invoice ? 100000 : null,
  );
}

class PrintPreviewScreen extends ConsumerStatefulWidget {
  const PrintPreviewScreen({super.key, this.initialPaper, this.sampleMode});
  final PaperSize? initialPaper;
  final DocMode? sampleMode; // when opened from the menu: show a sample of this kind
  @override
  ConsumerState<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends ConsumerState<PrintPreviewScreen> {
  late PaperSize _paper = widget.initialPaper ?? ref.read(settingsProvider).paper;

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    var doc = widget.sampleMode != null ? null : ref.watch(printDocProvider);
    final now = ref.watch(clockProvider);
    final products = ref.watch(productsProvider);
    doc ??= samplePrintDoc(products, now, mode: widget.sampleMode ?? DocMode.invoice, edited: widget.sampleMode == DocMode.estimation);
    final phone = context.isPhone;

    final controls = Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      SegmentedButton<PaperSize>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: PaperSize.a4, label: Text(l.paperA4)),
          ButtonSegment(value: PaperSize.mm80, label: Text(l.paper80)),
          ButtonSegment(value: PaperSize.mm58, label: Text(l.paper58)),
        ],
        selected: {_paper},
        onSelectionChanged: (s) => setState(() => _paper = s.first),
      ),
    ]);
    final actions = [
      FilledButton.icon(onPressed: () => toast(context, l.printNotConnected), icon: const Icon(Icons.print), label: Text(l.print)),
      OutlinedButton.icon(onPressed: () => toast(context, l.pdfNotConnected), icon: const Icon(Icons.picture_as_pdf_outlined), label: Text(l.saveAsPdf)),
      if (context.canPop()) TextButton(onPressed: () => context.pop(), child: Text(l.back)),
    ];

    return PageFrame(
      title: l.printPreview,
      subtitle: doc.mode == DocMode.invoice ? l.previewInvoiceHint : l.previewEstimateHint,
      actions: phone ? const [] : actions,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        controls,
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m)),
            child: LayoutBuilder(builder: (ctx, bc) {
              final paperW = switch (_paper) { PaperSize.a4 => 595.0, PaperSize.mm80 => 302.0, PaperSize.mm58 => 219.0 };
              final scale = ((bc.maxWidth - 24) / paperW).clamp(0.3, 1.6);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: SizedBox(
                    width: paperW * (scale > 1 ? 1.0 : scale),
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling), child: SizedBox(width: paperW, child: Paper(doc: doc!, paper: _paper, l: l, shopName: ref.watch(shopProvider).name, gstin: ref.watch(shopProvider).gstin))),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (phone) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Wrap(spacing: 8, runSpacing: 8, children: actions)),
      ]),
    );
  }
}

/// The paper itself. Always white with dark text, whatever the app theme. Estimation shows its OWN date beside its number,
/// and "Edited on" only if it was edited.
class Paper extends StatelessWidget {
  const Paper({super.key, required this.doc, required this.paper, required this.l, required this.shopName, required this.gstin});
  final PrintDoc doc;
  final PaperSize paper;
  final Strings l;
  final String shopName, gstin;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a4 = paper == PaperSize.a4;
    final fs = a4 ? 12.0 : (paper == PaperSize.mm80 ? 11.0 : 10.0);
    TextStyle s({bool b = false, double? size}) => TextStyle(fontFamily: 'Inter', color: c.onPaper, fontSize: size ?? fs, fontWeight: b ? FontWeight.w700 : FontWeight.w400, height: 1.3);
    final est = doc.mode == DocMode.estimation;
    final title = est ? l.rcEstimate : l.rcTaxInvoice;
    final cgst = doc.calc.cgst, sgst = doc.calc.sgst;
    final Widget header = Column(crossAxisAlignment: a4 ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
      Text(shopName.toUpperCase(), style: s(b: true, size: a4 ? 18 : fs + 3), textAlign: a4 ? TextAlign.left : TextAlign.center),
      Text('12 Market Street, Coimbatore - 641001', style: s(), textAlign: a4 ? TextAlign.left : TextAlign.center),
      Text('${l.rcGstin}: $gstin   Ph: 98765 43210', style: s(), textAlign: a4 ? TextAlign.left : TextAlign.center),
    ]);
    final meta = a4
        ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${l.rcCustomer}: ${doc.customer}', style: s(b: true)),
              if (!est) Text('${l.rcPaidBy}: ${_pay(doc.pay)}', style: s()),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${est ? l.rcEstNo : l.rcBillNo}: ${doc.number}', style: s(b: true)),
              Text('${l.rcDate}: ${formatDate(doc.date)}', style: s(), key: const ValueKey('paperDate')),
              if (doc.editedOn != null) Text('${l.rcEditedOn}: ${formatDate(doc.editedOn!)}', style: s(), key: const ValueKey('paperEdited')),
            ]),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(doc.number, style: s(b: true)),
              Text(formatDate(doc.date), style: s(), key: const ValueKey('paperDate')),
            ]),
            if (doc.editedOn != null) Text('${l.rcEditedOn}: ${formatDate(doc.editedOn!)}', style: s(), key: const ValueKey('paperEdited')),
            Text('${l.rcCustomer}: ${doc.customer}', style: s()),
          ]);

    Widget line(int i) {
      final ln = doc.lines[i];
      final lc = doc.calc.lines[i];
      if (a4) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 26, child: Text('${i + 1}', style: s())),
            Expanded(child: Text(ln.product.name, style: s())),
            SizedBox(width: 70, child: Text('${formatQty(ln.qtyMilli)} ${ln.product.unit}', textAlign: TextAlign.right, style: s())),
            SizedBox(width: 72, child: Text(formatPaise(ln.rate), textAlign: TextAlign.right, style: s())),
            SizedBox(width: 84, child: Text(formatPaise(lc.total), textAlign: TextAlign.right, style: s())),
          ]),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ln.product.name, style: s()),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${formatQty(ln.qtyMilli)} x ${formatPaise(ln.rate)}', style: s()),
            Text(formatPaise(lc.total), style: s()),
          ]),
        ]),
      );
    }

    Widget totalRow(String k, String v, {bool b = false, double? size, Key? key}) => Row(key: key, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Flexible(child: Text(k, style: s(b: b, size: size))), const SizedBox(width: 6), Text(v, style: s(b: b, size: size))]);

    final divider = Divider(color: c.onPaper.withValues(alpha: 0.5), height: a4 ? 14 : 10, thickness: 1);
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      SizedBox(height: a4 ? 10 : 6),
      Center(child: Text(title, style: s(b: true, size: a4 ? 15 : fs + 1))),
      divider,
      meta,
      divider,
      if (a4)
        Row(children: [
          SizedBox(width: 26, child: Text('#', style: s(b: true))),
          Expanded(child: Text(l.rcItem, style: s(b: true))),
          SizedBox(width: 70, child: Text(l.rcQty, textAlign: TextAlign.right, style: s(b: true))),
          SizedBox(width: 72, child: Text(l.rcRate, textAlign: TextAlign.right, style: s(b: true))),
          SizedBox(width: 84, child: Text(l.rcAmount, textAlign: TextAlign.right, style: s(b: true))),
        ]),
      if (a4) divider,
      for (var i = 0; i < doc.lines.length; i++) line(i),
      divider,
      Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: a4 ? 260 : double.infinity,
          child: Column(children: [
            totalRow(l.rcTaxable, formatPaise(doc.calc.taxable)),
            totalRow('CGST', formatPaise(cgst)),
            totalRow('SGST', formatPaise(sgst)),
            totalRow(l.rcRoundOff, '${doc.calc.roundOff >= 0 ? '+' : ''}${formatPaise(doc.calc.roundOff)}'),
            const SizedBox(height: 4),
            totalRow(l.rcGrandTotal, '₹ ${formatPaise(doc.calc.grandTotal)}', b: true, size: a4 ? 15 : fs + 2),
            if (!est && doc.receivedPaise != null) ...[
              const SizedBox(height: 4),
              totalRow(doc.pay == PayMode.credit ? l.paidNow : '${l.rcReceived} (${_pay(doc.pay)})', formatPaise(doc.receivedPaise! > doc.calc.grandTotal ? doc.calc.grandTotal : doc.receivedPaise!), key: const ValueKey('paperReceived')),
              if (doc.balancePaise > 0) totalRow(l.rcBalanceDue, '₹ ${formatPaise(doc.balancePaise)}', b: true, key: const ValueKey('paperBalance')) else Align(alignment: Alignment.centerRight, child: Text(l.rcPaidInFull, style: s(b: true), key: const ValueKey('paperPaid'))),
              if (doc.advanceKeptPaise > 0) totalRow(l.rcAdvance, formatPaise(doc.advanceKeptPaise)),
              if (doc.newBalancePaise != null && doc.newBalancePaise! > 0 && doc.balancePaise > 0) totalRow(l.rcAccountBalance, '₹ ${formatPaise(doc.newBalancePaise!)}', key: const ValueKey('paperNewBalance')),
              if (doc.changePaise > 0) totalRow(l.rcChange, formatPaise(doc.changePaise)),
            ],
          ]),
        ),
      ),
      SizedBox(height: a4 ? 18 : 10),
      Center(child: Text(est ? l.rcEstimateNote : l.rcThanks, style: s(), textAlign: TextAlign.center)),
    ]);
    return Container(
      color: c.paper,
      padding: EdgeInsets.all(a4 ? 28 : 10),
      constraints: BoxConstraints(minHeight: a4 ? 842 : 0),
      child: body,
    );
  }

  String _pay(PayMode m) => switch (m) { PayMode.cash => l.payCash, PayMode.upi => l.payUpi, PayMode.card => l.payCard, PayMode.credit => l.payCredit };
}
