import 'package:flutter/material.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../design/form_sheet.dart';
import '../../design/segments.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain_lite/bill_calc.dart';
import '../../fake/models.dart';
import 'cart.dart';

/// Header of the bill: customer + number/date, plus the "editing" bar for saved estimations.
class BillHeader extends StatelessWidget {
  const BillHeader({super.key, required this.mode, required this.cart, required this.number, required this.date, required this.onPickCustomer});
  final DocMode mode;
  final CartState cart;
  final String number;
  final DateTime date;
  final VoidCallback onPickCustomer;

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    final th = Theme.of(context).textTheme;
    final cust = cart.customer;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (cart.editingNumber != null)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.badgeBgInfo, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.info.withValues(alpha: 0.5))),
          child: Row(children: [
            Icon(Icons.edit_note, color: c.info),
            const SizedBox(width: 8),
            Expanded(child: Text(l.editingKeeps(cart.editingNumber!, formatDate(cart.editingDate!)), style: th.bodyMedium?.copyWith(color: c.info))),
          ]),
        ),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickCustomer,
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, minimumSize: const Size(0, Sizes.touch)),
            icon: const Icon(Icons.person_outline),
            label: Text(cust?.name ?? l.walkInCustomer, maxLines: 2, overflow: TextOverflow.fade),
          ),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(number, style: th.titleSmall),
          Text(formatDate(date), style: th.bodySmall),
        ]),
      ]),
      if (cust != null && cust.balancePaise > 0)
        Padding(padding: const EdgeInsets.only(top: 6), child: StatusBadge(l.customerOwes(formatPaise(cust.balancePaise, symbol: true)), kind: BadgeKind.warning, icon: Icons.account_balance_wallet_outlined)),
    ]);
  }
}

/// The bill lines. This list scrolls INSIDE itself; the footer is never part of it.
class BillLines extends StatefulWidget {
  const BillLines({super.key, required this.mode, required this.cart, required this.calc, required this.onQty, required this.onRemove, required this.onRate, required this.onDiscount});
  final DocMode mode;
  final CartState cart;
  final BillCalc calc;
  final void Function(int index, int qtyMilli) onQty;
  final void Function(int index) onRemove;
  final void Function(int index, int ratePaise) onRate;
  final void Function(int index, int bp) onDiscount;
  @override
  State<BillLines> createState() => _BillLinesState();
}

