/// The things the screens do that touch many parts at once (a bill changes stock, a customer's balance, today's totals and the next
/// number). Each one waits for the database, then refreshes what the screens show.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repo/bill_repo.dart';
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

  Future<void> refreshAfter({Iterable<String> productIds = const [], String? customerId}) async {
    if (productIds.isNotEmpty) await ref.read(productsProvider.notifier).reload(productIds);
    if (customerId != null) await ref.read(creditProvider.notifier).refreshParty(customerId);
    await ref.read(statsProvider.notifier).refresh();
    await ref.read(nextNumbersProvider.notifier).refresh();
  }
}

final billActionsProvider = Provider<BillActions>(BillActions.new);
