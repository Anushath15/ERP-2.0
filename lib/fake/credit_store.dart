/// State for customer and dealer accounts. The rules live in lib/domain/credit (pure Dart, tested) and the writing lives in
/// lib/data/repo/ledger_repo.dart; this file keeps the accounts the screens show and refreshes them after every change.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_data.dart';
import '../data/ids.dart';
import '../domain/credit/ledger.dart';
import '../domain/credit/account.dart';
import '../domain/credit/reminder.dart';
import 'data_providers.dart';
import 'store.dart';

export '../demo/seed_credit.dart';
export '../domain/credit/account.dart';

const currentUser = 'Owner';

/// The operations every person-account has (customers owe us, we owe dealers). Positive balance = the other side is owed
/// money by the one in the book's title: for customers "they owe us", for dealers "we owe them".
///
/// Every operation that changes money waits for the database (one transaction) before the screen shows it as done.
abstract class PartyLedgerNotifier extends Notifier<Map<String, CreditAccount>> {
  PartyKind get kind;

  /// Prefix of receipt numbers ("RCP" for customer payments, "PAY" for payments to dealers).
  String get receiptPrefix;

  AppData get _data => ref.read(appDataProvider);

  CreditAccount account(String partyId) => state[partyId] ?? const CreditAccount();
  int balanceOf(String partyId) => account(partyId).balance;

  /// Loads an account that was not read at start-up (a customer who has been quiet a long time). Call when a profile opens.
  Future<void> ensureLoaded(String partyId) async {
    if (state.containsKey(partyId)) return;
    await refreshParty(partyId);
  }

  /// Reads the account again after something changed it (a bill, a payment, a reversal), here and in the lists.
  Future<void> refreshParty(String partyId) async {
    final a = await _data.ledger.account(partyId);
    state = {...state, partyId: a};
    onBalance(partyId, a.balance);
  }

  /// Lets the customer or dealer list show the new balance.
  void onBalance(String partyId, int balance);

  /// What the party owed right after the bill [billNo] was added to the account (null if the bill left no entry).
  int? balanceAfterBill(String partyId, String billNo) {
    int? out;
    for (final l in withRunningBalance(account(partyId).ledger)) {
      if (l.entry.billNo == billNo) out = l.runningPaise;
    }
    return out;
  }

  Future<T> _run<T>(Future<T> Function() job) => ref.read(writeQueueProvider).run(job);

  /// A payment: applied to the oldest unpaid bills (or only [onlyBills]); any rest becomes an advance.
  Future<PaymentReceipt> receivePayment({required String customerId, required String customerName, required int amount, required String mode, required DateTime at, String note = '', Set<String>? onlyBills}) async {
    final r = await _run(() => _data.ledger.receivePayment(kind, partyId: customerId, partyName: customerName, amount: amount, mode: mode, at: at, note: note, onlyBills: onlyBills));
    await refreshParty(customerId);
    return r;
  }

  /// "Settle fully": records the whole balance as received (or paid). Returns null when nothing is owed.
  Future<PaymentReceipt?> settleFully({required String customerId, required String customerName, required String mode, required DateTime at, String note = ''}) async {
    final r = await _run(() => _data.ledger.settleFully(kind, partyId: customerId, partyName: customerName, mode: mode, at: at, note: note));
    if (r != null) await refreshParty(customerId);
    return r;
  }

  /// Takes a just-made payment back (the 8-second Undo). Works only while nothing else was added and it was not uploaded yet.
  Future<bool> undoPayment(PaymentReceipt r) async {
    final ok = await _run(() => _data.ledger.undoPayment(kind, r));
    if (ok) await refreshParty(r.customerId);
    return ok;
  }

  /// Credit added by hand. It becomes a bill-like line (so it ages and payments settle it oldest-first). Returns its number.
  Future<String> addManualCredit({required String customerId, required int amount, required DateTime at, required String reason}) async {
    final no = await _run(() => _data.ledger.addManualCredit(kind, partyId: customerId, amount: amount, at: at, reason: reason));
    await refreshParty(customerId);
    return no;
  }

  /// A correction by hand, either way. Plus = they owe more; minus = they owe less (taken off the oldest bills). A reason is required.
  Future<void> addAdjustment({required String partyId, required int signedPaise, required DateTime at, required String reason}) async {
    await _run(() => _data.ledger.addAdjustment(kind, partyId: partyId, signedPaise: signedPaise, at: at, reason: reason));
    await refreshParty(partyId);
  }

