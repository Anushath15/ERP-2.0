import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../core/plain_error.dart';
import '../../data/ids.dart';
import '../../data/repo/purchase_repo.dart';
import '../../design/detail_sheet.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain/gst_price.dart';
import '../../domain/margin.dart';
import '../../domain/models.dart';
import '../../fake/actions.dart';
import '../../fake/data_providers.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart';
import '../../strings.dart';
import '../products/product_form.dart';

/// The purchases made with items (newest first); read again whenever one is saved or received.
final purchaseListProvider = FutureProvider.autoDispose<List<PurchaseRow>>((ref) {
  ref.watch(purchasesVersionProvider);
  return ref.read(appDataProvider).purchases.list();
});

/// A dealer's purchases (their page).
final dealerPurchasesProvider = FutureProvider.autoDispose.family<List<PurchaseRow>, String>((ref, dealerId) {
  ref.watch(purchasesVersionProvider);
  return ref.read(appDataProvider).purchases.list(dealerId: dealerId, limit: 200);
});

final dealerSummaryProvider = FutureProvider.autoDispose.family<DealerSummary, String>((ref, dealerId) {
  ref.watch(purchasesVersionProvider);
  return ref.read(appDataProvider).purchases.dealerSummary(dealerId);
});

/// The popup of one purchase: what was bought, at what rate, the selling price the shop marked, the rate paid before and any dealer
/// that had it cheaper.
Future<void> showPurchasePopup(BuildContext context, WidgetRef ref, PurchaseRow row) async {
  final l = tr(context);
  final th = Theme.of(context).textTheme;
  final c = context.c;
  final d = await ref.read(appDataProvider).purchases.detail(row.id);
  if (d == null || !context.mounted) return;
  final inclusive = ref.read(shopProvider).pricesIncludeGst;
  final givenBack = await ref.read(appDataProvider).purchaseReturns.returnedTotal(row.id);
  if (!context.mounted) return;
  String m(int p) => formatPaise(p, symbol: true);
  // the selling price is kept the way the shop prices things; the margin is worked out on the value before GST
  int sellEx(PurchaseLineView v) => inclusive ? divRound(v.sellingPaise * 10000, 10000 + v.gstBp) : v.sellingPaise;
  Widget line(PurchaseLineView v) {
    final margin = v.ratePaise > 0 && v.sellingPaise > 0 ? ((sellEx(v) - v.ratePaise) * 100 / v.ratePaise).round() : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(v.name, style: th.titleSmall)),
          Text(m(v.totalPaise), style: th.titleSmall),
        ]),
        Text('${formatQty(v.qtyMilli)} ${v.unit}  ·  ${l.purItemsLine(formatQty(v.qtyMilli), m(v.ratePaise))}  ·  GST ${v.gstBp ~/ 100}%', style: th.bodySmall),
        const SizedBox(height: 2),
        Text(v.sellingPaise > 0 ? l.purSelling(m(v.sellingPaise), margin?.toString() ?? '-') : l.purNoSelling, key: ValueKey('pur-sell-${v.productId}'), style: th.bodySmall?.copyWith(color: c.success)),
        if (v.lastBefore != null) Text(l.purLastBefore(m(v.lastBefore!.ratePaise), v.lastBefore!.dealerName, formatDate(v.lastBefore!.at)), key: ValueKey('pur-last-${v.productId}'), style: th.bodySmall),
        if (v.cheaper != null) Text(l.purCheaperElse(v.cheaper!.dealerName, m(v.cheaper!.ratePaise), formatDate(v.cheaper!.at)), key: ValueKey('pur-cheaper-${v.productId}'), style: th.bodySmall?.copyWith(color: c.warning, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  unawaited(showDetail(context, title: row.number, subtitle: '${row.dealerName}  ·  ${formatDate(row.at)}', body: [
    if (row.invoiceNo.isNotEmpty) KeyValue(l.fieldDealerInvoice, row.invoiceNo),
    KeyValue(l.colStatus, row.received ? l.statusReceived : l.statusPending),
    if (d.receivedAt != null) KeyValue(l.purReceivedOn(formatDate(d.receivedAt!)), ''),
    const Divider(),
    for (final v in d.lines) line(v),
    const Divider(),
    KeyValue(l.purSubtotal, m(row.totalPaise - d.taxPaise)),
    KeyValue(l.purGst, m(d.taxPaise)),
    KeyValue(l.purTotal, m(row.totalPaise), bold: true),
    KeyValue(l.purPaidLabel, m(row.paidPaise)),
    if (row.unpaidPaise > 0) KeyValue(l.purOnAccount, m(row.unpaidPaise), bold: true),
    if (givenBack > 0) KeyValue(l.pretReturned, m(givenBack)),
    if (!row.received) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.pendingNoStock, style: th.bodySmall)),
    if (d.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(d.note, style: th.bodySmall)),
  ], actions: [
    OutlinedButton.icon(
      key: const ValueKey('pur-edit'),
      icon: const Icon(Icons.edit_rounded),
      label: Text(l.purEdit),
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop();
        context.go('/purchases/${row.id}/edit');
      },
    ),
    if (row.received)
      OutlinedButton.icon(
        key: const ValueKey('pur-return-items'),
        icon: const Icon(Icons.assignment_return_rounded),
        label: Text(l.pretReturnItems),
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
          context.go('/purchase-returns/purchase/${row.id}');
        },
      ),
    if (!row.received)
      FilledButton.icon(
        key: const ValueKey('pur-mark-received'),
        icon: const Icon(Icons.inventory_rounded),
        label: Text(l.markReceived),
        onPressed: () async {
          Navigator.of(context, rootNavigator: true).pop();
          try {
            await ref.read(billActionsProvider).markPurchaseReceived(row);
            if (context.mounted) toast(context, l.markedReceived);
          } catch (e) {
            if (context.mounted) toast(context, plainError(e));
          }
        },
      ),
  ]));
}

