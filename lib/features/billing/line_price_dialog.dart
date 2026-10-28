import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/percent_link.dart';
import '../../design/widgets.dart';
import '../../domain/models.dart';

/// What the person chose in the Change price box. [rate] and [discountBp] are for this bill or estimate only; [saveToProduct] means they pressed
/// "Save to product": the MRP, buying price and selling price typed here also become the product's own.
class LinePriceResult {
  const LinePriceResult({required this.ratePaise, required this.discountBp, required this.saveToProduct, required this.mrpPaise, required this.costPaise});
  final int ratePaise, discountBp, mrpPaise, costPaise;
  final bool saveToProduct;
}

/// Change the price of one line of a bill or an estimate: the rate, the discount on the line, and, to work the rate out, the MRP and the discounts from it
/// (MRP 100 with a 25% selling discount gives 75). The buying price is shown only when [showCost] (the profit is on show). Save changes this line only;
/// Save to product also keeps the MRP, buying price and selling price on the product.
Future<LinePriceResult?> showLinePriceDialog(BuildContext context, {required CartLine line, required Product product, required bool showCost}) {
  return showDialog<LinePriceResult>(context: context, builder: (_) => _LinePriceDialog(line: line, product: product, showCost: showCost));
}

class _LinePriceDialog extends StatefulWidget {
  const _LinePriceDialog({required this.line, required this.product, required this.showCost});
  final CartLine line;
  final Product product;
  final bool showCost;
  @override
  State<_LinePriceDialog> createState() => _LinePriceDialogState();
}

class _LinePriceDialogState extends State<_LinePriceDialog> {
  String two(int paise) => (paise / 100).toStringAsFixed(2);
  late final mrp = TextEditingController(text: widget.product.mrpPaise > 0 ? two(widget.product.mrpPaise) : '');
  late final buy = TextEditingController(text: widget.product.costPaise > 0 ? two(widget.product.costPaise) : '');
  late final rate = TextEditingController(text: two(widget.line.rate));
  final buyPct = TextEditingController();
  final ratePct = TextEditingController();
  late final disc = TextEditingController(text: (widget.line.discountBp / 100).toString());

  @override
  void initState() {
    super.initState();
    linkPercent(base: mrp, pct: buyPct, target: buy);
    linkPercent(base: mrp, pct: ratePct, target: rate);
  }

  @override
  void dispose() {
    for (final c in [mrp, buy, rate, buyPct, ratePct, disc]) {
      c.dispose();
    }
    super.dispose();
  }

  int? paise(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    return v == null ? null : (v * 100).round();
  }

  void done(bool toProduct) {
    final r = paise(rate);
    if (r == null || r < 0) return;
    final d = double.tryParse(disc.text.trim());
    Navigator.pop(
      context,
      LinePriceResult(
        ratePaise: r,
        discountBp: d == null ? widget.line.discountBp : (d * 100).round().clamp(0, 10000),
        saveToProduct: toProduct,
        mrpPaise: paise(mrp) ?? widget.product.mrpPaise,
        costPaise: showCost ? (paise(buy) ?? widget.product.costPaise) : widget.product.costPaise,
      ),
    );
  }

  bool get showCost => widget.showCost;

  Widget box(String key, String label, TextEditingController c, {bool money = true, bool autofocus = false}) => TextField(
        key: ValueKey('lp-$key'),
        controller: c,
        autofocus: autofocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(13)],
        decoration: InputDecoration(labelText: label, prefixText: money ? '₹ ' : null, suffixText: money ? null : '%'),
        onSubmitted: (_) => done(false),
      );

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    Widget gap() => const SizedBox(height: 12);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(l.changeRate, style: th.titleLarge)),
              IconButton(tooltip: l.close, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            Text(widget.product.name, style: th.bodySmall),
            gap(),
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  box('mrp', l.purMrp, mrp),
                  if (showCost) ...[
                    gap(),
                    box('buy', l.fieldCostPrice, buy),
                    gap(),
                    box('buypct', l.fieldCostPct, buyPct, money: false),
                  ],
                  gap(),
                  box('rate', l.fieldSellPrice, rate, autofocus: true),
                  gap(),
                  box('ratepct', l.fieldSellPct, ratePct, money: false),
                  gap(),
                  box('disc', l.discountPercentLabel, disc, money: false),
                  gap(),
                  Text(l.linePriceNote, style: th.bodySmall),
                ]),
              ),
            ),
            gap(),
            Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.end, children: [
              OutlinedButton(key: const ValueKey('lp-cancel'), onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
              OutlinedButton.icon(key: const ValueKey('lp-save-product'), onPressed: () => done(true), icon: const Icon(Icons.inventory_2_rounded), label: Text(l.linePriceSaveProduct)),
              FilledButton.icon(key: const ValueKey('lp-save'), onPressed: () => done(false), icon: const Icon(Icons.check_rounded), label: Text(l.save)),
            ]),
          ]),
        ),
      ),
    );
  }
}