  /// A starting balance for someone who already owed (or paid ahead) before this program. Positive = owes.
  Future<void> addOpening({required String customerId, required int amount, required DateTime at}) async {
    await _run(() => _data.ledger.addOpening(kind, partyId: customerId, amount: amount, at: at));
    await refreshParty(customerId);
  }

  /// Fixes a wrong entry with a NEW entry (the wrong one stays visible). Throws when the entry cannot be reversed or already was.
  Future<void> reverseEntry({required String partyId, required String entryId, required String reason, required DateTime at}) async {
    await _run(() => _data.ledger.reverseEntry(kind, partyId: partyId, entryId: entryId, reason: reason, at: at));
    await refreshParty(partyId);
  }

  /// Owner only. Cannot write off more than is owed.
  Future<void> writeOff({required String customerId, required int amount, required String reason, required DateTime at}) async {
    await _run(() => _data.ledger.writeOff(kind, partyId: customerId, amount: amount, reason: reason, at: at));
    await refreshParty(customerId);
  }
}

class CreditNotifier extends PartyLedgerNotifier {
  @override
  PartyKind get kind => PartyKind.customer;

  @override
  String get receiptPrefix => 'RCP';

  @override
  Map<String, CreditAccount> build() => ref.read(bootstrapProvider).customerAccounts;

  @override
  void onBalance(String partyId, int balance) => ref.read(customersProvider.notifier).setBalance(partyId, balance);

  int get totalToCollect => state.values.fold<int>(0, (s, a) => a.balance > 0 ? s + a.balance : s);
  int get totalAdvances => state.values.fold<int>(0, (s, a) => a.balance < 0 ? s - a.balance : s);
}

final creditProvider = NotifierProvider<CreditNotifier, Map<String, CreditAccount>>(CreditNotifier.new);

/// What we owe each dealer: purchases on credit, payments to the dealer, returns and adjustments (same rules as customers).
class DealerLedgerNotifier extends PartyLedgerNotifier {
  @override
  PartyKind get kind => PartyKind.dealer;

  @override
  String get receiptPrefix => 'PAY';

  @override
  Map<String, CreditAccount> build() => ref.read(bootstrapProvider).dealerAccounts;

  @override
  void onBalance(String partyId, int balance) => ref.read(recsProvider('dealers').notifier).setBalance(partyId, balance);

  int get totalWeOwe => state.values.fold<int>(0, (s, a) => a.balance > 0 ? s + a.balance : s);
}

final dealerLedgerProvider = NotifierProvider<DealerLedgerNotifier, Map<String, CreditAccount>>(DealerLedgerNotifier.new);

/// The account book for a kind of party (for screens that serve both customers and dealers).
Map<String, CreditAccount> watchBook(WidgetRef ref, PartyKind k) => k == PartyKind.customer ? ref.watch(creditProvider) : ref.watch(dealerLedgerProvider);
PartyLedgerNotifier bookOf(WidgetRef ref, PartyKind k) => k == PartyKind.customer ? ref.read(creditProvider.notifier) : ref.read(dealerLedgerProvider.notifier);

class ReminderLogNotifier extends Notifier<ReminderLog> {
  @override
  ReminderLog build() => ref.read(bootstrapProvider).reminders;

  /// Records "opened in WhatsApp". The record is in the list at once; the database write follows (and is held back 10 s before it may upload).
  ReminderRecord record({required String customerId, required int amountDue, required String message, required DateTime at}) {
    final id = newId();
    final r = ReminderRecord(id: id, customerId: customerId, at: at, amountDuePaise: amountDue, message: message, by: currentUser);
    state = state.add(r);
    final d = ref.read(appDataProvider);
    ref.read(writeQueueProvider).add(() async {
      await d.reminders.record(id: id, customerId: customerId, amountDue: amountDue, message: message, at: at);
    });
    return r;
  }

  void undo(String id) {
    state = state.undo(id);
    final d = ref.read(appDataProvider);
    ref.read(writeQueueProvider).add(() async {
      await d.reminders.undo(id);
    });
  }
}

final reminderLogProvider = NotifierProvider<ReminderLogNotifier, ReminderLog>(ReminderLogNotifier.new);