class _BillLinesState extends State<BillLines> {
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void didUpdateWidget(BillLines old) {
    super.didUpdateWidget(old);
    if (widget.cart.lines.length > _lastCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
    _lastCount = widget.cart.lines.length;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final lines = widget.cart.lines;
    if (lines.isEmpty) {
      return EmptyState(icon: Icons.shopping_cart_outlined, title: l.billEmptyTitle, text: l.billEmptyText);
    }
    return LayoutBuilder(builder: (ctx, bc) => _buildLines(ctx, lines, bc.maxWidth / ctx.textFactor < 560));
  }

  Widget _buildLines(BuildContext context, List<CartLine> lines, bool phone) {
    final l = tr(context);
    final c = context.c;
    return Column(children: [
      if (!phone)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Row(children: [
            const SizedBox(width: 26),
            Expanded(child: Text(l.colItem, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.textMuted))),
            SizedBox(width: 150, child: Center(child: Text(l.colQty, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.textMuted)))),
            SizedBox(width: 78, child: Text(l.colRate, textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.textMuted))),
            SizedBox(width: 92, child: Text(l.colAmount, textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.textMuted))),
            const SizedBox(width: 40),
          ]),
        ),
      Expanded(
        child: Scrollbar(
          controller: _scroll,
          child: ListView.separated(
            controller: _scroll,
            itemCount: lines.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: c.border.withValues(alpha: 0.5)),
            itemBuilder: (ctx, i) => _LineRow(
              index: i,
              line: lines[i],
              calc: widget.calc.lines[i],
              phone: phone,
              onQty: (q) => widget.onQty(i, q),
              onRemove: () => widget.onRemove(i),
              onRate: (r) => widget.onRate(i, r),
              onDiscount: (d) => widget.onDiscount(i, d),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.index, required this.line, required this.calc, required this.phone, required this.onQty, required this.onRemove, required this.onRate, required this.onDiscount});
  final int index;
  final CartLine line;
  final LineCalc calc;
  final bool phone;
  final void Function(int) onQty;
  final VoidCallback onRemove;
  final void Function(int) onRate;
  final void Function(int) onDiscount;

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    final th = Theme.of(context).textTheme;
    final p = line.product;
    final over = line.qtyMilli > p.stockMilli;
    final name = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(p.name, style: th.titleSmall),
      if (over) Padding(padding: const EdgeInsets.only(top: 3), child: StatusBadge(p.stockMilli <= 0 ? l.warnNoStock : l.warnLowStock(formatQty(p.stockMilli), p.unit), kind: BadgeKind.warning, icon: Icons.warning_amber_rounded)),
      if (line.discountBp > 0) Padding(padding: const EdgeInsets.only(top: 3), child: Text(l.discountPercent((line.discountBp / 100).toStringAsFixed(line.discountBp % 100 == 0 ? 0 : 1)), style: th.bodySmall)),
    ]);
    final stepper = _QtyStepper(qtyMilli: line.qtyMilli, unit: p.unit, onChanged: onQty);
    final amount = Text(formatPaise(calc.total), style: th.titleSmall, textAlign: TextAlign.right);
    final del = IconButton(tooltip: l.removeLine, onPressed: onRemove, icon: Icon(Icons.delete_outline, color: c.danger));
    Future<void> editRate() async {
      final v = await showFormSheet(context, title: l.changeRate, saveLabel: l.save, fields: [FieldSpec('rate', l.colRate, type: FieldType.money, initial: (line.rate / 100).toStringAsFixed(2), required: true, autofocus: true), FieldSpec('disc', l.discountPercentLabel, type: FieldType.number, initial: (line.discountBp / 100).toString())]);
      if (v == null) return;
      final r = double.tryParse(v['rate'] ?? '');
      final d = double.tryParse(v['disc'] ?? '');
      if (r != null) onRate((r * 100).round());
      if (d != null) onDiscount((d * 100).round());
    }

    if (phone) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 2, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(right: 8), child: name),
          const SizedBox(height: 4),
          Row(children: [
            stepper,
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  InkWell(onTap: editRate, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: Text('${formatPaise(line.rate)} ×', style: th.bodySmall))),
                  amount,
                ]),
              ),
            ),
            del,
          ]),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 26, child: Text('${index + 1}', style: th.bodySmall)),
        Expanded(child: name),
        SizedBox(width: 150, child: Center(child: stepper)),
        SizedBox(
          width: 78,
          child: InkWell(
            onTap: editRate,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(formatPaise(line.rate), textAlign: TextAlign.right, style: th.bodyMedium)),
          ),
        ),
        SizedBox(width: 92, child: amount),
        SizedBox(width: 40, child: del),
      ]),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qtyMilli, required this.unit, required this.onChanged});
  final int qtyMilli;
  final String unit;
  final void Function(int) onChanged;
  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    Widget btn(IconData i, String tip, VoidCallback f) => SizedBox(
          width: 40,
          height: 40,
          child: IconButton(tooltip: tip, padding: EdgeInsets.zero, style: IconButton.styleFrom(backgroundColor: c.surfaceAlt, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: f, icon: Icon(i, size: 20)),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(Icons.remove, l.lessQty, () => onChanged(qtyMilli - 1000)),
      InkWell(
        onTap: () async {
          final v = await showFormSheet(context, title: l.changeQty, saveLabel: l.save, fields: [FieldSpec('q', '${l.colQty} ($unit)', type: FieldType.number, initial: formatQty(qtyMilli), required: true, autofocus: true)]);
          final q = double.tryParse(v?['q'] ?? '');
          if (q != null && q > 0) onChanged((q * 1000).round());
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          alignment: Alignment.center,
          child: Text(formatQty(qtyMilli), style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
      btn(Icons.add, l.moreQty, () => onChanged(qtyMilli + 1000)),
    ]);
  }
}

/// PINNED footer: totals, payment mode and the action buttons. It sits outside every scroll view, so it never moves.
/// With very large text the GST detail collapses into one short row and the buttons stack, but Grand total and the
/// three buttons are always fully visible.
class BillFooter extends StatelessWidget {
  const BillFooter({super.key, required this.mode, required this.cart, required this.calc, required this.onPay, required this.onSave, required this.onSavePrint, required this.onPreview, required this.onClear});
  final DocMode mode;
  final CartState cart;
  final BillCalc calc;
  final void Function(PayMode) onPay;
  final VoidCallback onSave, onSavePrint, onPreview, onClear;

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    final th = Theme.of(context).textTheme;
    final phone = context.isPhone;
    final empty = cart.lines.isEmpty;
    final invoice = mode == DocMode.invoice;
    final big = context.textFactor >= 1.4;

    // One line, always the same height (so the footer never moves), shrinking to fit instead of wrapping or clipping.
    final lineH = MediaQuery.textScalerOf(context).scale(th.bodySmall!.fontSize ?? 12) * 1.5;
    final detailText = big
        ? '${l.itemsCount(calc.itemCount.toString())}  ·  ${l.taxable}: ${formatPaise(calc.taxable)}  ·  GST: ${formatPaise(calc.tax)}'
        : '${l.itemsCount(calc.itemCount.toString())}   ${l.taxable}: ${formatPaise(calc.taxable)}   CGST: ${formatPaise(calc.cgst)}   SGST: ${formatPaise(calc.sgst)}'
            '${calc.discount > 0 ? '   ${l.discount}: -${formatPaise(calc.discount)}' : ''}   ${l.roundOff}: ${calc.roundOff >= 0 ? '+' : ''}${formatPaise(calc.roundOff)}';
    final Widget details = SizedBox(
      height: lineH,
      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(detailText, style: th.bodySmall, maxLines: 1, softWrap: false)),
    );

    final totalH = MediaQuery.textScalerOf(context).scale(th.displaySmall?.fontSize ?? 28) * 1.45;
    final total = SizedBox(height: totalH, child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Flexible(flex: 0, child: Text(l.grandTotal, style: th.titleMedium)),
      const SizedBox(width: 8),
      Expanded(
        child: Semantics(
          label: l.grandTotal,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text('₹ ${formatPaise(calc.grandTotal)}', key: const ValueKey('grandTotal'), maxLines: 1, style: th.displaySmall?.copyWith(color: c.primary, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    ]));

    final Widget pay = invoice
        ? SlideSegments<PayMode>(
            options: [
              (PayMode.cash, l.payCash, Icons.payments_outlined),
              (PayMode.upi, l.payUpi, Icons.qr_code_2),
              (PayMode.card, l.payCard, Icons.credit_card),
              (PayMode.credit, l.payCredit, Icons.schedule),
            ],
            selected: cart.pay,
            onChanged: onPay,
          )
        : Row(children: [Icon(Icons.info_outline, size: 18, color: c.textMuted), const SizedBox(width: 8), Expanded(child: Text(l.estimateNoStock, style: th.bodySmall))]);

    final saveLabel = invoice ? l.saveBill : l.saveEstimate;
    final buttons = LayoutBuilder(builder: (ctx, bc) {
      final w = bc.maxWidth / ctx.textFactor;
      final narrow = w < 520;
      final stacked = big && bc.maxWidth < 640;
      Widget lbl(String t) => FittedBox(fit: BoxFit.scaleDown, child: Text(t, textAlign: TextAlign.center, maxLines: 1));
      Widget? ic(IconData i) => narrow ? null : Icon(i);
      final save = Tooltip(message: 'Ctrl+S', child: FilledButton.icon(onPressed: empty ? null : onSave, icon: ic(Icons.save_outlined), label: lbl(saveLabel)));
      final savePrint = Tooltip(message: 'F9', child: FilledButton.tonalIcon(onPressed: empty ? null : onSavePrint, icon: ic(Icons.print_outlined), label: lbl(l.saveAndPrint)));
      final preview = Tooltip(message: 'F8', child: OutlinedButton.icon(onPressed: empty ? null : onPreview, icon: ic(Icons.visibility_outlined), label: lbl(l.preview)));
      if (stacked) {
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          save,
          const SizedBox(height: 6),
          Row(children: [Expanded(flex: 3, child: savePrint), const SizedBox(width: 8), Expanded(flex: 2, child: preview)]),
        ]);
      }
      return Row(children: [
        Expanded(flex: 3, child: save),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: savePrint),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: preview),
        if (!narrow) ...[
          const SizedBox(width: 8),
          Tooltip(message: 'Esc', child: IconButton(onPressed: empty ? null : onClear, icon: const Icon(Icons.layers_clear_outlined), tooltip: l.clearBill)),
        ],
      ]);
    });

    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      padding: EdgeInsets.fromLTRB(phone ? 10 : 14, 8, phone ? 10 : 14, 10),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        details,
        const SizedBox(height: 2),
        total,
        const SizedBox(height: 6),
        pay,
        const SizedBox(height: 8),
        buttons,
      ]),
    );
  }
}
