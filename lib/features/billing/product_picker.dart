import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/models.dart';

/// The product table used in billing: a vertical, windowed table (never boxes). Full names always visible (wrap),
/// price in its own column, stock with unit, a separate "Out of stock" badge, an "in bill" badge.
/// Up/Down move, Enter adds the highlighted row (the first match by default), a scanned barcode + Enter adds that product.
class ProductPicker extends StatefulWidget {
  const ProductPicker({super.key, required this.products, required this.inBill, required this.onAdd, required this.onQuickAdd, this.onScan, this.focusNode});
  final List<Product> products;
  final Map<String, int> inBill; // productId -> qty milli
  final void Function(Product) onAdd;
  final void Function(String text) onQuickAdd;
  final VoidCallback? onScan; // called when a scanned barcode adds a product (for the optional beep)
  final FocusNode? focusNode;

  @override
  State<ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<ProductPicker> {
  final _ctl = TextEditingController();
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  final _selKey = GlobalKey();
  String _q = '';
  int _sel = 0;
  String? _tickId;
  Timer? _tickTimer;
  List<Product> _rows = const [];
  List<String> _lower = const [];

  @override
  void initState() {
    super.initState();
    _reindex();
    _rows = widget.products;
  }

  @override
  void didUpdateWidget(ProductPicker old) {
    super.didUpdateWidget(old);
    if (!identical(old.products, widget.products)) {
      _reindex();
      _filter();
    }
  }

  void _reindex() => _lower = [for (final p in widget.products) '${p.name} ${p.barcode}'.toLowerCase()];

  void _filter() {
    final tokens = _q.trim().toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) {
      _rows = widget.products;
    } else {
      final out = <Product>[];
      for (var i = 0; i < widget.products.length; i++) {
        final s = _lower[i];
        var ok = true;
        for (final t in tokens) {
          if (!s.contains(t)) {
            ok = false;
            break;
          }
        }
        if (ok) out.add(widget.products[i]);
      }
      _rows = out;
    }
    _sel = 0;
  }

  void _onChanged(String v) => setState(() {
        _q = v;
        _filter();
      });

  void _add(Product p, {bool scanned = false}) {
    widget.onAdd(p);
    if (scanned) widget.onScan?.call();
    if (context.motion.effects) {
      _tickTimer?.cancel();
      _tickId = p.id;
      _tickTimer = Timer(const Duration(milliseconds: 900), () => mounted ? setState(() => _tickId = null) : null);
    }
    _ctl.clear();
    setState(() {
      _q = '';
      _filter();
    });
    _focus.requestFocus();
  }

  void _enter() {
    if (_rows.isEmpty) {
      if (_q.trim().isNotEmpty) widget.onQuickAdd(_q.trim());
      return;
    }
    final row = _rows[_sel.clamp(0, _rows.length - 1)];
    final scanned = RegExp(r'^[0-9]{8,}$').hasMatch(_q.trim()) && row.barcode == _q.trim();
    _add(row, scanned: scanned);
  }

