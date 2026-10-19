import 'package:flutter/material.dart';
import '../backup/backups_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../design/effects.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/stats.dart';
import '../../fake/store.dart';

/// Simple bar chart drawn with plain boxes (no chart package, no animation).
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.values, required this.labels, this.height = 140, this.highlightLast = true});
  final List<int> values;
  final List<String> labels;
  final double height;
  final bool highlightLast;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final maxV = values.fold<int>(1, (m, v) => v > m ? v : m);
    final th = Theme.of(context).textTheme;
    return SizedBox(
      height: height + 22,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Semantics(
                label: '${labels[i]}: ${formatPaise(values[i], symbol: true)}',
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(height: (height * values[i] / maxV).clamp(2, height), decoration: BoxDecoration(color: highlightLast && i == values.length - 1 ? c.primary : c.primary.withValues(alpha: 0.45), borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))),
                  const SizedBox(height: 4),
                  SizedBox(height: 16, child: FittedBox(child: Text(labels[i], style: th.bodySmall))),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final phone = context.isPhone;
    final now = ref.watch(clockProvider);
    final hs = ref.watch(statsProvider);
    final products = ref.watch(productsProvider);
    final th = Theme.of(context).textTheme;
    final todayTotal = hs.today.sales;
    final low = products.where((p) => p.lowStock || p.outOfStock).toList();
    final week = hs.week;
    final labels = [for (final d in hs.weekDays) '${two(d.day)}/${two(d.month)}'];

    Widget action(IconData i, String label, String path, {bool primary = false}) => Expanded(
          child: PressScale(child: primary
              ? FilledButton.icon(onPressed: () => context.go(path), icon: Icon(i), label: Text(label, textAlign: TextAlign.center), style: FilledButton.styleFrom(minimumSize: const Size(0, 56)))
              : OutlinedButton.icon(onPressed: () => context.go(path), icon: Icon(i), label: Text(label, textAlign: TextAlign.center), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)))),
        );

    final actions = phone
        ? Column(children: [
            Row(children: [action(Icons.point_of_sale_rounded, l.navNewBill, '/bill', primary: true), const SizedBox(width: 8), action(Icons.request_quote_rounded, l.navNewEstimate, '/estimate')]),
            const SizedBox(height: 8),
            Row(children: [action(Icons.add_box_rounded, l.addProduct, '/products?add=1'), const SizedBox(width: 8), action(Icons.payments_rounded, l.receivePayment, '/credit')]),
          ])
        : Row(children: [
            action(Icons.point_of_sale_rounded, '${l.navNewBill}  (F2)', '/bill', primary: true),
            const SizedBox(width: 10),
            action(Icons.request_quote_rounded, '${l.navNewEstimate}  (F3)', '/estimate'),
            const SizedBox(width: 10),
            action(Icons.add_box_rounded, '${l.addProduct}  (Ctrl+Shift+N)', '/products?add=1'),
            const SizedBox(width: 10),
            action(Icons.payments_rounded, l.receivePayment, '/credit'),
          ]);

    final stats = LayoutBuilder(builder: (ctx, bc) {
      final cols = (bc.maxWidth / ctx.textFactor) > 900 ? 4 : ((bc.maxWidth / ctx.textFactor) > 520 ? 2 : 1);
      final w = ((bc.maxWidth - (cols - 1) * 12) / cols).floorToDouble();
      final cards = [
        StatCard(label: l.statTodaySales, value: '₹ ${formatPaise(todayTotal)}', icon: Icons.trending_up_rounded, tone: context.c.success, hint: l.billsCount(hs.today.bills.toString())),
        StatCard(label: l.statToCollect, value: '₹ ${formatPaise(hs.toCollect)}', icon: Icons.south_west_rounded, tone: context.c.warning, hint: l.customersOwing(hs.owingPeople.toString())),
        StatCard(label: l.statLow, value: low.length.toString(), icon: Icons.warning_amber_rounded, tone: context.c.danger, hint: l.needReorder),
        StatCard(label: l.statCashToday, value: '₹ ${formatPaise(hs.today.cash)}', icon: Icons.payments_rounded, hint: l.cashEstimate),
      ];
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final c in cards) SizedBox(width: w, child: c)]);
    });

    final chart = SectionCard(title: l.salesLast7, child: BarChart(values: week, labels: labels));

    final recent = SectionCard(
      title: l.recentBills,
      trailing: TextButton(onPressed: () => context.go('/sales'), child: Text(l.seeAll)),
      child: Column(children: [
        for (final b in hs.recent)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(b.customerName.isEmpty ? l.walkInCustomer : b.customerName, style: th.titleSmall), Text('${b.number} · ${formatTime(b.at)}', style: th.bodySmall)])),
              Text('₹ ${formatPaise(b.totalPaise)}', style: th.titleSmall),
            ]),
          ),
      ]),
    );

    final lowCard = SectionCard(
      title: l.lowStockTitle,
      trailing: TextButton(onPressed: () => context.go('/inventory'), child: Text(l.seeAll)),
      child: low.isEmpty
          ? Text(l.allStockOk)
          : Column(children: [
              for (final p in low.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(p.name, style: th.bodyMedium)),
                    const SizedBox(width: 8),
                    p.outOfStock ? StatusBadge(l.outOfStock, kind: BadgeKind.danger) : StatusBadge('${formatQty(p.stockMilli)} ${p.unit}', kind: BadgeKind.warning),
                  ]),
                ),
            ]),
    );

    final body = <Widget>[
      Text(l.greeting, style: th.headlineSmall),
      Text(l.todayIs(formatDate(now)), style: th.bodySmall),
      const BackupStatusLine(),
      const SizedBox(height: 14),
      actions,
      const SizedBox(height: 14),
      stats,
      const SizedBox(height: 14),
      if (context.isDesktop)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: chart), const SizedBox(width: 14), Expanded(flex: 4, child: lowCard)])
      else ...[chart, const SizedBox(height: 14), lowCard],
      const SizedBox(height: 14),
      recent,
      const SizedBox(height: 24),
    ];
    return ListView(padding: EdgeInsets.all(phone ? 12 : 24), children: body);
  }
}
