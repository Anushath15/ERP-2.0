import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../design/detail_sheet.dart';
import '../../design/widgets.dart';
import '../../domain/stock_value.dart';
import '../../fake/data_providers.dart';
import '../../fake/stock_value_provider.dart';
import '../../strings.dart';

String ruleName(Strings l, ValuationRule r) => switch (r) { ValuationRule.average => l.ruleAverage, ValuationRule.buying => l.ruleBuying, ValuationRule.selling => l.ruleSelling };

/// The text under the big stock-value number: which rule it is, or that the recommended one is shown until the shop chooses.
String ruleCaption(Strings l, StockValuation v) => v.isChosen ? l.stockValueChosen(ruleName(l, v.shown)) : l.stockValueRecommended;

Future<void> showStockValueSheet(BuildContext context, WidgetRef ref) {
  return showDetail<void>(
    context,
    title: tr(context).stockValueTitle,
    subtitle: tr(context).stockValueHelp,
    body: [Consumer(builder: (ctx, ref, _) => _Body(ref))],
  );
}

class _Body extends StatelessWidget {
  const _Body(this.ref);
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final v = ref.watch(stockValuationProvider).value;
    if (v == null) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    Future<void> choose(ValuationRule r) async {
      await ref.read(appDataProvider).settings.put('valuation.rule', r.name);
      ref.invalidate(stockValuationProvider);
      if (context.mounted) toast(context, l.ruleSaved);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('₹ ${formatPaise(v.shownTotal)}', style: th.headlineMedium),
      Text(ruleCaption(l, v), style: th.bodySmall),
      const SizedBox(height: 12),
      for (final r in ValuationRule.values)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ruleName(l, r), style: th.titleSmall),
                  Text('${l.stockValueActive}: ₹ ${formatPaise(v.activeValue[r]!)}', style: th.bodySmall),
                  Text('${l.stockValueInactive}: ₹ ${formatPaise(v.inactiveValue[r]!)}', style: th.bodySmall),
                  Text('${l.stockValueTotal}: ₹ ${formatPaise(v.total(r))}', style: th.titleMedium),
                ]),
              ),
              const SizedBox(width: 8),
              if (v.chosen == r) StatusBadge(l.ruleInUse, kind: BadgeKind.success, icon: Icons.check) else OutlinedButton(key: ValueKey('useRule-${r.name}'), onPressed: () => choose(r), child: Text(l.useThisRule)),
            ]),
          ),
        ),
      if (v.unpricedProducts > 0) ...[
        StatusBadge(l.costNotSetLine(v.unpricedProducts.toString(), formatQty(v.unpricedQtyMilli)), kind: BadgeKind.warning, icon: Icons.sell_outlined),
        Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Text(l.costNotSetHelp, style: th.bodySmall)),
      ],
      if (v.negatives.isNotEmpty) ...[
        StatusBadge(l.negativeStockLine(v.negatives.length.toString()), kind: BadgeKind.danger, icon: Icons.error_outline),
        for (final n in v.negatives.take(10)) Text('${n.name}: ${formatQty(n.stockMilli)}', style: th.bodySmall),
      ],
    ]);
  }
}
