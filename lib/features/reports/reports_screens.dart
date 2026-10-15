import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../design/effects.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../data/repo/report_repo.dart';
import '../../fake/data_providers.dart';
import '../../fake/shop_profile.dart';
import '../../fake/stats.dart';
import '../../fake/store.dart';
import '../dashboard/dashboard_screen.dart';

/// Everything one report range shows, read from the day and month summaries (never from the bills themselves).
class ReportData {
  const ReportData({required this.sales, required this.bills, required this.cash, required this.upi, required this.card, required this.credit, required this.profit, required this.values, required this.labels, required this.top});
  final int sales, bills, cash, upi, card, credit, profit;
  final List<int> values;
  final List<String> labels;
  final List<({String name, int amount})> top;

  static ReportData empty(int range, DateTime now) {
    final b = range == 2 ? 12 : (range == 1 ? 15 : 7);
    return ReportData(sales: 0, bills: 0, cash: 0, upi: 0, card: 0, credit: 0, profit: 0, values: List.filled(b, 0), labels: List.filled(b, ''), top: const []);
  }
}

final reportProvider = FutureProvider.family<ReportData, int>((ref, range) async {
  final d = ref.watch(appDataProvider);
  ref.watch(statsProvider); // read again after every bill
  final now = ref.watch(clockProvider);
  final today = DateTime(now.year, now.month, now.day);
  final days = switch (range) { 0 => 7, 1 => 30, _ => 365 };
  final from = today.subtract(Duration(days: days - 1));
  final rows = await d.reports.days(from, today);
  final buckets = range == 2 ? 12 : (range == 1 ? 15 : 7);
  final span = days / buckets;
  final values = List<int>.filled(buckets, 0);
  for (final t in rows) {
    final date = DateTime.parse(t.day);
    final age = today.difference(date).inDays;
    values[buckets - 1 - (age / span).floor().clamp(0, buckets - 1)] += t.sales;
  }
  final labels = [for (var i = 0; i < buckets; i++) range == 2 ? '${today.subtract(Duration(days: ((buckets - 1 - i) * span).round())).month}' : two(today.subtract(Duration(days: ((buckets - 1 - i) * span).round())).day)];
  final sum = DayTotals.sum('range', rows);
  // profit: what was sold before tax minus what it cost; where no cost is known the old 19% rule of thumb is shown (the card says estimate)
  final profit = sum.cost > 0 ? sum.taxable - sum.cost : (sum.taxable * 19 / 100).round();
  return ReportData(sales: sum.sales, bills: sum.bills, cash: sum.cash, upi: sum.upi, card: sum.card, credit: sum.credit, profit: profit, values: values, labels: labels, top: await d.reports.topProducts(from, today));
});

class ClosingScreen extends ConsumerStatefulWidget {
  const ClosingScreen({super.key});
  @override
  ConsumerState<ClosingScreen> createState() => _ClosingScreenState();
}

