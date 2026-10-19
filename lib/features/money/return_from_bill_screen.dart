import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../core/plain_error.dart';
import '../../core/responsive.dart';
import '../../data/ids.dart';
import '../../data/repo/return_repo.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/actions.dart';
import '../../fake/data_providers.dart';
import '../../fake/store.dart' show clockProvider;
import '../../strings.dart';

/// "Return items" from a saved bill: the bill's items are listed with how many are still with the customer; the person types how
/// many come back; the refund, what happens to the customer's debt and the way the money goes back are shown before saving.
class ReturnFromBillScreen extends ConsumerStatefulWidget {
  const ReturnFromBillScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<ReturnFromBillScreen> createState() => _ReturnFromBillState();
}

class _ReturnFromBillState extends ConsumerState<ReturnFromBillScreen> {
  ReturnableBill? _bill;
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
    final b = await ref.read(appDataProvider).returns.returnable(widget.billId);
    if (!mounted) return;
    setState(() {
      _bill = b;
      _loaded = true;
      for (final l in b?.lines ?? const <ReturnableLine>[]) {
        _qty[l.billLineId] = TextEditingController();
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

  /// The typed quantities that are valid numbers (anything else counts as nothing).
  Map<String, int> _typed() {
    final out = <String, int>{};
    for (final e in _qty.entries) {
      final q = parseQtyMilli(e.value.text);
      if (q != null && q > 0) out[e.key] = q;
    }
    return out;
  }

  String? _lineProblem(ReturnableLine l, Strings s) {
    final text = _qty[l.billLineId]!.text.trim();
    if (text.isEmpty) return null;
    final q = parseQtyMilli(text);
    if (q == null) return s.retTooMany(formatQty(l.remainingMilli), l.name);
    if (q > l.remainingMilli) return s.retTooMany(formatQty(l.remainingMilli), l.name);
    return null;
  }

  Future<void> _save(Strings s, ReturnableBill b) async {
    final typed = _typed();
    if (typed.isEmpty) {
      setState(() => _error = s.retNothing);
      return;
    }
    for (final l in b.lines) {
      if (_lineProblem(l, s) != null) {
        setState(() => _error = _lineProblem(l, s));
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
      final saved = await ref.read(billActionsProvider).returnItems(
            SaveReturnInput(idemKey: _idemKey, billId: b.billId, at: ref.read(clockProvider), lines: typed, reason: _reason.text.trim(), refundMode: _mode, keepAsCredit: _keepCredit),
            productIds: [for (final l in b.lines) if (typed.containsKey(l.billLineId)) l.productId],
            customerId: b.customerId,
          );
      if (!mounted) return;
      toast(context, s.retDone(saved.number, formatPaise(saved.totalPaise, symbol: true)));
      context.go('/sales-returns');
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
    final b = _bill;
    if (!_loaded) return PageFrame(title: s.navSalesReturns, child: const Center(child: CircularProgressIndicator()));
    if (b == null) {
      return PageFrame(title: s.retNotFoundTitle, child: Align(alignment: Alignment.topLeft, child: Text(s.retNoBill)));
    }
    final typed = _typed();
    final p = ReturnRepo.preview(b, typed, keepAsCredit: _keepCredit);
    String m(int paise) => formatPaise(paise, symbol: true);

    Widget lineRow(ReturnableLine l) {
      final problem = _lineProblem(l, s);
      final done = l.remainingMilli <= 0;
      final field = SizedBox(
        width: 130,
        child: TextField(
          key: ValueKey('ret-qty-${l.billLineId}'),
          controller: _qty[l.billLineId],
          enabled: !done,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(13)],
          decoration: InputDecoration(labelText: s.retNow, suffixText: l.unit, isDense: true),
          onChanged: (_) => setState(() => _error = null),
        ),
      );
      final all = TextButton(
        key: ValueKey('ret-all-${l.billLineId}'),
        onPressed: done ? null : () => setState(() => _qty[l.billLineId]!.text = formatQty(l.remainingMilli)),
        child: Text(s.retAll),
      );
      final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.name, style: th.titleSmall),
        const SizedBox(height: 2),
        Text('${s.retSold}: ${formatQty(l.soldMilli)} ${l.unit}   ·   ${s.retBack}: ${formatQty(l.returnedMilli)}   ·   ${m(l.ratePaise)}', style: th.bodySmall),
        if (problem != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(problem, style: th.bodySmall?.copyWith(color: context.c.danger))),
      ]);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: context.isPhone
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 8), Row(children: [field, const SizedBox(width: 8), all])])
            : Row(children: [Expanded(child: info), field, const SizedBox(width: 8), all]),
      );
    }

    final handBack = p.refunded > 0;
    final summary = SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.retRefund(m(p.total)), key: const ValueKey('ret-total'), style: th.titleLarge),
        if (p.dueReduced > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.retToDebt(m(p.dueReduced)), key: const ValueKey('ret-debt'), style: th.bodyMedium)),
        if (p.creditKept > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${s.retSettledCredit}: ${m(p.creditKept)}', key: const ValueKey('ret-credit'), style: th.bodyMedium)),
        if (handBack) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.retHandBack(m(p.refunded)), key: const ValueKey('ret-hand'), style: th.bodyMedium)),
        if (b.customerId != null && p.total > p.dueReduced)
          SwitchListTile(
            key: const ValueKey('ret-keep-credit'),
            contentPadding: EdgeInsets.zero,
            title: Text(s.retKeepCredit),
            value: _keepCredit,
            onChanged: (v) => setState(() => _keepCredit = v),
          ),
        if (handBack) ...[
          const SizedBox(height: 8),
          Text(s.retMethod, style: th.bodySmall),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            key: const ValueKey('ret-method'),
            showSelectedIcon: false,
            segments: [ButtonSegment(value: 0, label: Text(s.payCash)), ButtonSegment(value: 1, label: Text(s.payUpi)), ButtonSegment(value: 2, label: Text(s.payCard))],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
        ],
      ]),
    );

    return PageFrame(
      title: s.retTitle(b.number),
      subtitle: s.retSubtitle,
      actions: [OutlinedButton.icon(onPressed: () => context.go('/sales-returns'), icon: const Icon(Icons.arrow_back), label: Text(s.back))],
      child: !b.anythingLeft
          ? Align(alignment: Alignment.topLeft, child: Text(s.retAllDone, key: const ValueKey('ret-all-done')))
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              Text(s.retBillInfo(b.number, formatDateTime(b.at), m(b.totalPaise)), style: th.bodySmall),
              const SizedBox(height: 8),
              SectionCard(child: Column(children: [for (final l in b.lines) lineRow(l)])),
              const SizedBox(height: 12),
              summary,
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('ret-reason'),
                controller: _reason,
                maxLength: 200,
                decoration: InputDecoration(labelText: s.fieldReason, hintText: s.retReasonHelp),
                onChanged: (_) => setState(() => _error = null),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const ValueKey('ret-error'), style: th.bodyMedium?.copyWith(color: context.c.danger))),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('ret-save'),
                  onPressed: _busy ? null : () => _save(s, b),
                  icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.assignment_return_outlined),
                  label: Text(s.retSave),
                ),
              ),
            ]),
    );
  }
}