class _FormLine {
  _FormLine(this.product, {String rate = '', String qty = ''})
      : rate = TextEditingController(text: rate),
        qty = TextEditingController(text: qty);
  final Product product;
  final TextEditingController qty;
  final TextEditingController rate;
  void dispose() {
    qty.dispose();
    rate.dispose();
  }
}

/// Add a purchase: the dealer, the dealer's invoice, the items with their rates, how much was paid. Under each item the last rate paid
/// for it and any dealer that sold it cheaper are shown while typing.
class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key, this.dealerId, this.editId});
  final String? dealerId;

  /// The purchase being changed (the same form, filled in, and Save changes the saved one); null = a new purchase.
  final String? editId;

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<PurchaseFormScreen> {
  String? _dealer;
  final _invoice = TextEditingController();
  final _note = TextEditingController();
  final _paid = TextEditingController();
  final _lines = <_FormLine>[];
  final _idemKey = newId();
  bool _received = true;
  bool _ratesInclude = false;
  bool _updateCost = true;
  int _pay = 0; // 0 paid in full, 1 part paid, 2 on credit
  bool _busy = false;
  String? _error;
  bool _loaded = true; // false while a purchase being edited is read
  String _number = '';
  List<String> _oldProducts = const [];

  @override
  void initState() {
    super.initState();
    final dealers = ref.read(recsProvider('dealers'));
    _dealer = dealers.any((d) => d.id == widget.dealerId) ? widget.dealerId : (dealers.isEmpty ? null : dealers.first.id);
    if (widget.editId != null) {
      _loaded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    }
  }

  /// Fills the form from the saved purchase.
  Future<void> _loadForEdit() async {
    final d = await ref.read(appDataProvider).purchases.detail(widget.editId!);
    if (!mounted) return;
    if (d == null) {
      setState(() {
        _loaded = true;
        _error = 'No such purchase.';
      });
      return;
    }
    final products = ref.read(productsProvider);
    setState(() {
      _number = d.row.number;
      _dealer = d.row.dealerId;
      _invoice.text = d.row.invoiceNo;
      _note.text = d.note;
      _received = d.row.received;
      _updateCost = d.updateCost;
      _ratesInclude = false; // the rates are kept without GST: shown the same way
      _pay = d.row.paidPaise >= d.row.totalPaise ? 0 : (d.row.paidPaise == 0 ? 2 : 1);
      if (_pay == 1) _paid.text = (d.row.paidPaise / 100).toStringAsFixed(2);
      _oldProducts = [for (final l in d.lines) l.productId];
      for (final l in d.lines) {
        final p = products.where((x) => x.id == l.productId).firstOrNull ??
            Product(id: l.productId, name: l.name, category: '', unit: l.unit, pricePaise: l.sellingPaise, costPaise: l.ratePaise, stockMilli: 0, gstBp: l.gstBp, barcode: '');
        _lines.add(_FormLine(p, rate: (l.ratePaise / 100).toStringAsFixed(2), qty: formatQty(l.qtyMilli)));
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _invoice.dispose();
    _note.dispose();
    _paid.dispose();
    for (final x in _lines) {
      x.dispose();
    }
    super.dispose();
  }

  static int _paise(String s) => ((double.tryParse(s.trim()) ?? 0) * 100).round();

  /// The rate typed for a line, per unit WITHOUT GST (what is kept).
  int _exRate(_FormLine x) => buyingPriceToStore(enteredPaise: _paise(x.rate.text), enteredIncludesGst: _ratesInclude, gstBp: x.product.gstBp);

  PurchaseLineInput? _input(_FormLine x) {
    final q = parseQtyMilli(x.qty.text);
    if (q == null || q <= 0 || double.tryParse(x.rate.text.trim()) == null) return null;
    return PurchaseLineInput(productId: x.product.id, name: x.product.name, unit: x.product.unit, qtyMilli: q, ratePaise: _exRate(x), gstBp: x.product.gstBp);
  }

  ({int taxable, int tax, int total}) _totals() {
    var taxable = 0, tax = 0;
    for (final x in _lines) {
      final i = _input(x);
      if (i != null) {
        taxable += i.taxable;
        tax += i.tax;
      }
    }
    return (taxable: taxable, tax: tax, total: taxable + tax);
  }

  /// A product that is not in the list yet: made here (the purchase brings its stock) and added to the items.
  Future<void> _newProduct() async {
    final s = tr(context);
    final p = await showProductForm(context, saveLabel: s.save, forPurchase: true);
    if (p == null || !mounted) return;
    ref.read(productsProvider.notifier).add(p);
    await ref.read(writeQueueProvider).flush(); // the product is in the database before the purchase that names it
    if (!mounted) return;
    final made = ref.read(productsProvider).where((x) => x.id == p.id).firstOrNull ?? p;
    setState(() {
      _lines.add(_FormLine(made, rate: made.costPaise == 0 ? '' : (made.costPaise / 100).toStringAsFixed(2)));
      _error = null;
    });
  }

  Future<void> _save(Strings s) async {
    if (_dealer == null) {
      setState(() => _error = s.purNeedDealer);
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = s.purNoItems);
      return;
    }
    final inputs = <PurchaseLineInput>[];
    for (final x in _lines) {
      final i = _input(x);
      if (i == null) {
        setState(() => _error = s.purBadRate);
        return;
      }
      inputs.add(i);
    }
    final total = inputs.fold<int>(0, (a, b) => a + b.total);
    final paid = _pay == 0 ? total : (_pay == 1 ? _paise(_paid.text) : 0);
    if (paid > total || paid < 0) {
      setState(() => _error = s.purPaidTooMuch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(writeQueueProvider).flush(); // anything typed a moment ago (a product made here) is saved first
      final input = SavePurchaseInput(
        idemKey: _idemKey,
        dealerId: _dealer!,
        at: ref.read(clockProvider),
        lines: inputs,
        invoiceNo: _invoice.text,
        paidPaise: paid,
        received: _received,
        updateCost: _updateCost,
        note: _note.text,
      );
      if (widget.editId != null) {
        final saved = await ref.read(billActionsProvider).editPurchase(widget.editId!, input, oldProductIds: _oldProducts);
        if (!mounted) return;
        toast(context, s.purEdited(saved.number));
        context.go('/purchases');
        return;
      }
      final saved = await ref.read(billActionsProvider).savePurchase(input);
      if (!mounted) return;
      toast(context, s.purSaved(saved.number, formatPaise(saved.totalPaise, symbol: true)));
      context.go('/purchases');
    } catch (e) {
      if (mounted) setState(() => _error = plainError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = tr(context);
    final th = Theme.of(context).textTheme;
    final c = context.c;
    final dealers = ref.watch(recsProvider('dealers'));
    final products = ref.watch(productsProvider);
    final t = _totals();
    String m(int p) => formatPaise(p, symbol: true);

    Widget picker = Autocomplete<Product>(
      displayStringForOption: (p) => p.name,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<Product>.empty();
        return products.where((p) => '${p.name} ${p.code} ${p.brand} ${p.barcode}'.toLowerCase().contains(q)).take(8);
      },
      onSelected: (p) => setState(() {
        _lines.add(_FormLine(p, rate: _ratesInclude || p.costPaise == 0 ? '' : (p.costPaise / 100).toStringAsFixed(2)));
        _error = null;
      }),
      fieldViewBuilder: (ctx, ctl, focus, submit) => TextField(
        key: const ValueKey('pur-picker'),
        controller: ctl,
        focusNode: focus,
        decoration: InputDecoration(labelText: s.purAddItem, hintText: s.purSearchHint, prefixIcon: const Icon(Icons.search_rounded)),
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
                ListTile(
                  key: ValueKey('pur-option-${p.id}'),
                  dense: true,
                  title: Text(p.name),
                  subtitle: Text('${p.code}${p.brand.isEmpty ? '' : '  ·  ${p.brand}'}  ·  ${formatQty(p.stockMilli)} ${p.unit}'),
                  onTap: () => onSelected(p),
                ),
            ]),
          ),
        ),
      ),
    );

    Widget lineRow(_FormLine x) {
      final rateEx = _exRate(x);
      final i = _input(x);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${x.product.name}${x.product.code.isEmpty ? '' : '  ·  ${x.product.code}'}', style: th.titleSmall)),
            IconButton(key: ValueKey('pur-remove-${x.product.id}'), tooltip: s.delete, onPressed: () => setState(() {
              _lines.remove(x);
              x.dispose();
            }), icon: const Icon(Icons.close_rounded, size: 18)),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 130,
              child: TextField(
                key: ValueKey('pur-qty-${x.product.id}'),
                controller: x.qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(13)],
                decoration: InputDecoration(labelText: s.purQty, suffixText: x.product.unit, isDense: true),
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                key: ValueKey('pur-rate-${x.product.id}'),
                controller: x.rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(13)],
                decoration: InputDecoration(labelText: s.purRate, prefixText: '₹ ', isDense: true),
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            Text('GST ${x.product.gstBp ~/ 100}%', style: th.bodySmall),
            if (i != null) Text(m(i.total), style: th.titleSmall),
            // what the selling price becomes when this purchase is received (the margin on the old buying price is kept)
            if (_updateCost && rateEx > 0 && x.product.costPaise > 0 && x.product.pricePaise > 0)
              () {
                final now = sellingPriceKeepingMargin(oldCost: x.product.costPaise, newCost: rateEx, oldSell: x.product.pricePaise);
                final changed = now != x.product.pricePaise;
                final above = x.product.mrpPaise > 0 && now > x.product.mrpPaise;
                final bold = th.bodySmall?.copyWith(fontWeight: FontWeight.w600);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  // the old buying price first, then what the selling price becomes
                  Text(
                    key: ValueKey('pur-cost-${x.product.id}'),
                    rateEx != x.product.costPaise ? s.purCostChange(m(x.product.costPaise), m(rateEx)) : s.purCostSame(m(x.product.costPaise)),
                    style: bold,
                  ),
                  Text(
                    key: ValueKey('pur-sell-${x.product.id}'),
                    '${changed ? s.purSellChange(m(x.product.pricePaise), m(now)) : s.purSellSame(m(x.product.pricePaise))}${above ? '  ·  ${s.purSellAboveMrp(m(x.product.mrpPaise))}' : ''}',
                    style: bold?.copyWith(color: above ? context.c.warning : (changed ? context.c.info : null)),
                  ),
                ]);
              }(),
          ]),
          if (_dealer != null) _RateHints(key: ValueKey('hints-${x.product.id}-$_dealer-$rateEx'), productId: x.product.id, dealerId: _dealer!, ratePaise: rateEx),
        ]),
      );
    }

    final payMenu = SegmentedButton<int>(
      key: const ValueKey('pur-pay'),
      showSelectedIcon: false,
      segments: [ButtonSegment(value: 0, label: Text(s.purPaidFull)), ButtonSegment(value: 1, label: Text(s.purPaidPart)), ButtonSegment(value: 2, label: Text(s.purPaidNone))],
      selected: {_pay},
      onSelectionChanged: (v) => setState(() => _pay = v.first),
    );

    final editing = widget.editId != null;
    if (!_loaded) return PageFrame(title: s.purFormTitle, child: const Center(child: CircularProgressIndicator()));
    return PageFrame(
      title: editing ? s.purEditTitle(_number) : s.purFormTitle,
      subtitle: editing ? s.purEditHint : s.purFormHint,
      actions: [TextButton.icon(onPressed: () => context.go('/purchases'), icon: const Icon(Icons.arrow_back_rounded), label: Text(s.back))],
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('pur-dealer'),
              initialValue: _dealer,
              decoration: InputDecoration(labelText: s.purDealer),
              items: [for (final d in dealers) DropdownMenuItem(value: d.id, child: Text(d.s('name')))],
              onChanged: editing ? null : (v) => setState(() => _dealer = v), // a saved purchase keeps its dealer
            ),
            const SizedBox(height: 12),
            TextField(key: const ValueKey('pur-invoice'), controller: _invoice, decoration: InputDecoration(labelText: s.fieldDealerInvoice)),
            const SizedBox(height: 12),
            Text(s.colStatus, style: th.bodySmall),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              key: const ValueKey('pur-status'),
              showSelectedIcon: false,
              segments: [ButtonSegment(value: true, label: Text(s.statusReceived)), ButtonSegment(value: false, label: Text(s.statusPending))],
              selected: {_received},
              onSelectionChanged: editing ? null : (v) => setState(() => _received = v.first), // a saved purchase keeps its status
            ),
            if (editing) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${s.purEditDealerFixed} ${s.purEditStatusFixed}', style: th.bodySmall)),
            if (!_received) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.pendingNoStock, style: th.bodySmall)),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: s.purItemsTitle,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s.purRatesAre, style: th.bodySmall),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                key: const ValueKey('pur-rate-mode'),
                showSelectedIcon: false,
                segments: [ButtonSegment(value: false, label: Text(s.gstExcl)), ButtonSegment(value: true, label: Text(s.gstIncl))],
                selected: {_ratesInclude},
                onSelectionChanged: (v) => setState(() => _ratesInclude = v.first),
              ),
            ),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: picker),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(top: 6), child: OutlinedButton.icon(key: const ValueKey('pur-new-product'), onPressed: _busy ? null : _newProduct, icon: const Icon(Icons.add_rounded), label: Text(s.purNewProduct))),
            ]),
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(s.purNewProductHint, style: th.bodySmall)),
            for (final x in _lines) ...[const Divider(), lineRow(x)],
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KeyValue(s.purSubtotal, m(t.taxable)),
            KeyValue(s.purGst, m(t.tax)),
            Row(children: [Expanded(child: Text(s.purTotal, style: th.titleMedium)), Text(m(t.total), key: const ValueKey('pur-total'), style: th.titleLarge)]),
            const SizedBox(height: 12),
            payMenu,
            if (_pay == 1) ...[
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('pur-paid'),
                controller: _paid,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: InputDecoration(labelText: s.purPaidAmount, prefixText: '₹ '),
                onChanged: (_) => setState(() => _error = null),
              ),
            ],
            SwitchListTile(key: const ValueKey('pur-update-cost'), contentPadding: EdgeInsets.zero, title: Text(s.purUpdateCost), value: _updateCost, onChanged: (v) => setState(() => _updateCost = v)),
            TextField(key: const ValueKey('pur-note'), controller: _note, decoration: InputDecoration(labelText: s.purNote)),
          ]),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, key: const ValueKey('pur-error'), style: th.bodyMedium?.copyWith(color: c.danger))),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const ValueKey('pur-save'),
            onPressed: _busy ? null : () => _save(s),
            icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
            label: Text(s.purSave),
          ),
        ),
      ]),
    );
  }
}

