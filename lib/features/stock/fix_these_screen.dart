import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../data/ids.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain/models.dart';
import '../../domain/stock_value.dart';
import '../../fake/data_providers.dart';
import '../../fake/stock_value_provider.dart';
import '../../fake/store.dart';

/// "Fix these": the two lists the stock value depends on. Stock with no buying price (type the price) and negative stock (one tap writes a visible
/// stock change that brings it to zero). Nothing is changed silently.
class FixTheseScreen extends ConsumerWidget {
  const FixTheseScreen({super.key});

  static const shown = 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final sv = ref.watch(stockValuationProvider).value;
    final nothing = sv != null && sv.negatives.isEmpty && sv.unpricedItems.isEmpty;
    return PageFrame(
      title: l.fixTitle,
      subtitle: l.fixSubtitle,
      child: sv == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (nothing) SectionCard(child: Row(children: [Icon(Icons.check_circle_outline_rounded, color: context.c.success), const SizedBox(width: 8), Expanded(child: Text(l.fixNothing))])),
                  if (sv.negatives.isNotEmpty) ...[
                    SectionCard(
                      title: '${l.fixNegTitle} (${sv.negatives.length})',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.fixNegHelp, style: th.bodySmall),
                        const SizedBox(height: 8),
                        for (final n in sv.negatives.take(shown)) _NegativeRow(item: n),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (sv.unpricedItems.isNotEmpty)
                    SectionCard(
                      title: '${l.fixNoCostTitle} (${sv.unpricedItems.length})',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.fixNoCostHelp, style: th.bodySmall),
                        const SizedBox(height: 8),
                        for (final n in sv.unpricedItems.take(shown)) _CostRow(key: ValueKey('cost-${n.id}'), item: n),
                      ]),
                    ),
                  if (sv.inactiveProducts > 0) ...[
                    const SizedBox(height: 12),
                    SectionCard(child: Text(l.fixInactiveLine('${sv.inactiveProducts}', formatQty(sv.inactiveQtyMilli)))),
                  ],
                ]),
              ),
            ),
    );
  }
}

class _NegativeRow extends ConsumerWidget {
  const _NegativeRow({required this.item});
  final NegativeStock item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 6, children: [
        ConstrainedBox(constraints: const BoxConstraints(minWidth: 180, maxWidth: 380), child: Text('${item.name}: ${formatQty(item.stockMilli)}')),
        OutlinedButton(
          key: ValueKey('correct-${item.id}'),
          onPressed: () async {
            final add = -item.stockMilli;
            final ok = await confirmDialog(context, title: l.fixCorrect, message: l.fixCorrectConfirm(formatQty(add), item.name, formatQty(item.stockMilli)), confirmLabel: l.fixCorrect);
            if (!ok) return;
            final d = ref.read(appDataProvider);
            final at = ref.read(clockProvider);
            final reason = 'Corrected negative stock (was ${formatQty(item.stockMilli)})';
            await ref.read(writeQueueProvider).run(() async {
              await d.stock.adjust(productId: item.id, qtyMilli: add, reason: reason, at: at);
              await ref.read(productsProvider.notifier).reload([item.id]);
            });
            ref.read(recsProvider('adjustments').notifier).showOnly(Rec(newId(), {'date': at, 'product': item.name, 'qty': add, 'reason': reason}));
            ref.invalidate(stockValuationProvider);
            if (context.mounted) toast(context, l.fixCorrected);
          },
          child: Text(l.fixCorrect),
        ),
      ]),
    );
  }
}

class _CostRow extends ConsumerStatefulWidget {
  const _CostRow({super.key, required this.item});
  final NegativeStock item;
  @override
  ConsumerState<_CostRow> createState() => _CostRowState();
}

class _CostRowState extends ConsumerState<_CostRow> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = tr(context);
    final rupees = double.tryParse(_c.text.trim().replaceAll(',', ''));
    if (rupees == null || rupees <= 0 || rupees > 10000000) {
      setState(() => _error = l.fixPriceInvalid);
      return;
    }
    final p = ref.read(productsProvider).where((x) => x.id == widget.item.id).firstOrNull;
    if (p == null) return;
    ref.read(productsProvider.notifier).update(p.copyWith(costPaise: (rupees * 100).round()));
    await ref.read(writeQueueProvider).flush(); // the price is on disk before the list is worked out again
    ref.invalidate(stockValuationProvider);
    if (mounted) toast(context, l.fixSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 6, children: [
        ConstrainedBox(constraints: const BoxConstraints(minWidth: 180, maxWidth: 380), child: Text('${widget.item.name}: ${formatQty(widget.item.stockMilli)}')),
        SizedBox(
          width: 150,
          child: TextField(
            key: ValueKey('price-${widget.item.id}'),
            controller: _c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.fixBuyingPrice, prefixText: '₹ ', errorText: _error, isDense: true),
            onSubmitted: (_) => _save(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ),
        FilledButton(key: ValueKey('save-${widget.item.id}'), onPressed: _save, child: Text(l.fixSave)),
      ]),
    );
  }
}