  void _move(int d) {
    if (_rows.isEmpty) return;
    setState(() => _sel = (_sel + d).clamp(0, _rows.length - 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Duration.zero);
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _ctl.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    final th = Theme.of(context).textTheme;
    final phone = context.isPhone;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
            },
            child: TextField(
              controller: _ctl,
              focusNode: _focus,
              autofocus: !phone,
              onChanged: _onChanged,
              onSubmitted: (_) {
                _enter();
              },
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.searchProductHint, suffixIcon: _q.isEmpty ? const Icon(Icons.qr_code_scanner) : IconButton(tooltip: l.clear, onPressed: () => setState(() { _ctl.clear(); _q = ''; _filter(); }), icon: const Icon(Icons.close))),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: l.addProductShortcut,
          child: OutlinedButton.icon(onPressed: () => widget.onQuickAdd(_q.trim()), icon: const Icon(Icons.add), label: Text(phone ? l.add : l.addProduct)),
        ),
      ]),
      const SizedBox(height: 8),
      if (!phone)
        Container(
          color: c.surfaceAlt,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(child: Text(l.colProduct, style: th.labelMedium?.copyWith(color: c.textMuted))),
            SizedBox(width: 96, child: Text(l.colPrice, textAlign: TextAlign.right, style: th.labelMedium?.copyWith(color: c.textMuted))),
            SizedBox(width: 140, child: Text(l.colStock, textAlign: TextAlign.right, style: th.labelMedium?.copyWith(color: c.textMuted))),
          ]),
        ),
      Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: c.border.withValues(alpha: 0.6)), borderRadius: phone ? BorderRadius.circular(Radii.m) : const BorderRadius.vertical(bottom: Radius.circular(Radii.m))),
          child: _rows.isEmpty
              ? _NoProduct(text: _q.trim(), onAdd: () => widget.onQuickAdd(_q.trim()))
              : RepaintBoundary(child: ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: c.border.withValues(alpha: 0.5)),
                  itemBuilder: (ctx, i) => _ProductRow(
                    key: i == _sel ? _selKey : null,
                    product: _rows[i],
                    selected: i == _sel,
                    inBill: widget.inBill[_rows[i].id] ?? 0,
                    onTap: () => _add(_rows[i]),
                    phone: phone,
                    ticked: _rows[i].id == _tickId,
                  ),
                )),
        ),
      ),
    ]);
  }
}

class _NoProduct extends StatelessWidget {
  const _NoProduct({required this.text, required this.onAdd});
  final String text;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    return InkWell(
      onTap: onAdd,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(l.noProductFound, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(text.isEmpty ? l.addProduct : l.addNamed(text), softWrap: true)),
        ]),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({super.key, required this.product, required this.selected, required this.inBill, required this.onTap, required this.phone, required this.ticked});
  final bool ticked;
  final Product product;
  final bool selected, phone;
  final int inBill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    final th = Theme.of(context).textTheme;
    final p = product;
    final name = Text.rich(
      TextSpan(children: [
        TextSpan(text: p.name, style: th.titleMedium?.copyWith(fontWeight: FontWeight.w700)), // wraps, never an ellipsis
        WidgetSpan(alignment: PlaceholderAlignment.middle, child: AnimatedOpacity(opacity: ticked ? 1 : 0, duration: context.motion.fx(150), child: Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.check_circle, size: 20, color: c.success)))),
      ]),
    );
    final badges = Wrap(spacing: 6, runSpacing: 4, children: [
      if (inBill > 0) StatusBadge(l.inBillQty(formatQty(inBill)), kind: BadgeKind.info, icon: Icons.shopping_cart_outlined),
    ]);
    final stock = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('${formatQty(p.stockMilli)} ${p.unit}', style: th.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: p.outOfStock ? c.danger : null)),
      if (p.outOfStock) Padding(padding: const EdgeInsets.only(top: 3), child: StatusBadge(l.outOfStock, kind: BadgeKind.danger, icon: Icons.block)),
      if (p.lowStock) Padding(padding: const EdgeInsets.only(top: 3), child: StatusBadge(l.lowStock, kind: BadgeKind.warning)),
    ]);
    return Semantics(
      button: true,
      label: '${p.name}, ${formatPaise(p.pricePaise)}, ${p.outOfStock ? l.outOfStock : '${formatQty(p.stockMilli)} ${p.unit}'}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: selected ? c.rowSelected : null,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: (phone ? 10 : 9) * context.metrics.factor),
          constraints: BoxConstraints(minHeight: context.metrics.rowHeight + 4),
          child: phone
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [name, const SizedBox(height: 4), Text('₹ ${formatPaise(p.pricePaise)}', style: th.titleSmall?.copyWith(color: c.primary)), badges])),
                  const SizedBox(width: 8),
                  stock,
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [name, if (inBill > 0) Padding(padding: const EdgeInsets.only(top: 4), child: badges)])),
                  SizedBox(width: 96, child: Text(formatPaise(p.pricePaise), textAlign: TextAlign.right, style: th.titleMedium)),
                  SizedBox(width: 140, child: stock),
                ]),
        ),
      ),
    );
  }
}