/// Under an item while typing: the last rate paid for this product, and a dealer that sold it cheaper than the rate typed.
class _RateHints extends ConsumerStatefulWidget {
  const _RateHints({super.key, required this.productId, required this.dealerId, required this.ratePaise});
  final String productId, dealerId;
  final int ratePaise;

  @override
  ConsumerState<_RateHints> createState() => _RateHintsState();
}

class _RateHintsState extends ConsumerState<_RateHints> {
  ({RateNote? last, RateNote? cheaper})? _hints;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final h = await ref.read(appDataProvider).purchases.rateHints(widget.productId, dealerId: widget.dealerId, ratePaise: widget.ratePaise);
    if (mounted) setState(() => _hints = h);
  }

  @override
  Widget build(BuildContext context) {
    final s = tr(context);
    final th = Theme.of(context).textTheme;
    final h = _hints;
    if (h == null) return const SizedBox.shrink();
    String m(int p) => formatPaise(p, symbol: true);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (h.last != null) Text(s.purLast(m(h.last!.ratePaise), h.last!.dealerName, formatDate(h.last!.at)), key: ValueKey('hint-last-${widget.productId}'), style: th.bodySmall),
        if (h.cheaper != null && widget.ratePaise > 0) Text(s.purCheaper(h.cheaper!.dealerName, m(h.cheaper!.ratePaise), formatDate(h.cheaper!.at)), key: ValueKey('hint-cheaper-${widget.productId}'), style: th.bodySmall?.copyWith(color: context.c.warning, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