class _ClosingScreenState extends ConsumerState<ClosingScreen> {
  final _counted = TextEditingController();
  bool _closed = false;

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final now = ref.watch(clockProvider);
    final today = ref.watch(statsProvider).today;
    final th = Theme.of(context).textTheme;
    bool sameDay(DateTime a) => a.year == now.year && a.month == now.month && a.day == now.day;
    final cash = today.cash, upi = today.upi, card = today.card;
    final credit = today.credit;
    final expenses = ref.watch(recsProvider('expenses')).where((r) => sameDay(r.f['date'] as DateTime)).fold<int>(0, (s, r) => s + r.i('amount'));
    final opening = ref.watch(shopProvider).openingCashPaise;
    final expected = opening + cash - expenses;
    final countedPaise = ((double.tryParse(_counted.text) ?? 0) * 100).round();
    final diff = countedPaise - expected;
    Widget row(String k, String v, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(k, style: bold ? th.titleSmall : th.bodyMedium)), Text(v, style: bold ? th.titleMedium : th.bodyMedium)]));

    final summary = SectionCard(title: l.closingSummary(formatDate(now)), child: Column(children: [
      row(l.statBillsToday, '${today.bills}'),
      row(l.closingCashSales, '₹ ${formatPaise(cash)}'),
      row(l.payUpi, '₹ ${formatPaise(upi)}'),
      row(l.payCard, '₹ ${formatPaise(card)}'),
      row(l.closingCreditGiven, '₹ ${formatPaise(credit)}'),
      const Divider(),
      row(l.closingOpening, '₹ ${formatPaise(opening)}'),
      row(l.closingExpenses, '- ₹ ${formatPaise(expenses)}'),
      row(l.closingExpected, '₹ ${formatPaise(expected)}', bold: true),
    ]));
    final count = SectionCard(title: l.closingCount, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.closingCountHelp, style: th.bodySmall),
      const SizedBox(height: 10),
      TextField(controller: _counted, enabled: !_closed, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: l.closingCounted, prefixText: '₹ ')),
      const SizedBox(height: 10),
      if (_counted.text.isNotEmpty)
        StatusBadge(diff == 0 ? l.closingTally : (diff > 0 ? l.closingExtra(formatPaise(diff.abs(), symbol: true)) : l.closingShort(formatPaise(diff.abs(), symbol: true))), kind: diff == 0 ? BadgeKind.success : BadgeKind.warning, icon: diff == 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: _closed || _counted.text.isEmpty ? null : () async {
          final ok = await confirmDialog(context, title: l.closingConfirmTitle, message: l.closingConfirmText(formatDate(now)), confirmLabel: l.closeDay);
          if (ok) {
            setState(() => _closed = true);
            if (context.mounted) toast(context, l.closingDone);
          }
        },
        icon: const Icon(Icons.event_available),
        label: Text(_closed ? l.dayClosed : l.closeDay),
      ),
    ]));
    return PageFrame(
      title: l.navClosing,
      subtitle: l.closingSubtitle,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: context.isDesktop ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: summary), const SizedBox(width: 14), Expanded(child: count)]) : Column(children: [summary, const SizedBox(height: 12), count]),
      ),
    );
  }
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _range = 1; // 0 = 7 days, 1 = 30 days, 2 = 12 months

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final now = ref.watch(clockProvider);
    final th = Theme.of(context).textTheme;
    final data = ref.watch(reportProvider(_range));
    final r = data.value ?? ReportData.empty(_range, now);
    final total = r.sales, avg = r.bills == 0 ? 0 : total ~/ r.bills;
    final values = r.values;
    final labels = r.labels;
    final modes = [(l.payCash, r.cash), (l.payUpi, r.upi), (l.payCard, r.card), (l.payCredit, r.credit)];
    final top = [for (final t in r.top) (t.name, t.amount)];
    final profit = r.profit;

    Widget share(List<(String, int)> rows, Color color) {
      final mx = rows.fold<int>(1, (m, r) => r.$2 > m ? r.$2 : m);
      return Column(children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(r.$1, style: th.bodyMedium)), Text('₹ ${formatPaise(r.$2)}', style: th.titleSmall)]),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: r.$2 / mx, minHeight: 8, color: color, backgroundColor: context.c.surfaceAlt)),
            ]),
          ),
      ]);
    }

    final stats = Wrap(spacing: 12, runSpacing: 12, children: [
      for (final s in [
        StatCard(label: l.statSales, value: '₹ ${formatPaise(total)}', icon: Icons.trending_up, tone: context.c.success),
        StatCard(label: l.statBills, value: '${r.bills}', icon: Icons.receipt_long_outlined),
        StatCard(label: l.statAvgBill, value: '₹ ${formatPaise(avg)}', icon: Icons.calculate_outlined),
        StatCard(label: l.statProfit, value: '₹ ${formatPaise(profit)}', icon: Icons.savings_outlined, tone: context.c.success, hint: l.profitEstimate),
      ])
        SizedBox(width: context.isPhone ? double.infinity : 230, child: s),
    ]);
    final charts = [
      SectionCard(title: l.salesOverTime, child: BarChart(values: values, labels: labels, height: 160)),
      SectionCard(title: l.byPayMode, child: share(modes, context.c.primary)),
      SectionCard(title: l.topProducts, child: share(top, context.c.success)),
    ];
    return PageFrame(
      title: l.navReports,
      subtitle: l.reportsSubtitle,
      actions: [OutlinedButton.icon(onPressed: () => toast(context, l.exportedDemo), icon: const Icon(Icons.ios_share), label: Text(l.navExport))],
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [ButtonSegment(value: 0, label: Text(l.range7)), ButtonSegment(value: 1, label: Text(l.range30)), ButtonSegment(value: 2, label: Text(l.range12m))],
          selected: {_range},
          onSelectionChanged: (s) => setState(() => _range = s.first),
        ),
        const SizedBox(height: 12),
        stats,
        const SizedBox(height: 12),
        if (context.isDesktop) ...[
          charts[0],
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: charts[1]), const SizedBox(width: 12), Expanded(child: charts[2])]),
        ] else
          for (final c in charts) Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
      ]),
    );
  }
}

