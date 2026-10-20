import 'package:flutter/material.dart';
import '../../core/date_fmt.dart';
import 'package:flutter/services.dart';
import '../../core/money.dart';
import '../../domain/credit/payment_split.dart';
import '../../core/responsive.dart';
import '../../design/effects.dart';
import '../../design/form_sheet.dart';
import '../../design/segments.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain_lite/bill_calc.dart';
import '../../fake/models.dart';
import 'cart.dart';

/// Header of the bill: customer + number/date, plus the "editing" bar for saved estimations.
class BillHeader extends StatelessWidget {
  const BillHeader({super.key, required this.mode, required this.cart, required this.number, required this.date, required this.onPickCustomer, this.onEditGst, this.balance = 0});
  final int balance; // the customer's credit balance now (negative = advance)
  final DocMode mode;
  final CartState cart;
  final String number;
  final DateTime date;
  final VoidCallback onPickCustomer;

  /// Opens the customer's GST number (a tax invoice prints it). Null on an estimate: it carries no GST.
  final VoidCallback? onEditGst;

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
            Icon(Icons.edit_note_rounded, color: c.info),
            const SizedBox(width: 8),
            Expanded(child: Text(l.editingKeeps(cart.editingNumber!, formatDate(cart.editingDate!)), style: th.bodyMedium?.copyWith(color: c.info))),
          ]),
        ),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickCustomer,
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, minimumSize: const Size(0, Sizes.touch)),
            icon: const Icon(Icons.person_outline_rounded),
            label: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(cust?.name ?? l.walkInCustomer, maxLines: 2, overflow: TextOverflow.fade),
              if (onEditGst != null && cust != null && cust.gstin.isNotEmpty) Text(l.gstOnBill(cust.gstin), key: const ValueKey('bill-gst-text'), style: th.bodySmall),
            ]),
          ),
        ),
        // GST number of the customer for the tax invoice: an icon beside the customer (no extra height on the bill screen)
        if (onEditGst != null) ...[
          const SizedBox(width: 6),
          IconButton.outlined(
            key: const ValueKey('bill-gst'),
            tooltip: cust == null ? l.gstPickCustomer : (cust.gstin.isEmpty ? l.gstAddForBill : l.gstEditTitle),
            onPressed: cust == null ? onPickCustomer : onEditGst,
            icon: Icon(cust != null && cust.gstin.isNotEmpty ? Icons.receipt_long_rounded : Icons.receipt_long_rounded),
          ),
        ],
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(number, style: th.titleSmall),
          Text(formatDate(date), style: th.bodySmall),
        ]),
      ]),
      if (cust != null && balance > 0)
        Padding(padding: const EdgeInsets.only(top: 6), child: StatusBadge(l.customerOwes(formatPaise(balance, symbol: true)), kind: BadgeKind.warning, icon: Icons.account_balance_wallet_rounded)),
      if (cust != null && balance < 0)
        Padding(padding: const EdgeInsets.only(top: 6), child: StatusBadge(l.advanceAmount(formatPaise(-balance, symbol: true)), kind: BadgeKind.success, icon: Icons.savings_rounded)),
    ]);
  }
}

/// The bill lines. This list scrolls INSIDE itself; the footer is never part of it.
class BillLines extends StatefulWidget {
  const BillLines({super.key, required this.mode, required this.cart, required this.calc, required this.onQty, required this.onRemove, required this.onRate, required this.onDiscount, this.trailing, this.variants = const {}, this.onBrand});
  final DocMode mode;
  final CartState cart;
  final BillCalc calc;
  final void Function(int index, int qtyMilli) onQty;
  final void Function(int index) onRemove;
  final void Function(int index, int ratePaise) onRate;

  /// Products that exist in more than one brand (see [productVariantsProvider]) and what to do when the person picks another brand for a line.
  final Map<String, List<Product>> variants;
  final void Function(int index, Product other)? onBrand;
  final void Function(int index, int bp) onDiscount;

