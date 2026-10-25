import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../data/ids.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain/models.dart';
import '../../domain/orders.dart';
import '../../fake/data_providers.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart';
import '../../strings.dart';
import '../share/whatsapp_share.dart';
import 'order_pdf.dart';

String _statusLabel(Strings s, OrderStatus x) => switch (x) { OrderStatus.open => s.orderStatusOpen, OrderStatus.sent => s.orderStatusSent, OrderStatus.converted => s.orderStatusDone, OrderStatus.cancelled => s.orderStatusCancelled };
BadgeKind _statusKind(OrderStatus x) => switch (x) { OrderStatus.open => BadgeKind.warning, OrderStatus.sent => BadgeKind.info, OrderStatus.converted => BadgeKind.success, OrderStatus.cancelled => BadgeKind.neutral };

/// The orders made to dealers, newest first.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = tr(context);
    final orders = [for (final r in ref.watch(recsProvider('orders'))) OrderDoc.fromRec(r)]..sort((a, b) => b.date.compareTo(a.date));
    return PageFrame(
      title: s.ordersTitle,
      subtitle: s.ordersSubtitle,
      actions: [FilledButton.icon(key: const ValueKey('order-new'), onPressed: () => context.go('/orders/new'), icon: const Icon(Icons.add_rounded), label: Text(s.orderNew))],
      child: orders.isEmpty
          ? EmptyState(icon: Icons.shopping_basket_rounded, title: s.orderEmpty)
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final o = orders[i];
                return Card(
                  child: ListTile(
                    key: ValueKey('order-${o.number}'),
                    title: Text('${o.number}  -  ${o.dealerName}'),
                    subtitle: Text('${formatDate(o.date)}  -  ${s.orderItemsCount('${o.lines.length}')}${o.purchaseNo.isEmpty ? '' : '  -  ${o.purchaseNo}'}'),
                    trailing: StatusBadge(_statusLabel(s, o.status), kind: _statusKind(o.status)),
                    onTap: () => context.go('/orders/${o.id}'),
                  ),
                );
              },
            ),
    );
  }
}

class _OLine {
  _OLine(this.product, {String qty = ''}) : qty = TextEditingController(text: qty);
  final Product product;
  final TextEditingController qty;
}

/// One order: the dealer, the items with quantities, a note. Save it, send it on WhatsApp ("Order now"), and when the goods come make the purchase from it.
class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key, this.orderId});

  /// The saved order being opened; null = a new order.
  final String? orderId;

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormState();
}

class _OrderFormState extends ConsumerState<OrderFormScreen> {
  String? _dealer;
  final _note = TextEditingController();
  final _lines = <_OLine>[];
  String? _error;
  bool _busy = false;
  OrderDoc? _saved;

