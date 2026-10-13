import 'package:flutter/material.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../design/form_sheet.dart';
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
    return LayoutBuilder(builder: (ctx, bc) => _buildLines(ctx, lines, bc.maxWidth < 560));
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
            const Spacer(),
            InkWell(onTap: editRate, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: Text('${formatPaise(line.rate)} ×', style: th.bodySmall))),
            SizedBox(width: 84, child: amount),
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

    final details = Wrap(spacing: 14, runSpacing: 2, children: [
      Text(l.itemsCount(calc.itemCount.toString()), style: th.bodySmall),
      Text('${l.taxable}: ${formatPaise(calc.taxable)}', style: th.bodySmall),
      Text('CGST: ${formatPaise(calc.cgst)}', style: th.bodySmall),
      Text('SGST: ${formatPaise(calc.sgst)}', style: th.bodySmall),
      if (calc.discount > 0) Text('${l.discount}: -${formatPaise(calc.discount)}', style: th.bodySmall),
      Text('${l.roundOff}: ${calc.roundOff >= 0 ? '+' : ''}${formatPaise(calc.roundOff)}', style: th.bodySmall),
    ]);

    final total = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: Text(l.grandTotal, style: th.titleMedium)),
      Semantics(
        label: l.grandTotal,
        child: Text('₹ ${formatPaise(calc.grandTotal)}', key: const ValueKey('grandTotal'), style: th.displaySmall?.copyWith(color: c.primary, fontWeight: FontWeight.w800)),
      ),
    ]);

    final pay = invoice
        ? SegmentedButton<PayMode>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(minimumSize: const Size(0, 44), textStyle: th.labelMedium),
            segments: [
              ButtonSegment(value: PayMode.cash, label: Text(l.payCash), icon: const Icon(Icons.payments_outlined, size: 18)),
              ButtonSegment(value: PayMode.upi, label: Text(l.payUpi), icon: const Icon(Icons.qr_code_2, size: 18)),
              ButtonSegment(value: PayMode.card, label: Text(l.payCard), icon: const Icon(Icons.credit_card, size: 18)),
              ButtonSegment(value: PayMode.credit, label: Text(l.payCredit), icon: const Icon(Icons.schedule, size: 18)),
            ],
            selected: {cart.pay},
            onSelectionChanged: (s) => onPay(s.first),
          )
        : Row(children: [Icon(Icons.info_outline, size: 18, color: c.textMuted), const SizedBox(width: 8), Expanded(child: Text(l.estimateNoStock, style: th.bodySmall))]);

    final saveLabel = invoice ? l.saveBill : l.saveEstimate;
    final buttons = LayoutBuilder(builder: (ctx, bc) {
      final narrow = bc.maxWidth < 520;
      Widget lbl(String t) => FittedBox(fit: BoxFit.scaleDown, child: Text(t, textAlign: TextAlign.center));
      Widget? ic(IconData i) => narrow ? null : Icon(i);
      return Row(children: [
        Expanded(
          flex: 3,
          child: Tooltip(message: 'Ctrl+S', child: FilledButton.icon(onPressed: empty ? null : onSave, icon: ic(Icons.save_outlined), label: lbl(saveLabel))),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Tooltip(message: 'F9', child: FilledButton.tonalIcon(onPressed: empty ? null : onSavePrint, icon: ic(Icons.print_outlined), label: lbl(l.saveAndPrint))),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Tooltip(message: 'F8', child: OutlinedButton.icon(onPressed: empty ? null : onPreview, icon: ic(Icons.visibility_outlined), label: lbl(l.preview))),
        ),
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
