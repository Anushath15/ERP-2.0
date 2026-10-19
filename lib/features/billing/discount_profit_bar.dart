import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain_lite/bill_calc.dart';
import 'cart.dart';

/// Whether the profit figure is on show (the owner can hide it while a customer looks at the screen). Not saved: it is shown again
/// the next time the program starts.
class ShowProfit extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final showProfitProvider = NotifierProvider<ShowProfit, bool>(ShowProfit.new);

/// Under the items of a bill or an estimate: a discount on the WHOLE bill (typed as an amount or as a percent: either works, the
/// other one follows) and the profit the shop makes on it. The profit is for the owner only: it is never printed, saved on the bill
/// or shown to the customer.
class DiscountProfitBar extends ConsumerStatefulWidget {
  const DiscountProfitBar({super.key, required this.mode, required this.cart, required this.calc, required this.onAmount, required this.onPercent});
  final DocMode mode;
  final CartState cart;
  final BillCalc calc;
  final void Function(int paise) onAmount;
  final void Function(int bp) onPercent;

  @override
  ConsumerState<DiscountProfitBar> createState() => _DiscountProfitBarState();
}

class _DiscountProfitBarState extends ConsumerState<DiscountProfitBar> {
  final _amount = TextEditingController();
  final _percent = TextEditingController();
  final _amountFocus = FocusNode();
  final _percentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(DiscountProfitBar old) {
    super.didUpdateWidget(old);
    _follow();
  }

  @override
  void dispose() {
    _amount.dispose();
    _percent.dispose();
    _amountFocus.dispose();
    _percentFocus.dispose();
    super.dispose();
  }

  int get _before => widget.calc.lines.fold<int>(0, (a, x) => a + x.total + x.extraShare);

  static String _pct(int bp) => bp % 100 == 0 ? '${bp ~/ 100}' : (bp / 100).toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  /// The field NOT being typed in follows the one that is (and both follow the bill when its total changes).
  void _follow() {
    final extra = widget.calc.extraDiscount;
    final percentMode = widget.cart.extraDiscountBp > 0;
    if (!_amountFocus.hasFocus) {
      final t = extra > 0 ? (extra / 100).toStringAsFixed(2) : '';
      if (_amount.text != t) _amount.text = t;
    }
    if (!_percentFocus.hasFocus) {
      final t = percentMode ? _pct(widget.cart.extraDiscountBp) : (extra > 0 && _before > 0 ? _pct((extra * 10000 / _before).round()) : '');
      if (_percent.text != t) _percent.text = t;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final c = context.c;
    if (widget.cart.lines.isEmpty) return const SizedBox.shrink();
    final show = ref.watch(showProfitProvider);
    final profit = billProfit(widget.cart.lines, widget.calc);
    final hasDiscount = widget.calc.extraDiscount > 0;

    final amount = SizedBox(
      width: 130,
      child: TextField(
        key: const ValueKey('disc-amount'),
        controller: _amount,
        focusNode: _amountFocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(12)],
        decoration: InputDecoration(labelText: l.discAmount, prefixText: '₹ ', isDense: true),
        onChanged: (v) => widget.onAmount(((double.tryParse(v) ?? 0) * 100).round()),
      ),
    );
    final percent = SizedBox(
      width: 110,
      child: TextField(
        key: const ValueKey('disc-percent'),
        controller: _percent,
        focusNode: _percentFocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(6)],
        decoration: InputDecoration(labelText: l.discPercent, suffixText: '%', isDense: true),
        onChanged: (v) => widget.onPercent(((double.tryParse(v) ?? 0) * 100).round()),
      ),
    );

    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(l.discBarTitle, style: th.labelLarge),
        amount,
        percent,
        if (hasDiscount) IconButton(key: const ValueKey('disc-clear'), tooltip: l.discClear, onPressed: () => widget.onAmount(0), icon: const Icon(Icons.close, size: 18)),
        Tooltip(
          message: l.profitPrivate,
          child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, size: 16, color: c.textMuted),
            const SizedBox(width: 4),
            Text(widget.mode == DocMode.invoice ? l.profitOnBill : l.profitOnEstimate, style: th.bodySmall),
            const SizedBox(width: 6),
            Text(show ? '₹ ${formatPaise(profit)}' : '₹ ••••', key: const ValueKey('profit-value'), style: th.titleSmall?.copyWith(color: profit < 0 ? c.danger : c.success, fontWeight: FontWeight.w700)),
            IconButton(
              key: const ValueKey('profit-toggle'),
              tooltip: show ? l.profitHide : l.profitShow,
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(showProfitProvider.notifier).toggle(),
              icon: Icon(show ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
            ),
          ])),
        ),
      ]),
    );
  }
}
