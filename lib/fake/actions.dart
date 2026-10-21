/// The things the screens do that touch many parts at once (a bill changes stock, a customer's balance, today's totals and the next
/// number). Each one waits for the database, then refreshes what the screens show.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repo/bill_repo.dart';
import '../data/repo/purchase_repo.dart';
import '../data/repo/purchase_return_repo.dart';
import '../data/repo/return_repo.dart';
import 'credit_store.dart';
import 'data_providers.dart';
import 'stats.dart';
import 'store.dart';

class BillActions {
  BillActions(this.ref);
  final Ref ref;

  /// Saves a bill (see BillRepo.saveBill). Nothing is shown as saved until the database has it.
  Future<SavedBill> save(SaveBillInput input) async {
    final d = ref.read(appDataProvider);
    final saved = await ref.read(writeQueueProvider).run(() => d.bills.saveBill(input));
    await refreshAfter(productIds: [for (final l in input.lines) l.productId], customerId: input.customerId);
    return saved;
  }

  /// Cancels a bill (owner, with a reason): stock back, credit reversed. Returns false when it was already cancelled.
  Future<bool> cancel(String billId, {required String reason}) async {
    final d = ref.read(appDataProvider);
    final detail = await d.bills.detail(billId);
    if (detail == null) return false;
    final done = await ref.read(writeQueueProvider).run(() => d.bills.cancelBill(billId, reason: reason, at: ref.read(clockProvider)));
    if (done) await refreshAfter(productIds: [for (final l in detail.lines) l.productId], customerId: detail.row.customerId);
    return done;
  }

  /// Saves a sales return from a bill (see ReturnRepo): stock back, the customer's debt or a refund, the day totals. Refreshes the
  /// screens that show any of them.
  Future<SavedReturn> returnItems(SaveReturnInput input, {required Iterable<String> productIds, String? customerId}) async {
    final d = ref.read(appDataProvider);
    final saved = await ref.read(writeQueueProvider).run(() => d.returns.saveReturn(input));
    await refreshAfter(productIds: productIds, customerId: customerId);
    ref.read(returnsVersionProvider.notifier).bump();
    return saved;
  }

  /// Saves a purchase from a dealer (see PurchaseRepo): stock in, the dealer's account, the buying prices. Refreshes what shows them.
  Future<SavedPurchase> savePurchase(SavePurchaseInput input) async {
    final d = ref.read(appDataProvider);
    final saved = await ref.read(writeQueueProvider).run(() => d.purchases.savePurchase(input));
    await _afterPurchase(input.dealerId, [for (final l in input.lines) l.productId], received: saved.received);
    return saved;
  }

  /// Saves the changes to a saved purchase (see PurchaseRepo.editPurchase) and refreshes what the screens show.
  Future<SavedPurchase> editPurchase(String purchaseId, SavePurchaseInput input, {Iterable<String> oldProductIds = const []}) async {
    final d = ref.read(appDataProvider);
    final saved = await ref.read(writeQueueProvider).run(() => d.purchases.editPurchase(purchaseId, input));
    await _afterPurchase(input.dealerId, {...oldProductIds, for (final l in input.lines) l.productId}.toList(), received: saved.received);
    await ref.read(statsProvider.notifier).refresh();
    return saved;
  }

  /// A pending purchase arrives: stock and the dealer's account are updated now.
  Future<bool> markPurchaseReceived(PurchaseRow row) async {
    final d = ref.read(appDataProvider);
    final detail = await d.purchases.detail(row.id);
    final done = await ref.read(writeQueueProvider).run(() => d.purchases.markReceived(row.id, at: ref.read(clockProvider)));
    if (done) await _afterPurchase(row.dealerId, [for (final l in detail?.lines ?? const <PurchaseLineView>[]) l.productId], received: true);
    return done;
  }

  /// Gives goods back to a dealer from a received purchase (see PurchaseReturnRepo): stock out, the dealer's account. Refreshes the screens.
  Future<SavedPurchaseReturn> returnToDealer(SavePurchaseReturnInput input, {required Iterable<String> productIds, required String dealerId}) async {
    final d = ref.read(appDataProvider);
    final saved = await ref.read(writeQueueProvider).run(() => d.purchaseReturns.saveReturn(input));
    await ref.read(productsProvider.notifier).reload(productIds);
    await ref.read(dealerLedgerProvider.notifier).refreshParty(dealerId);
    ref.read(purchasesVersionProvider.notifier).bump();
    return saved;
  }

  Future<void> _afterPurchase(String dealerId, List<String> productIds, {required bool received}) async {
    if (received) {
      await ref.read(productsProvider.notifier).reload(productIds);
      await ref.read(dealerLedgerProvider.notifier).refreshParty(dealerId);
    }
    ref.read(purchasesVersionProvider.notifier).bump();
  }

  Future<void> refreshAfter({Iterable<String> productIds = const [], String? customerId}) async {
    if (productIds.isNotEmpty) await ref.read(productsProvider.notifier).reload(productIds);
    if (customerId != null) await ref.read(creditProvider.notifier).refreshParty(customerId);
    await ref.read(statsProvider.notifier).refresh();
    await ref.read(nextNumbersProvider.notifier).refresh();
  }
}

final billActionsProvider = Provider<BillActions>(BillActions.new);

/// Counts the sales returns saved in this run, so the returns list and the bill screens know to read again.
class ReturnsVersion extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final returnsVersionProvider = NotifierProvider<ReturnsVersion, int>(ReturnsVersion.new);

/// Counts the purchases saved or received in this run, so the purchase lists and the dealer pages read again.
final purchasesVersionProvider = NotifierProvider<ReturnsVersion, int>(ReturnsVersion.new);