  /// Shown after the last item, inside the scrolling list (the discount on the whole bill and the profit).
  final Widget? trailing;
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
      return EmptyState(icon: Icons.shopping_cart_rounded, title: l.billEmptyTitle, text: l.billEmptyText);
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
          child: RepaintBoundary(child: ListView.separated(
            controller: _scroll,
            itemCount: lines.length + (widget.trailing == null ? 0 : 1),
            separatorBuilder: (_, _) => Divider(height: 1, color: c.border.withValues(alpha: 0.5)),
            itemBuilder: (ctx, i) => i >= lines.length ? widget.trailing! : _LineRow(
              key: ValueKey(lines[i].product.id),
              fresh: widget.cart.touchedNew && widget.cart.touchedId == lines[i].product.id && DateTime.now().millisecondsSinceEpoch - widget.cart.touchedAtMs < 600,
              touchSeq: widget.cart.touchedId == lines[i].product.id ? widget.cart.touchSeq : 0,
              index: i,
              line: lines[i],
              calc: widget.calc.lines[i],
              phone: phone,
              onQty: (q) => widget.onQty(i, q),
              onRemove: () => widget.onRemove(i),
              onRate: (r) => widget.onRate(i, r),
              onDiscount: (d) => widget.onDiscount(i, d),
              brands: widget.onBrand == null ? const [] : (widget.variants[variantKey(lines[i].product)] ?? const []),
              onBrand: (other) => widget.onBrand?.call(i, other),
            ),
          )),
        ),
      ),
    ]);
  }
}

class _LineBody extends StatelessWidget {
  const _LineBody({required this.index, required this.line, required this.calc, required this.phone, required this.onQty, required this.onRemove, required this.onRate, required this.onDiscount, this.brands = const [], this.onBrand});
  final int index;
  final CartLine line;
  final LineCalc calc;
  final bool phone;
  final void Function(int) onQty;
  final VoidCallback onRemove;
  final void Function(int) onRate;
  final void Function(int) onDiscount;

  /// The same product in other brands (empty when there is only this one) and the switch to one of them.
  final List<Product> brands;
  final void Function(Product)? onBrand;

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    final th = Theme.of(context).textTheme;
    final p = line.product;
    final over = line.qtyMilli > p.stockMilli;
    final name = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(p.name, style: th.titleSmall),
      if (p.brand.trim().isNotEmpty || brands.isNotEmpty)
        brands.isEmpty
            ? Text(p.brand.trim(), key: ValueKey('line-brand-$index'), style: th.bodySmall?.copyWith(color: c.textMuted, fontWeight: FontWeight.w600))
            : PopupMenuButton<Product>(
                key: ValueKey('brand-switch-$index'),
                tooltip: l.changeBrand,
                onSelected: (o) => onBrand?.call(o),
                itemBuilder: (_) => [
                  for (final o in [p, ...brands])
                    CheckedPopupMenuItem<Product>(
                      value: o,
                      checked: o.id == p.id,
                      child: Text('${o.brand.trim().isEmpty ? l.noBrand : o.brand.trim()}  -  ${formatPaise(o.pricePaise, symbol: true)}  -  ${formatQty(o.stockMilli)} ${o.unit}'),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(p.brand.trim().isEmpty ? l.noBrand : p.brand.trim(), style: th.bodySmall?.copyWith(color: c.primary, fontWeight: FontWeight.w700)),
                    Icon(Icons.arrow_drop_down_rounded, size: 20, color: c.primary),
                  ]),
                ),
              ),
      if (over) Padding(padding: const EdgeInsets.only(top: 3), child: StatusBadge(p.stockMilli <= 0 ? l.warnNoStock : l.warnLowStock(formatQty(p.stockMilli), p.unit), kind: BadgeKind.warning, icon: Icons.warning_amber_rounded)),
      if (line.discountBp > 0) Padding(padding: const EdgeInsets.only(top: 3), child: Text(l.discountPercent((line.discountBp / 100).toStringAsFixed(line.discountBp % 100 == 0 ? 0 : 1)), style: th.bodySmall)),
    ]);
    final stepper = _QtyStepper(qtyMilli: line.qtyMilli, unit: p.unit, onChanged: onQty);
    final amount = Text(formatPaise(calc.total), style: th.titleSmall, textAlign: TextAlign.right);
    final del = IconButton(tooltip: l.removeLine, onPressed: onRemove, icon: Icon(Icons.delete_outline_rounded, color: c.danger));
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