class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = <(IconData, String, String)>[
      (Icons.receipt_long_outlined, l.expSales, l.expSalesHelp),
      (Icons.inventory_2_outlined, l.expProducts, l.expProductsHelp),
      (Icons.people_outline, l.expCustomers, l.expCustomersHelp),
      (Icons.account_balance_wallet_outlined, l.expDues, l.expDuesHelp),
      (Icons.payments_outlined, l.expExpenses, l.expExpensesHelp),
      (Icons.percent, l.expGst, l.expGstHelp),
    ];
    final th = Theme.of(context).textTheme;
    return PageFrame(
      title: l.navExport,
      subtitle: l.exportSubtitle,
      child: LayoutBuilder(builder: (ctx, bc) {
        final cols = (bc.maxWidth / ctx.textFactor) > 980 ? 3 : ((bc.maxWidth / ctx.textFactor) > 620 ? 2 : 1);
        final w = ((bc.maxWidth - (cols - 1) * 12) / cols).floorToDouble();
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            for (final it in items)
              SizedBox(
                width: w,
                child: SectionCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Icon(it.$1, color: context.c.primary), const SizedBox(width: 10), Expanded(child: Text(it.$2, style: th.titleMedium))]),
                    const SizedBox(height: 6),
                    Text(it.$3, style: th.bodySmall),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final f in ['Excel', 'CSV', 'PDF']) OutlinedButton(onPressed: () => toast(context, l.exportedDemoFile(f)), child: Text(f)),
                    ]),
                  ]),
                ),
              ),
          ]),
        );
      }),
    );
  }
}

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});
  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  int _step = 0; // 0 choose file, 1 dry-run report, 2 done
  bool _checking = false;

  /// Demo of a slow step: the report takes about a second to build, so a placeholder shows (after 150 ms) instead of a frozen screen.
  Future<void> _check() async {
    setState(() => _checking = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() { _checking = false; _step = 1; });
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final c = context.c;
    Widget stepBody;
    if (_step == 0) {
      stepBody = SectionCard(title: l.importStep1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.importHelp, style: th.bodyMedium),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: _checking ? null : _check, icon: const Icon(Icons.folder_open), label: Text(l.chooseBackupFile)),
        const SizedBox(height: 8),
        Text(l.importSafe, style: th.bodySmall),
      ]));
    } else if (_step == 1) {
      stepBody = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionCard(title: l.importReport, child: Column(children: [
          for (final r in [(l.statItems, '757'), (l.navCustomers, '4,982'), (l.navDealers, '38'), (l.statBills, '12,604'), (l.statStockValue, '₹ 18,42,760.00'), (l.statToCollect, '₹ 6,31,200.00')])
            Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(r.$1)), Text(r.$2, style: th.titleSmall)])),
        ])),
        const SizedBox(height: 12),
        SectionCard(title: l.importWarnings, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusBadge(l.warnNegStock('11'), kind: BadgeKind.warning, icon: Icons.warning_amber_rounded),
          const SizedBox(height: 6),
          StatusBadge(l.warnNoCost('64'), kind: BadgeKind.warning, icon: Icons.warning_amber_rounded),
          const SizedBox(height: 6),
          StatusBadge(l.warnDupNames('3'), kind: BadgeKind.warning, icon: Icons.warning_amber_rounded),
          const SizedBox(height: 6),
          StatusBadge(l.warnBadDates('2'), kind: BadgeKind.warning, icon: Icons.warning_amber_rounded),
          const SizedBox(height: 10),
          Text(l.importWarnHelp, style: th.bodySmall),
        ])),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton(onPressed: () => setState(() => _step = 0), child: Text(l.cancel)),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(onPressed: () => setState(() => _step = 2), icon: const Icon(Icons.download_done), label: Text(l.importNow))),
        ]),
      ]);
    } else {
      stepBody = SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.check_circle, color: c.success, size: 32), const SizedBox(width: 10), Expanded(child: Text(l.importDone, style: th.titleLarge))]),
        const SizedBox(height: 10),
        Text(l.importProof, style: th.bodyMedium),
        const SizedBox(height: 10),
        for (final r in [l.proofProducts, l.proofStock, l.proofBalances, l.proofBills]) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Icon(Icons.check, size: 18, color: c.success), const SizedBox(width: 8), Expanded(child: Text(r))])),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: () => setState(() => _step = 0), child: Text(l.importAgain)),
      ]));
    }
    return PageFrame(
      title: l.navImport,
      subtitle: l.importSubtitle,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            stepBody,
            if (_checking) const SizedBox(height: 200, child: DelayedLoader(loading: true, skeleton: SkeletonBlocks(rows: 3), child: SizedBox.shrink())),
          ]),
        ),
      ),
    );
  }
}
