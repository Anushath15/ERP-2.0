import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/file_saver.dart';
import '../../core/responsive.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain_lite/bill_calc.dart';
import '../../fake/models.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart';
import '../../strings.dart';
import '../billing/cart.dart';
import 'bill_template.dart';
import 'bill_template_paper.dart';
import 'doc_pdf.dart';
import 'print_layout.dart';

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
    customerPhone: mode == DocMode.invoice ? '94430 12345' : '',
    customerGstin: mode == DocMode.invoice ? '33ABCDE1234F1Z5' : '',
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
    final settings = ref.watch(settingsProvider);

    final controls = Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      SegmentedButton<PaperSize>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: PaperSize.a4, label: Text(l.paperA4)),
          ButtonSegment(value: PaperSize.a5, label: Text(l.paperA5)),
          ButtonSegment(value: PaperSize.mm80, label: Text(l.paper80)),
          ButtonSegment(value: PaperSize.mm58, label: Text(l.paper58)),
        ],
        selected: {_paper},
        onSelectionChanged: (s) => setState(() => _paper = s.first),
      ),
    ]);
    final actions = [
      FilledButton.icon(onPressed: () => toast(context, l.printNotConnected), icon: const Icon(Icons.print), label: Text(l.print)),
      OutlinedButton.icon(
        key: const ValueKey('printSavePdf'),
        onPressed: () async {
          final bytes = await buildDocPdf(doc: doc!, paper: _paper, shop: ref.read(shopProvider), size: settings.printSize, l: l);
          final kind = doc!.mode == DocMode.estimation ? l.rcEstimate : l.rcTaxInvoice;
          final where = await ref.read(fileSaverProvider).save('${kind[0]}${kind.substring(1).toLowerCase()} ${doc.number}.pdf'.replaceAll('/', '-'), bytes);
          if (context.mounted) toast(context, where == null ? l.pdfFailed : l.pdfSaved(where));
        },
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: Text(l.saveAsPdf),
      ),
      if (doc.backTo != null || context.canPop()) TextButton(key: const ValueKey('printBack'), onPressed: () => doc?.backTo != null ? context.go(doc!.backTo!) : context.pop(), child: Text(l.back)),
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
              final paperW = paperWidthPt(_paper);
              final scale = ((bc.maxWidth - 24) / paperW).clamp(0.3, 1.6);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: SizedBox(
                    width: paperW * (scale > 1 ? 1.0 : scale),
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling), child: SizedBox(width: paperW, child: Paper(doc: doc!, paper: _paper, l: l, shop: ref.watch(shopProvider), size: settings.printSize))),
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

/// The paper itself. Always white with dark text, whatever the app theme. It only DRAWS what print_layout.dart says to print,
/// at the sizes of the chosen "Print text size"; the PDF uses the same layout, so the two always agree.
class Paper extends StatelessWidget {
  const Paper({super.key, required this.doc, required this.paper, required this.l, required this.shop, this.size = PrintTextSize.small});
  final PrintDoc doc;
  final PaperSize paper;
  final Strings l;
  final ShopProfile shop;
  final PrintTextSize size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!isRoll(paper)) {
      // A4 and A5 follow the shop's own bill template (the same for a bill and an estimate; an estimate has no shop details)
      return TemplatePaper(t: buildBillTemplate(doc: doc, shop: shop, l: l), paper: paper, shop: shop, size: size);
    }
    final lay = buildPrintLayout(doc: doc, shop: shop, l: l);
    final m = PrintMetrics.of(size);
    final roll = isRoll(paper);
    final margin = paperMarginPt(paper);
    TextStyle s({bool b = false, double? fs}) => TextStyle(fontFamily: 'Inter', color: c.onPaper, fontSize: fs ?? m.row, fontWeight: b ? FontWeight.w700 : FontWeight.w400, height: 1.3);
    Widget text(PrintText t, {TextAlign? align}) => Text(t.text, key: t.id == null ? null : ValueKey<String>(t.id!), style: s(b: t.bold, fs: t.id == 'shopName' ? m.shop : null), textAlign: align);
    final cross = roll ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final divider = Divider(color: c.onPaper.withValues(alpha: 0.5), height: roll ? 9 : 12, thickness: 0.8);

    final header = lay.header.isEmpty ? null : Column(crossAxisAlignment: cross, children: [for (final h in lay.header) text(h, align: roll ? TextAlign.center : TextAlign.left)]);

    final meta = roll
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final t in [...lay.metaRight, ...lay.metaLeft]) text(t)])
        : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final t in lay.metaLeft) text(t)])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [for (final t in lay.metaRight) text(t, align: TextAlign.right)]),
          ]);

    const wNum = 22.0, wQty = 56.0, wRate = 58.0, wAmt = 68.0;
    Widget head() => Row(children: [
          SizedBox(width: wNum, child: Text(lay.tableHead[0], style: s(b: true))),
          Expanded(child: Text(lay.tableHead[1], style: s(b: true))),
          SizedBox(width: wQty, child: Text(lay.tableHead[2], textAlign: TextAlign.right, style: s(b: true))),
          SizedBox(width: wRate, child: Text(lay.tableHead[3], textAlign: TextAlign.right, style: s(b: true))),
          SizedBox(width: wAmt, child: Text(lay.tableHead[4], textAlign: TextAlign.right, style: s(b: true))),
        ]);
    Widget item(PrintItem i) => roll
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.name, style: s()),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(i.qtyTimesRate, style: s()), Text(i.amount, style: s())]),
            ]),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: wNum, child: Text(i.number, style: s())),
              Expanded(child: Text(i.name, style: s())),
              SizedBox(width: wQty, child: Text(i.qty, textAlign: TextAlign.right, style: s())),
              SizedBox(width: wRate, child: Text(i.rate, textAlign: TextAlign.right, style: s())),
              SizedBox(width: wAmt, child: Text(i.amount, textAlign: TextAlign.right, style: s())),
            ]),
          );

    Widget total(TotalLine t) => Row(key: t.id == null ? null : ValueKey<String>(t.id!), mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(t.label, style: s(b: t.bold, fs: t.big ? m.total : null))),
          const SizedBox(width: 6),
          Text(t.value, style: s(b: t.bold, fs: t.big ? m.total : null)),
        ]);

    final body = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (header != null) ...[header, SizedBox(height: roll ? 4 : 8)],
      Center(child: Text(lay.title, style: s(b: true, fs: m.title))),
      divider,
      meta,
      divider,
      if (!roll) ...[head(), divider],
      for (final i in lay.items) item(i),
      divider,
      Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: roll ? double.infinity : (paper == PaperSize.a5 ? 215 : 230),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final t in lay.totals) total(t),
            if (lay.paidInFull) Align(alignment: Alignment.centerRight, child: Text(l.rcPaidInFull, style: s(b: true), key: const ValueKey('paperPaid'))),
          ]),
        ),
      ),
      SizedBox(height: roll ? 8 : 12),
      Center(child: Text(lay.note, style: s(), textAlign: TextAlign.center)),
    ]);
    return Container(color: c.paper, padding: EdgeInsets.all(margin), child: body);
  }
}