/// One bill line. A line that was JUST added slides in and flashes briefly (Full only); nothing here delays the add itself.
class _LineRow extends StatelessWidget {
  const _LineRow({super.key, required this.fresh, required this.touchSeq, required this.index, required this.line, required this.calc, required this.phone, required this.onQty, required this.onRemove, required this.onRate, required this.onDiscount, this.brands = const [], this.onBrand});
  final bool fresh;
  final int touchSeq;
  final int index;
  final CartLine line;
  final LineCalc calc;
  final bool phone;
  final void Function(int) onQty;
  final VoidCallback onRemove;
  final void Function(int) onRate;
  final void Function(int) onDiscount;
  final List<Product> brands;
  final void Function(Product)? onBrand;

  @override
  Widget build(BuildContext context) => FadeSlideIn(
        enabled: fresh,
        flash: true,
        dx: 18,
        dy: 0,
        ms: 220,
        child: _LineBody(index: index, line: line, calc: calc, phone: phone, onQty: onQty, onRemove: onRemove, onRate: onRate, onDiscount: onDiscount, brands: brands, onBrand: onBrand),
      );
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
      btn(Icons.remove_rounded, l.lessQty, () => onChanged(qtyMilli - 1000)),
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
          child: PulseOnChange(token: qtyMilli, child: Text(formatQty(qtyMilli), style: Theme.of(context).textTheme.titleMedium)),
        ),
      ),
      btn(Icons.add_rounded, l.moreQty, () => onChanged(qtyMilli + 1000)),
    ]);
  }
}

/// PINNED footer: totals, payment mode and the action buttons. It sits outside every scroll view, so it never moves.
/// With very large text the GST detail collapses into one short row and the buttons stack, but Grand total and the
/// three buttons are always fully visible.
class BillFooter extends StatelessWidget {
  const BillFooter({super.key, required this.mode, required this.cart, required this.calc, required this.onPay, required this.onReceived, required this.onKeepAdvance, this.customerName, this.customerBalance, this.onShowQr, required this.onSave, required this.onSavePrint, required this.onClear});

  /// Shows the UPI QR code (set only while UPI is the chosen way to pay).
  final VoidCallback? onShowQr;
  final DocMode mode;
  final CartState cart;
  final BillCalc calc;
  final void Function(PayMode) onPay;
  final void Function(int? paise) onReceived; // null = the full Grand Total
  final void Function(bool keep) onKeepAdvance;
  final String? customerName; // null = walk-in
  final int? customerBalance; // what the named customer owes now (negative = advance)
  final VoidCallback onSave, onSavePrint, onClear;

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    final th = Theme.of(context).textTheme;
    final phone = context.isPhone;
    final empty = cart.lines.isEmpty;
    final invoice = mode == DocMode.invoice;
    final big = context.textFactor >= 1.4;
    // very large text on a short window: the GST detail line is dropped so Grand total, Received and the buttons keep their room
    final tight = big && MediaQuery.sizeOf(context).height <= 800;

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
            child: AnimatedMoney(paise: calc.grandTotal, textKey: const ValueKey('grandTotal'), style: th.displaySmall?.copyWith(color: c.primary, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    ]));

    final Widget pay = invoice
        ? PaymentArea(cart: cart, calc: calc, customerName: customerName, customerBalance: customerBalance, onPay: onPay, onReceived: onReceived, onKeepAdvance: onKeepAdvance, onShowQr: onShowQr)
        : Row(children: [Icon(Icons.info_outline_rounded, size: 18, color: c.textMuted), const SizedBox(width: 8), Expanded(child: Text(l.estimateNoStock, style: th.bodySmall))]);

    final saveLabel = invoice ? l.saveBill : l.saveEstimate;
    final buttons = LayoutBuilder(builder: (ctx, bc) {
      final w = bc.maxWidth / ctx.textFactor;
      final narrow = w < 520;
      final stacked = big && bc.maxWidth < 640;
      Widget lbl(String t) => FittedBox(fit: BoxFit.scaleDown, child: Text(t, textAlign: TextAlign.center, maxLines: 1));
      Widget? ic(IconData i) => narrow ? null : Icon(i);
      final save = Tooltip(message: 'Ctrl+S', child: PressScale(child: FilledButton.icon(onPressed: empty ? null : onSave, icon: ic(Icons.save_rounded), label: lbl(saveLabel))));
      final savePrint = Tooltip(message: 'F9', child: PressScale(child: FilledButton.tonalIcon(onPressed: empty ? null : onSavePrint, icon: ic(Icons.print_rounded), label: lbl(l.saveAndPrint))));
      if (stacked) {
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          save,
          const SizedBox(height: 6),
          savePrint,
        ]);
      }
      return Row(children: [
        Expanded(flex: 3, child: save),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: savePrint),
        if (!narrow) ...[
          const SizedBox(width: 8),
          Tooltip(message: 'Esc', child: IconButton(onPressed: empty ? null : onClear, icon: const Icon(Icons.layers_clear_rounded), tooltip: l.clearBill)),
        ],
      ]);
    });

    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      padding: EdgeInsets.fromLTRB(phone ? 10 : 14, tight ? 4 : 8, phone ? 10 : 14, tight ? 6 : 10),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!tight) ...[details, const SizedBox(height: 2)],
        total,
        SizedBox(height: tight ? 2 : 6),
        pay,
        SizedBox(height: tight ? 4 : 8),
        buttons,
      ]),
    );
  }
}

