/// What the Home page, the sales register and the day closing show at a glance: today's totals, the last seven days, the newest bills,
/// what is owed. All of it comes from the summary tables, so it is fast whatever the number of bills.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_data.dart';
import '../data/repo/bill_repo.dart';
import '../data/repo/report_repo.dart';
import 'data_providers.dart';
import 'store.dart';

class HomeStats {
  const HomeStats({required this.today, required this.week, required this.weekDays, required this.recent, required this.toCollect, required this.owingPeople, required this.lowStock, required this.billCount});
  final DayTotals today;

  /// Sales of the last seven days, oldest first, and the days they belong to.
  final List<int> week;
  final List<DateTime> weekDays;
  final List<BillRow> recent;
  final int toCollect, owingPeople, lowStock, billCount;

  static Future<HomeStats> load(AppData d, DateTime now) async {
    final day0 = DateTime(now.year, now.month, now.day);
    final from = day0.subtract(const Duration(days: 6));
    final days = await d.reports.days(from, day0);
    final byDay = {for (final t in days) t.day: t.sales};
    final dates = [for (var i = 0; i < 7; i++) from.add(Duration(days: i))];
    final c = await d.reports.toCollect();
    return HomeStats(
      today: await d.reports.day(day0),
      week: [for (final x in dates) byDay['${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}'] ?? 0],
      weekDays: dates,
      recent: await d.bills.page(limit: 6),
      toCollect: c.total,
      owingPeople: c.people,
      lowStock: await d.reports.lowStockCount(),
      billCount: await d.bills.countFast(),
    );
  }
}

class StatsNotifier extends Notifier<HomeStats> {
  @override
  HomeStats build() => ref.read(bootstrapProvider).stats;

  /// Read again after a bill, a payment, a cancellation or a stock change.
  Future<void> refresh() async {
    state = await HomeStats.load(ref.read(appDataProvider), ref.read(clockProvider));
  }
}

final statsProvider = NotifierProvider<StatsNotifier, HomeStats>(StatsNotifier.new);