  @override
  void initState() {
    super.initState();
    final dealers = ref.read(recsProvider('dealers'));
    _dealer = dealers.isEmpty ? null : dealers.first.id;
    if (widget.orderId != null) {
      final rec = ref.read(recsProvider('orders')).where((r) => r.id == widget.orderId).firstOrNull;
      if (rec != null) {
        final o = OrderDoc.fromRec(rec);
        _saved = o;
        _dealer = o.dealerId;
        _note.text = o.note;
        final products = ref.read(productsProvider);
        for (final l in o.lines) {
          final p = products.where((x) => x.id == l.productId).firstOrNull ?? Product(id: l.productId, name: l.name, category: '', unit: l.unit, pricePaise: 0, costPaise: 0, stockMilli: 0, gstBp: 1800, barcode: '');
          _lines.add(_OLine(p, qty: formatQty(l.qtyMilli)));
        }
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    for (final x in _lines) {
      x.qty.dispose();
    }
    super.dispose();
  }

  bool get _locked => _saved != null && !_saved!.editable;

  List<OrderLine>? _readLines(Strings s) {
    final out = <OrderLine>[];
    for (final x in _lines) {
      final q = parseQtyMilli(x.qty.text);
      if (q == null || q <= 0) {
        setState(() => _error = s.orderNoItems);
        return null;
      }
      out.add(OrderLine(productId: x.product.id, name: x.product.name, unit: x.product.unit, qtyMilli: q));
    }
    if (out.isEmpty) {
      setState(() => _error = s.orderNoItems);
      return null;
    }
    return out;
  }

  Rec? _dealerRec() => ref.read(recsProvider('dealers')).where((d) => d.id == _dealer).firstOrNull;

  /// Saves the order (new, or the changes to a saved one). Returns it with its number, or null when something is missing.
  Future<OrderDoc?> _save({OrderStatus? status, DateTime? sentAt}) async {
    final s = tr(context);
    final dealer = _dealerRec();
    if (dealer == null) {
      setState(() => _error = s.orderNeedDealer);
      return null;
    }
    final lines = _readLines(s);
    if (lines == null) return null;
    final notifier = ref.read(recsProvider('orders').notifier);
    final old = _saved;
    final fields = OrderDoc.fields(
      date: old?.date ?? ref.read(clockProvider),
      dealerId: dealer.id,
      dealerName: dealer.s('name'),
      status: status ?? old?.status ?? OrderStatus.open,
      note: _note.text.trim(),
      lines: lines,
      purchaseNo: old?.purchaseNo ?? '',
      sentAt: sentAt ?? old?.sentAt,
    );
    final id = old?.id ?? newId();
    if (old == null) {
      notifier.add(Rec(id, fields));
    } else {
      final rec = ref.read(recsProvider('orders')).firstWhere((r) => r.id == old.id);
      notifier.replace(Rec(old.id, {...rec.f, ...fields}));
    }
    await ref.read(writeQueueProvider).flush(); // a new order has its number now
    final doc = OrderDoc.fromRec(ref.read(recsProvider('orders')).firstWhere((r) => r.id == id));
    if (mounted) setState(() => _saved = doc);
    return doc;
  }

  Future<void> _onSave() async {
    final s = tr(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final doc = await _save();
      if (doc != null && mounted) {
        toast(context, s.orderSaved(doc.number));
        if (widget.orderId == null) context.go('/orders/${doc.id}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _orderNow() async {
    final s = tr(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final doc = await _save();
      if (doc == null || !mounted) return;
      final shop = ref.read(shopProvider);
      final dealer = _dealerRec();
      final phone = dealer?.s('phone') ?? '';
      final now = ref.read(clockProvider);
      final sent = await showWhatsappShare(
        context,
        title: s.orderTitle(doc.number),
        phone: phone,
        message: orderMessage(dealerName: doc.dealerName, shopName: shop.name, shopPhone: shop.phone, number: doc.number, lines: doc.lines, note: doc.note, qty: formatQty),
        fileName: 'Order ${doc.number} ${doc.dealerName}.pdf'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-'),
        pdf: () => buildOrderPdf(order: doc, dealerPhone: dealer?.s('phone') ?? '', shop: shop, now: now),
        onNumber: (p) {
          if (dealer != null) ref.read(recsProvider('dealers').notifier).replace(dealer.with_({'phone': p}));
        },
      );
      if (sent && mounted) await _save(status: OrderStatus.sent, sentAt: now);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _makePurchase() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final doc = await _save();
      if (doc == null || !mounted) return;
      context.go('/purchases/new?dealer=${doc.dealerId}&order=${doc.id}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final s = tr(context);
    final old = _saved;
    if (old == null) return;
    final rec = ref.read(recsProvider('orders')).where((r) => r.id == old.id).firstOrNull;
    if (rec == null) return;
    ref.read(recsProvider('orders').notifier).replace(rec.with_({'status': OrderStatus.cancelled.name}));
    toast(context, s.orderCancelled);
    context.go('/orders');
  }

  void _addLow() {
    final s = tr(context);
    final have = {for (final x in _lines) x.product.id};
    final low = [for (final p in ref.read(productsProvider)) if (p.lowStock && !have.contains(p.id)) p];
    if (low.isEmpty) {
      toast(context, s.orderNoLow);
      return;
    }
    setState(() {
      for (final p in low) {
        final want = p.minStockMilli * 2 - p.stockMilli; // up to twice the minimum
        _lines.add(_OLine(p, qty: formatQty(want < 1000 ? 1000 : want)));
      }
      _error = null;
    });
    toast(context, s.orderLowAdded('${low.length}'));
  }

  @override
  Widget build(BuildContext context) {
    final s = tr(context);
    final th = Theme.of(context).textTheme;
    final c = context.c;
    final dealers = ref.watch(recsProvider('dealers'));
    final products = ref.watch(productsProvider);
    final saved = _saved;
    final locked = _locked;

    final picker = Autocomplete<Product>(
      displayStringForOption: (p) => p.name,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<Product>.empty();
        return products.where((p) => '${p.name} ${p.code} ${p.brand} ${p.barcode}'.toLowerCase().contains(q)).take(8);
      },
      onSelected: (p) => setState(() {
        if (!_lines.any((x) => x.product.id == p.id)) _lines.add(_OLine(p, qty: '1'));
        _error = null;
      }),
      fieldViewBuilder: (ctx, ctl, focus, submit) => TextField(
        key: const ValueKey('order-picker'),
        controller: ctl,
        focusNode: focus,
        enabled: !locked,
        decoration: InputDecoration(labelText: s.orderAddItem, hintText: s.purSearchHint, prefixIcon: const Icon(Icons.search_rounded)),
        onSubmitted: (_) => submit(),
      ),
      optionsViewBuilder: (ctx, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320, maxWidth: 560),
            child: ListView(shrinkWrap: true, children: [
              for (final p in options)
                ListTile(key: ValueKey('order-option-${p.id}'), dense: true, title: Text(p.name), subtitle: Text('${p.code}${p.brand.isEmpty ? '' : '  -  ${p.brand}'}  -  ${formatQty(p.stockMilli)} ${p.unit}'), onTap: () => onSelected(p)),
            ]),
          ),
        ),
      ),
    );

    Widget lineRow(_OLine x) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text('${x.product.name}${x.product.code.isEmpty ? '' : '  -  ${x.product.code}'}', style: th.titleSmall)),
            const SizedBox(width: 8),
            SizedBox(
              width: 130,
              child: TextField(
                key: ValueKey('order-qty-${x.product.id}'),
                controller: x.qty,
                enabled: !locked,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(13)],
                decoration: InputDecoration(labelText: s.orderQty, suffixText: x.product.unit, isDense: true),
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            IconButton(key: ValueKey('order-remove-${x.product.id}'), tooltip: s.delete, onPressed: locked ? null : () => setState(() => _lines.remove(x)), icon: const Icon(Icons.close_rounded, size: 18)),
          ]),
        );

    return PageFrame(
      title: saved == null ? s.orderFormTitle : s.orderTitle(saved.number),
      subtitle: saved == null ? s.ordersSubtitle : _statusLabel(s, saved.status),
      actions: [TextButton.icon(onPressed: () => context.go('/orders'), icon: const Icon(Icons.arrow_back_rounded), label: Text(s.back))],
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('order-dealer'),
              initialValue: _dealer,
              decoration: InputDecoration(labelText: s.orderDealer),
              items: [for (final d in dealers) DropdownMenuItem(value: d.id, child: Text(d.s('name')))],
              onChanged: locked ? null : (v) => setState(() => _dealer = v),
            ),
            if (saved?.sentAt != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.orderSentOn('${formatDate(saved!.sentAt!)} ${formatTime(saved.sentAt!)}'), style: th.bodySmall)),
            if (saved != null && saved.status == OrderStatus.converted) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.orderDoneHint(saved.purchaseNo), style: th.bodySmall)),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: s.purItemsTitle,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            picker,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(key: const ValueKey('order-low'), onPressed: locked ? null : _addLow, icon: const Icon(Icons.warning_amber_rounded), label: Text(s.orderLowStock))),
            for (final x in _lines) ...[const Divider(), lineRow(x)],
            const SizedBox(height: 8),
            TextField(key: const ValueKey('order-note'), controller: _note, enabled: !locked, decoration: InputDecoration(labelText: s.orderNote)),
          ]),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, key: const ValueKey('order-error'), style: th.bodyMedium?.copyWith(color: c.danger))),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (!locked) FilledButton.icon(key: const ValueKey('order-save'), onPressed: _busy ? null : _onSave, icon: const Icon(Icons.save_rounded), label: Text(s.orderSave)),
          if (!locked) FilledButton.tonalIcon(key: const ValueKey('order-now'), onPressed: _busy ? null : _orderNow, icon: const Icon(Icons.chat_rounded), label: Text(s.orderOrderNow)),
          if (!locked) OutlinedButton.icon(key: const ValueKey('order-make-purchase'), onPressed: _busy ? null : _makePurchase, icon: const Icon(Icons.shopping_cart_checkout_rounded), label: Text(s.orderMakePurchase)),
          if (saved != null && saved.editable) TextButton.icon(key: const ValueKey('order-cancel'), onPressed: _busy ? null : _cancel, icon: Icon(Icons.cancel_outlined, color: c.danger), label: Text(s.orderCancel, style: TextStyle(color: c.danger))),
        ]),
        if (!locked) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.orderPurchaseNote, style: th.bodySmall)),
      ]),
    );
  }
}