/// Payment area of the pinned footer: Amount received (defaults to the Grand Total), Full amount, a one-line status that says what
/// happens to any balance or change, and the payment mode for the part that was received. Every row has a fixed height, so the
/// footer never moves when the message changes.
class PaymentArea extends StatefulWidget {
  const PaymentArea({super.key, required this.cart, required this.calc, required this.customerName, this.customerBalance, required this.onPay, required this.onReceived, required this.onKeepAdvance, this.onShowQr});

  /// Shows the UPI QR code for the amount being received (only while UPI is the chosen way to pay).
  final VoidCallback? onShowQr;
  final CartState cart;
  final BillCalc calc;
  final String? customerName;
  final int? customerBalance;
  final void Function(PayMode) onPay;
  final void Function(int? paise) onReceived;
  final void Function(bool keep) onKeepAdvance;
  @override
  State<PaymentArea> createState() => _PaymentAreaState();
}

class _PaymentAreaState extends State<PaymentArea> {
  late final TextEditingController _ctl = TextEditingController(text: _fmt(_expected));
  final _focus = FocusNode();
  int? _typed; // the amount the person last typed, so we never overwrite their typing

  int get _total => widget.calc.grandTotal;
  int get _expected => widget.cart.receivedPaise ?? _total;
  static String _fmt(int paise) => (paise / 100).toStringAsFixed(2);

