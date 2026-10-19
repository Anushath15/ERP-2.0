/// The door between the screens and the database: the open database, everything the screens need at start-up, and the write queue.
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_data.dart';
import '../data/repo/bill_repo.dart';
import '../data/write_queue.dart';
import '../domain/credit/account.dart';
import '../domain/credit/reminder.dart';
import '../domain/models.dart';
import '../core/data_mode.dart';
import '../core/plain_error.dart';
import 'health.dart';
import 'shop_profile.dart';
import 'stats.dart';

/// The open shop database. The app (and each test) overrides this; nothing works without it.
final appDataProvider = Provider<AppData>((ref) => throw StateError('The shop database is not open.'));

/// Everything the screens need the moment they appear: the lists they show at once, read from the database before the first screen.
final bootstrapProvider = Provider<Bootstrap>((ref) => throw StateError('The shop data is not loaded.'));

/// Which data the app is showing (real shop or demo shop) and the way to switch. The start-up root overrides both; in tests they do nothing.
class AppModeNotifier extends Notifier<DataMode> {
  @override
  DataMode build() => DataMode.real;
}

final appModeProvider = NotifierProvider<AppModeNotifier, DataMode>(AppModeNotifier.new);

final modeSwitcherProvider = Provider<Future<void> Function(DataMode)>((ref) => (m) async {});

/// Says in plain words that a write failed (disk full, file locked...); the shell shows it as a banner.
class WriteErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? message) => state = message;
}

final writeErrorProvider = NotifierProvider<WriteErrorNotifier, String?>(WriteErrorNotifier.new);

final writeQueueProvider = Provider<WriteQueue>((ref) {
  final guard = ref.watch(diskGuardProvider);
  return WriteQueue(onError: (e, s) => ref.read(writeErrorProvider.notifier).set(plainError(e)), beforeWrite: guard.checkBeforeWrite);
});

class Bootstrap {
  const Bootstrap({
    required this.products,
    required this.customers,
    required this.dealers,
    required this.categories,
    required this.shop,
    required this.recs,
    required this.estimations,
    required this.customerAccounts,
    required this.dealerAccounts,
    required this.reminders,
    required this.nextInvoice,
    required this.nextEstimate,
    required this.stats,
    required this.firstBills,
  });

  final List<Product> products;
  final List<Customer> customers;
  final List<Rec> dealers;
  final List<Rec> categories;
  final ShopProfile shop;
  final Map<String, List<Rec>> recs;
  final List<EstimationDoc> estimations;
  final Map<String, CreditAccount> customerAccounts, dealerAccounts;
  final ReminderLog reminders;
  final String nextInvoice, nextEstimate;
  final HomeStats stats;

  /// The newest bills (the first page of the sales register), so the register opens with rows already on screen.
  final List<BillRow> firstBills;

  static const recKinds = ['brands', 'units', 'purchases', 'purchaseReturns', 'salesReturns', 'delivery', 'expenses', 'warranty', 'staff', 'notifications'];

  /// Reads the lists the screens show at once. Big things (the sales register, a customer's whole history, reports) are not here:
  /// they are read page by page when asked for.
  static Future<Bootstrap> load(AppData d, {required DateTime now}) async {
    final products = await d.catalog.products();
    final customers = await d.catalog.customers();
    final dealers = await d.catalog.dealers();
    final counts = <String, int>{};
    for (final p in products) {
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }
    final categoryNames = await d.catalog.categoryNames();
    final categories = [
      for (var i = 0; i < categoryNames.length; i++) Rec('k$i', {'name': categoryNames[i], 'items': counts[categoryNames[i]] ?? 0}),
    ];
    final raw = await d.settings.get('shop.profile');
    ShopProfile shop = const ShopProfile();
    if (raw != null) {
      try {
        shop = ShopProfile.fromJson(jsonDecode(raw));
      } catch (_) {
        // a damaged value: the defaults are used and the next change writes a good one
      }
    }
    d.bills.invoicePrefix = shop.invoicePrefix;
    final recs = <String, List<Rec>>{for (final k in recKinds) k: await d.records.list(k)};
    recs['adjustments'] = await d.stock.adjustments();
    return Bootstrap(
      products: products,
      customers: customers,
      dealers: dealers,
      categories: categories,
      shop: shop,
      recs: recs,
      estimations: await d.estimations.list(),
      customerAccounts: await d.ledger.loadActiveAccounts(PartyKind.customer),
      dealerAccounts: await d.ledger.loadActiveAccounts(PartyKind.dealer),
      reminders: ReminderLog(await d.reminders.recent()),
      nextInvoice: await d.bills.peekNextNumber(),
      nextEstimate: await d.estimations.peekNextNumber(),
      stats: await HomeStats.load(d, now),
      firstBills: await d.bills.page(limit: 50),
    );
  }
}
