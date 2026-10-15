import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/stock_value.dart';
import 'data_providers.dart';
import 'store.dart';

/// The ONE stock-value calculation, for every screen that shows it (Inventory, Health, exports). It recomputes when the product list (and so a stock figure) changes.
final stockValuationProvider = FutureProvider.autoDispose<StockValuation>((ref) {
  ref.watch(productsProvider);
  return ref.watch(appDataProvider).reports.stockValuation();
});