  @override
  void didUpdateWidget(PaymentArea old) {
    super.didUpdateWidget(old);
    // follow the cart: a new Grand Total (when "full") or a button that set the amount
    if ((parseRupeesToPaise(_ctl.text) ?? -1) != _expected && !(widget.cart.receivedPaise != null && widget.cart.receivedPaise == _typed)) {
      _ctl.value = TextEditingValue(text: _fmt(_expected), selection: TextSelection.collapsed(offset: _fmt(_expected).length));
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    final th = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final received = widget.cart.receivedPaise ?? _total;
    final split = splitPayment(total: _total, received: received);
    final name = widget.customerName;
    String money(int p) => formatPaise(p, symbol: true);

    // one status line, fixed height
    String text;
    Color color;
    IconData icon;
    final credit = widget.cart.pay == PayMode.credit;
    if (credit) {
      final base = l.creditSplit(money(split.settled), money(split.balance));
      if (name == null) {
        text = '$base. ${l.creditPickCustomer}';
        color = c.danger;
        icon = Icons.person_add_alt_rounded;
      } else {
        final owes = widget.customerBalance;
        text = owes == null || owes == 0 ? base : (owes > 0 ? '$base. ${l.creditOwesNow(name, money(owes))}' : '$base. ${l.creditAdvanceNow(name, money(-owes))}');
        color = split.balance > 0 ? c.warning : c.success;
        icon = Icons.schedule_rounded;
      }
    } else if (split.balance > 0) {
      if (name == null) {
        text = l.balanceNeedsCustomer(money(split.balance));
        color = c.danger;
        icon = Icons.person_add_alt_rounded;
      } else {
        text = l.balanceToCredit(money(split.balance), name);
        color = c.warning;
        icon = Icons.schedule_rounded;
      }
    } else if (split.change > 0) {
      if (name != null && widget.cart.keepAdvance) {
        text = l.advanceKeptFor(money(split.change), name);
        color = c.info;
        icon = Icons.savings_rounded;
      } else {
        text = l.changeGiveBack(money(split.change));
        color = c.info;
        icon = Icons.currency_exchange_rounded;
      }
    } else {
      text = l.paidInFull;
      color = c.success;
      icon = Icons.check_circle_outline_rounded;
    }
    final lineH = scaler.scale(th.bodyMedium?.fontSize ?? 14) * 1.5;
    final fieldH = scaler.scale(16) * 1.5 + 30;

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: fieldH.clamp(48, 140),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 5,
            child: TextField(
              key: const ValueKey('receivedField'),
              controller: _ctl,
              focusNode: _focus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              textAlignVertical: TextAlignVertical.center,
              style: th.titleMedium,
              onChanged: (v) {
                _typed = parseRupeesToPaise(v) ?? 0;
                widget.onReceived(_typed);
              },
              decoration: InputDecoration(labelText: credit ? l.paidNow : l.amountReceived, prefixText: '₹ ', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
          ),
          const SizedBox(width: 6),
          if (credit) ...[
            for (final b in [('payNothing', l.payNothing, () => widget.onReceived(0)), ('payHalf', l.payHalf, () => widget.onReceived(_total ~/ 2)), ('payFull', l.payFull, () => widget.onReceived(null))]) ...[
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  key: ValueKey(b.$1),
                  style: OutlinedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 4)),
                  onPressed: b.$3,
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(b.$2, maxLines: 1)),
                ),
              ),
            ],
          ] else ...[
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: OutlinedButton(
                key: const ValueKey('fullAmount'),
                style: OutlinedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 6)),
                onPressed: () => widget.onReceived(null),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(l.fullAmount, maxLines: 1)),
              ),
            ),
            Tooltip(message: l.nothingReceived, child: IconButton(key: const ValueKey('nothingReceived'), onPressed: () => widget.onPay(PayMode.credit), icon: const Icon(Icons.schedule_rounded))),
            if (widget.onShowQr != null) Tooltip(message: l.upiShowQr, child: IconButton(key: const ValueKey('showUpiQr'), onPressed: widget.onShowQr, icon: const Icon(Icons.qr_code_2_rounded))),
          ],
        ]),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: lineH,
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(text, key: const ValueKey('balanceLine'), maxLines: 1, style: th.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700)))),
          if (split.change > 0 && name != null)
            TextButton(key: const ValueKey('advanceToggle'), style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 6)), onPressed: () => widget.onKeepAdvance(!widget.cart.keepAdvance), child: FittedBox(fit: BoxFit.scaleDown, child: Text(widget.cart.keepAdvance ? l.giveChangeInstead : l.keepAsAdvance, maxLines: 1))),
        ]),
      ),
      const SizedBox(height: 4),
      SlideSegments<PayMode>(
        options: [
              (PayMode.cash, l.payCash, Icons.payments_rounded),
              (PayMode.upi, l.payUpi, Icons.qr_code_2_rounded),
              (PayMode.card, l.payCard, Icons.credit_card_rounded),
              (PayMode.credit, l.payCredit, Icons.schedule_rounded),
        ],
        selected: widget.cart.pay,
        onChanged: widget.onPay,
      ),
    ]);
  }
}
