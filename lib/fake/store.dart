/// In-memory "database" for the prototype: Riverpod providers over the seed data. Nothing is saved to disk.
library;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import 'seed.dart';

final clockProvider = Provider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, n.hour, n.minute);
});

class ProductsNotifier extends Notifier<List<Product>> {
  @override
  List<Product> build() => seedProducts();
  void add(Product p) => state = [p, ...state];
  void update(Product p) => state = [for (final x in state) x.id == p.id ? p : x];
}

final productsProvider = NotifierProvider<ProductsNotifier, List<Product>>(ProductsNotifier.new);

class CustomersNotifier extends Notifier<List<Customer>> {
  @override
  List<Customer> build() => seedCustomers();
  void add(Customer c) => state = [c, ...state];
}

final customersProvider = NotifierProvider<CustomersNotifier, List<Customer>>(CustomersNotifier.new);

final billBookProvider = Provider<BillBook>((ref) => BillBook(ref.watch(clockProvider), customers: ref.watch(customersProvider)));

/// All 20,000 bills, built once on first use.
final billsProvider = Provider<List<BillSummary>>((ref) => ref.watch(billBookProvider).all());

class EstimationsNotifier extends Notifier<List<EstimationDoc>> {
  @override
  List<EstimationDoc> build() => seedEstimations(ref.watch(clockProvider), ref.watch(customersProvider));
  void add(EstimationDoc e) => state = [e, ...state];
  void replace(EstimationDoc e) => state = [for (final x in state) x.number == e.number ? e : x];
  void remove(String number) => state = [for (final x in state) if (x.number != number) x];
}

final estimationsProvider = NotifierProvider<EstimationsNotifier, List<EstimationDoc>>(EstimationsNotifier.new);

/// Generic record lists (dealers, purchases, expenses, ...), keyed by kind.
class RecsNotifier extends Notifier<List<Rec>> {
  RecsNotifier(this.kind);
  final String kind;
  @override
  List<Rec> build() {
    final now = ref.watch(clockProvider);
    final customers = ref.watch(customersProvider);
    final products = ref.watch(productsProvider);
    switch (kind) {
      case 'dealers':
        return seedDealers();
      case 'categories':
        return seedCategories(products);
      case 'purchases':
        return seedPurchases(now, ref.watch(recsProvider('dealers')));
      case 'purchaseReturns':
        return seedPurchaseReturns(now, ref.watch(recsProvider('dealers')));
      case 'salesReturns':
        return seedSalesReturns(now, customers);
      case 'delivery':
        return seedDelivery(now, customers);
      case 'adjustments':
        return seedAdjustments(now, products);
      case 'expenses':
        return seedExpenses(now);
      case 'warranty':
        return seedWarranty(now, customers, products);
      case 'projects':
        return seedProjects();
      case 'staff':
        return seedStaff();
      case 'notifications':
        return seedNotifications(now);
    }
    return const [];
  }

  void add(Rec r) => state = [r, ...state];
  void replace(Rec r) => state = [for (final x in state) x.id == r.id ? r : x];
  void remove(String id) => state = [for (final x in state) if (x.id != id) x];
}

final recsProvider = NotifierProvider.family<RecsNotifier, List<Rec>, String>(RecsNotifier.new);

// ---------------- settings (per device; never synced) ----------------
enum PaperSize { a4, mm80, mm58 }

enum SyncState { synced, syncing, offline, attention }

class AppSettings {
  const AppSettings({
    this.theme = ThemeMode.dark,
    this.textScale = 1.0,
    this.paper = PaperSize.a4,
    this.pricesIncludeGst = true,
    this.shopName = 'Senthil Enterprises',
    this.gstin = '33AAAAA0000A1Z5',
    this.sync = SyncState.synced,
    this.firstRunDone = true,
    this.signedIn = true,
  });
  final ThemeMode theme;
  final double textScale;
  final PaperSize paper;
  final bool pricesIncludeGst, firstRunDone, signedIn;
  final String shopName, gstin;
  final SyncState sync;

  AppSettings copyWith({ThemeMode? theme, double? textScale, PaperSize? paper, bool? pricesIncludeGst, String? shopName, String? gstin, SyncState? sync, bool? firstRunDone, bool? signedIn}) => AppSettings(
        theme: theme ?? this.theme,
        textScale: textScale ?? this.textScale,
        paper: paper ?? this.paper,
        pricesIncludeGst: pricesIncludeGst ?? this.pricesIncludeGst,
        shopName: shopName ?? this.shopName,
        gstin: gstin ?? this.gstin,
        sync: sync ?? this.sync,
        firstRunDone: firstRunDone ?? this.firstRunDone,
        signedIn: signedIn ?? this.signedIn,
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();
  void set(AppSettings Function(AppSettings) f) => state = f(state);
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
