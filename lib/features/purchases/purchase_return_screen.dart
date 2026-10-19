import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../core/plain_error.dart';
import '../../core/responsive.dart';
import '../../data/ids.dart';
import '../../data/repo/purchase_return_repo.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/actions.dart';
import '../../fake/data_providers.dart';
import '../../fake/store.dart' show clockProvider;
import '../../strings.dart';

/// "Return items" from a received purchase: the purchase's items with how many are left and in stock; the person types how many go
/// back to the dealer; the value, what comes off what the shop owes the dealer and how the rest is settled are shown before saving.
class PurchaseReturnScreen extends ConsumerStatefulWidget {
  const PurchaseReturnScreen({super.key, required this.purchaseId});
  final String purchaseId;

  @override
  ConsumerState<PurchaseReturnScreen> createState() => _PurchaseReturnState();
}

class _PurchaseReturnState extends ConsumerState<PurchaseReturnScreen> {
  PurchaseReturnable? _purchase;
  bool _loaded = false;
  final _qty = <String, TextEditingController>{};
  final _reason = TextEditingController();
  final _idemKey = newId();
  int _mode = 0;
  bool _keepCredit = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ref.read(appDataProvider).purchaseReturns.returnable(widget.purchaseId);
    if (!mounted) return;
    setState(() {
      _purchase = p;
      _loaded = true;
      for (final l in p?.lines ?? const <PurchaseReturnableLine>[]) {
        _qty[l.purchaseLineId] = TextEditingController();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  Map<String, int> _typed() {
    final out = <String, int>{};
    for (final e in _qty.entries) {
      final q = parseQtyMilli(e.value.text);
      if (q != null && q > 0) out[e.key] = q;
    }
    return out;
  }

  String? _lineProblem(PurchaseReturnableLine l, Strings s) {
    final text = _qty[l.purchaseLineId]!.text.trim();
    if (text.isEmpty) return null;
    final q = parseQtyMilli(text);
    if (q == null || q > l.maxNowMilli) return s.pretTooMany(formatQty(l.maxNowMilli), l.name);
    return null;
  }

  Future<void> _save(Strings s, PurchaseReturnable p) async {
    final typed = _typed();
    if (typed.isEmpty) {
      setState(() => _error = s.retNothing);
      return;
    }
    for (final l in p.lines) {
      final problem = _lineProblem(l, s);
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = s.fieldRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref.read(billActionsProvider).returnToDealer(
            SavePurchaseReturnInput(idemKey: _idemKey, purchaseId: p.purchaseId, at: ref.read(clockProvider), lines: typed, reason: _reason.text.trim(), refundMode: _mode, keepAsCredit: _keepCredit),
            productIds: [for (final l in p.lines) if (typed.containsKey(l.purchaseLineId)) l.productId],
            dealerId: p.dealerId,
          );
      if (!mounted) return;
      toast(context, s.pretDone(saved.number, formatPaise(saved.totalPaise, symbol: true)));
      context.go('/purchase-returns');
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
    final p = _purchase;
    if (!_loaded) return PageFrame(title: s.navPurchaseReturns, child: const Center(child: CircularProgressIndicator()));
    if (p == null) return PageFrame(title: s.pretNotFoundTitle, child: Align(alignment: Alignment.topLeft, child: Text(s.pretNoPurchase)));
    String m(int paise) => formatPaise(paise, symbol: true);
    final back = TextButton.icon(onPressed: () => context.go('/purchase-returns'), icon: const Icon(Icons.arrow_back_rounded), label: Text(s.back));
    if (!p.received) {
      return PageFrame(title: s.pretTitle(p.number), actions: [back], child: Align(alignment: Alignment.topLeft, child: Text(s.pretNotReceived, key: const ValueKey('pret-not-received'))));
    }
    final typed = _typed();
    final pv = PurchaseReturnRepo.preview(p, typed, keepAsCredit: _keepCredit);

    Widget lineRow(PurchaseReturnableLine l) {
      final problem = _lineProblem(l, s);
      final done = l.maxNowMilli <= 0;
      final field = SizedBox(
        width: 130,
        child: TextField(
          key: ValueKey('pret-qty-${l.purchaseLineId}'),
          controller: _qty[l.purchaseLineId],
          enabled: !done,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(13)],
          decoration: InputDecoration(labelText: s.pretNow, suffixText: l.unit, isDense: true),
          onChanged: (_) => setState(() => _error = null),
        ),
      );
      final all = TextButton(
        key: ValueKey('pret-all-${l.purchaseLineId}'),
        onPressed: done ? null : () => setState(() => _qty[l.purchaseLineId]!.text = formatQty(l.maxNowMilli)),
        child: Text(s.pretAll),
      );
      final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.name, style: th.titleSmall),
        const SizedBox(height: 2),
        Text('${s.pretBought}: ${formatQty(l.boughtMilli)} ${l.unit}   ·   ${s.pretBack}: ${formatQty(l.returnedMilli)}   ·   ${s.pretInStock}: ${formatQty(l.inStockMilli < 0 ? 0 : l.inStockMilli)}   ·   ${m(l.ratePaise)}', style: th.bodySmall),
        if (problem != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(problem, style: th.bodySmall?.copyWith(color: context.c.danger))),
      ]);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: context.isPhone
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 8), Row(children: [field, const SizedBox(width: 8), all])])
            : Row(children: [Expanded(child: info), field, const SizedBox(width: 8), all]),
      );
    }

    final getBack = pv.refunded > 0;
    final summary = SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.pretRefund(m(pv.total)), key: const ValueKey('pret-total'), style: th.titleLarge),
        if (pv.dueReduced > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.pretToDebt(m(pv.dueReduced)), key: const ValueKey('pret-debt'), style: th.bodyMedium)),
        if (pv.creditKept > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${s.pretCreditKept}: ${m(pv.creditKept)}', key: const ValueKey('pret-credit'), style: th.bodyMedium)),
        if (getBack) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.pretGetBack(m(pv.refunded)), key: const ValueKey('pret-get-back'), style: th.bodyMedium)),
        if (pv.total > pv.dueReduced)
          SwitchListTile(key: const ValueKey('pret-keep-credit'), contentPadding: EdgeInsets.zero, title: Text(s.pretKeepCredit), value: _keepCredit, onChanged: (v) => setState(() => _keepCredit = v)),
        if (getBack) ...[
          const SizedBox(height: 8),
          Text(s.pretMethod, style: th.bodySmall),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            key: const ValueKey('pret-method'),
            showSelectedIcon: false,
            segments: [ButtonSegment(value: 0, label: Text(s.payCash)), ButtonSegment(value: 1, label: Text(s.payUpi)), ButtonSegment(value: 2, label: Text(s.payCard))],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
        ],
      ]),
    );

    return PageFrame(
      title: s.pretTitle(p.number),
      subtitle: s.pretSubtitle,
      actions: [back],
      child: !p.anythingLeft
          ? Align(alignment: Alignment.topLeft, child: Text(s.pretAllDone, key: const ValueKey('pret-all-done')))
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              Text('${p.dealerName}  ·  ${formatDate(p.at)}  ·  ${m(p.totalPaise)}', style: th.bodySmall),
              const SizedBox(height: 8),
              SectionCard(child: Column(children: [for (final l in p.lines) lineRow(l)])),
              const SizedBox(height: 12),
              summary,
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('pret-reason'),
                controller: _reason,
                maxLength: 200,
                decoration: InputDecoration(labelText: s.fieldReason, hintText: s.retReasonHelp),
                onChanged: (_) => setState(() => _error = null),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const ValueKey('pret-error'), style: th.bodyMedium?.copyWith(color: context.c.danger))),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('pret-save'),
                  onPressed: _busy ? null : () => _save(s, p),
                  icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.assignment_return_rounded),
                  label: Text(s.pretSave),
                ),
              ),
            ]),
    );
  }
}
