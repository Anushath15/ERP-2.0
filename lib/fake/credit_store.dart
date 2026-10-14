/// Prototype state for customer credit (Phase 1: in memory, fake data). The rules live in lib/domain/credit (pure Dart, tested);
/// this file only holds the data and calls those rules. Phase 2 stores the same entries in the database (docs/data-model.md).
library;

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/credit/account.dart';
import '../domain/credit/dues.dart';
import '../domain/credit/ledger.dart';
import '../domain/credit/payment_split.dart';
import '../domain/credit/reminder.dart';
import 'models.dart';
import 'store.dart';

export '../domain/credit/account.dart';

const currentUser = 'Owner';

/// The operations every person-account has (customers owe us, we owe dealers). Positive balance = the other side is owed
/// money by the one in the book's title: for customers "they owe us", for dealers "we owe them".
abstract class PartyLedgerNotifier extends Notifier<Map<String, CreditAccount>> {
  int _seq = 1000;
  int _rcp = 40;
  int _manual = 1;

  /// Prefix of receipt numbers ("RCP" for customer payments, "PAY" for payments to dealers).
  String get receiptPrefix;

  /// Words kept in notes so the ledger reads right for this kind of account.
  String get paidMoreNote => 'Paid more than was due';

  CreditAccount account(String partyId) => state[partyId] ?? const CreditAccount();
  int balanceOf(String partyId) => account(partyId).balance;

  String _id() => 'le${_seq++}';
  void _put(String id, CreditAccount a) => state = {...state, id: a};

  /// What the party owed right after the bill [billNo] was added to the account (null if the bill left no entry).
  int? balanceAfterBill(String partyId, String billNo) {
    int? out;
    for (final l in withRunningBalance(account(partyId).ledger)) {
      if (l.entry.billNo == billNo) out = l.runningPaise;
    }
    return out;
  }

  /// A payment: applied to the oldest unpaid bills (or only [onlyBills]); any rest becomes an advance.
  PaymentReceipt receivePayment({required String customerId, required String customerName, required int amount, required String mode, required DateTime at, String note = '', Set<String>? onlyBills}) {
    final a = account(customerId);
    final res = allocatePayment(bills: a.bills, amount: amount, onlyBills: onlyBills);
    // Money beyond the bills (when everything is not chosen by hand) first pays off an old opening balance that has no bill behind it.
    final toUnbilled = onlyBills == null ? (a.unbilledBalance > 0 ? (res.advancePaise < a.unbilledBalance ? res.advancePaise : a.unbilledBalance) : 0) : 0;
    final advance = res.advancePaise - toUnbilled;
    final ledger = [...a.ledger];
    if (res.appliedPaise + toUnbilled > 0) {
      ledger.add(LedgerEntry.payment(id: _id(), customerId: customerId, paise: res.appliedPaise + toUnbilled, at: at, mode: mode, note: note, by: currentUser, allocations: res.allocations));
    }
    if (advance > 0) {
      ledger.add(LedgerEntry.advance(id: _id(), customerId: customerId, paise: advance, at: at, mode: mode, note: note.isEmpty ? paidMoreNote : note, by: currentUser));
    }
    final updated = a.copyWith(ledger: ledger, bills: applyAllocations(a.bills, res.allocations));
    _put(customerId, updated);
    final r = PaymentReceipt(number: '$receiptPrefix-${(_rcp++).toString().padLeft(4, '0')}', customerId: customerId, customerName: customerName, amountPaise: amount, mode: mode, at: at, note: note, allocations: res.allocations, advancePaise: advance, balanceAfter: updated.balance);
    _snapshots[r.number] = (a, updated);
    return r;
  }

  final _snapshots = <String, (CreditAccount before, CreditAccount after)>{};

  /// "Settle fully": records the whole balance as received (or paid). Returns null when nothing is owed.
  PaymentReceipt? settleFully({required String customerId, required String customerName, required String mode, required DateTime at, String note = ''}) {
    final owed = account(customerId).balance;
    if (owed <= 0) return null;
    return receivePayment(customerId: customerId, customerName: customerName, amount: owed, mode: mode, at: at, note: note.isEmpty ? 'Settled fully' : note);
  }

  /// Takes a just-made payment back (the 8-second Undo). Works only while nothing else has changed on that account; the
  /// entries were never uploaded (reminder-style hold-back, see docs/data-model.md), so nothing is left behind.
  bool undoPayment(PaymentReceipt r) {
    final snap = _snapshots[r.number];
    if (snap == null || !identical(state[r.customerId] ?? const CreditAccount(), snap.$2)) return false;
    state = {...state, r.customerId: snap.$1};
    _snapshots.remove(r.number);
    return true;
  }

  /// Credit added by hand. It becomes a bill-like line (so it ages and payments settle it oldest-first).
  String addManualCredit({required String customerId, required int amount, required DateTime at, required String reason}) {
    final a = account(customerId);
    final no = 'CR-${(_manual++).toString().padLeft(3, '0')}';
    final e = LedgerEntry.manualCredit(id: _id(), customerId: customerId, paise: amount, at: at, reason: reason, by: currentUser, billNo: no);
    _put(customerId, a.copyWith(ledger: [...a.ledger, e], bills: [...a.bills, BillDue(billNo: no, date: at, totalPaise: amount, paidPaise: 0)]));
    return no;
  }

  /// A correction by hand, either way. Plus = they owe more (it becomes a bill-like line); minus = they owe less (taken off the
  /// oldest bills). A reason is required.
  void addAdjustment({required String partyId, required int signedPaise, required DateTime at, required String reason}) {
    final a = account(partyId);
    if (signedPaise > 0) {
      final no = 'ADJ-${(_manual++).toString().padLeft(3, '0')}';
      final e = LedgerEntry.adjustment(id: _id(), customerId: partyId, signedPaise: signedPaise, at: at, reason: reason, by: currentUser, billNo: no);
      _put(partyId, a.copyWith(ledger: [...a.ledger, e], bills: [...a.bills, BillDue(billNo: no, date: at, totalPaise: signedPaise, paidPaise: 0)]));
    } else {
      final res = allocatePayment(bills: a.bills, amount: -signedPaise);
      final e = LedgerEntry.adjustment(id: _id(), customerId: partyId, signedPaise: signedPaise, at: at, reason: reason, by: currentUser, allocations: res.allocations);
      _put(partyId, a.copyWith(ledger: [...a.ledger, e], bills: applyAllocations(a.bills, res.allocations)));
    }
  }

  /// A starting balance for someone who already owed (or paid ahead) before this program. Positive = owes.
  void addOpening({required String customerId, required int amount, required DateTime at}) {
    if (amount == 0) return;
    final a = account(customerId);
    final e = LedgerEntry.opening(id: _id(), customerId: customerId, paise: amount, at: at, by: currentUser);
    final no = 'OPEN-$customerId';
    _put(customerId, a.copyWith(ledger: [...a.ledger, e], bills: amount > 0 ? [...a.bills, BillDue(billNo: no, date: at, totalPaise: amount, paidPaise: 0)] : a.bills));
  }

  /// Fixes a wrong entry with a NEW entry (the wrong one stays visible). Puts money back on the bills it was applied to.
  /// Throws when the entry cannot be reversed or already was.
  void reverseEntry({required String partyId, required String entryId, required String reason, required DateTime at}) {
    final a = account(partyId);
    final orig = a.ledger.firstWhere((e) => e.id == entryId);
    if (reversedIds(a.ledger).contains(entryId)) throw StateError('already reversed');
    final rev = LedgerEntry.reversal(id: _id(), customerId: partyId, original: orig, at: at, reason: reason, by: currentUser);
    var bills = a.bills;
    switch (orig.kind) {
      case LedgerKind.payment || LedgerKind.writeOff:
        bills = restoreAllocations(bills, orig.allocations);
      case LedgerKind.manualCredit || LedgerKind.opening:
        bills = [for (final b in bills) b.billNo == (orig.billNo ?? 'OPEN-$partyId') ? b.cancel() : b];
      case LedgerKind.adjustment:
        bills = orig.amountPaise > 0 ? [for (final b in bills) b.billNo == orig.billNo ? b.cancel() : b] : restoreAllocations(bills, orig.allocations);
      default:
    }
    _put(partyId, a.copyWith(ledger: [...a.ledger, rev], bills: bills));
  }

  /// Owner only. Cannot write off more than is owed.
  void writeOff({required String customerId, required int amount, required String reason, required DateTime at}) {
    final a = account(customerId);
    if (amount > maxWriteOff(a.ledger)) throw StateError('cannot write off more than is owed');
    // the written-off money is taken off the oldest bills too, so bill-wise dues and the ledger stay equal
    final res = allocatePayment(bills: a.bills, amount: amount);
    final entry = LedgerEntry.writeOff(id: _id(), customerId: customerId, paise: amount, at: at, reason: reason, by: currentUser, allocations: res.allocations);
    _put(customerId, a.copyWith(ledger: [...a.ledger, entry], bills: applyAllocations(a.bills, res.allocations)));
  }

  /// Called when a bill (or a purchase) is saved. [balance] goes on the account; [advance] is kept on account.
  void addBill({required String customerId, required String billNo, required DateTime at, required int total, required int received, int advance = 0}) {
    final split = splitPayment(total: total, received: received);
    final a = account(customerId);
    final ledger = [...a.ledger];
    var bills = [...a.bills];
    if (split.balance > 0) {
      ledger.add(LedgerEntry.billCredit(id: _id(), customerId: customerId, paise: split.balance, at: at, billNo: billNo, by: currentUser));
      bills.add(BillDue(billNo: billNo, date: at, totalPaise: total, paidPaise: total - split.balance));
    }
    if (advance > 0) {
      ledger.add(LedgerEntry.advance(id: _id(), customerId: customerId, paise: advance, at: at, billNo: billNo, by: currentUser, note: 'Extra money kept as advance'));
    }
    if (ledger.length != a.ledger.length) _put(customerId, a.copyWith(ledger: ledger, bills: bills));
  }
}

class CreditNotifier extends PartyLedgerNotifier {
  @override
  String get receiptPrefix => 'RCP';

  @override
  Map<String, CreditAccount> build() => seedCredit(ref.read(customersProvider), ref.watch(clockProvider));

  int get totalToCollect => state.values.fold<int>(0, (s, a) => a.balance > 0 ? s + a.balance : s);
  int get totalAdvances => state.values.fold<int>(0, (s, a) => a.balance < 0 ? s - a.balance : s);

  /// A bill was cancelled (owner, with a reason): its credit is reversed. Does nothing for bills that never added credit.
  void cancelBill({required String billNo, required String reason, required DateTime at}) {
    for (final e in state.entries) {
      final hasCredit = e.value.ledger.any((x) => x.billNo == billNo && x.kind == LedgerKind.billCredit);
      if (!hasCredit) continue;
      if (e.value.bills.any((b) => b.billNo == billNo && b.cancelled)) return; // already cancelled
      final rev = reverseBillCredit(entries: e.value.ledger, customerId: e.key, billNo: billNo, at: at, reason: reason, by: currentUser, entryId: _id());
      _put(e.key, e.value.copyWith(ledger: [...e.value.ledger, rev], bills: [for (final b in e.value.bills) b.billNo == billNo ? b.cancel() : b]));
      return;
    }
  }
}

final creditProvider = NotifierProvider<CreditNotifier, Map<String, CreditAccount>>(CreditNotifier.new);

/// What we owe each dealer: purchases on credit, payments to the dealer, returns and adjustments (same rules as customers).
class DealerLedgerNotifier extends PartyLedgerNotifier {
  @override
  String get receiptPrefix => 'PAY';

  @override
  Map<String, CreditAccount> build() {
    final dealers = ref.read(recsProvider('dealers'));
    return seedCredit([for (final d in dealers) Customer(id: d.id, name: d.s('name'), phone: d.s('phone'), city: d.s('city'), balancePaise: d.i('balance'))], ref.read(clockProvider), billPrefix: 'PUR-0', billBase: 15000, seed: 2031);
  }

  int get totalWeOwe => state.values.fold<int>(0, (s, a) => a.balance > 0 ? s + a.balance : s);
}

final dealerLedgerProvider = NotifierProvider<DealerLedgerNotifier, Map<String, CreditAccount>>(DealerLedgerNotifier.new);

/// The account book for a kind of party (for screens that serve both customers and dealers).
Map<String, CreditAccount> watchBook(WidgetRef ref, PartyKind k) => k == PartyKind.customer ? ref.watch(creditProvider) : ref.watch(dealerLedgerProvider);
PartyLedgerNotifier bookOf(WidgetRef ref, PartyKind k) => k == PartyKind.customer ? ref.read(creditProvider.notifier) : ref.read(dealerLedgerProvider.notifier);

class ReminderLogNotifier extends Notifier<ReminderLog> {
  @override
  ReminderLog build() => seedReminders(ref.read(creditProvider), ref.watch(clockProvider));
  int _n = 500;

  ReminderRecord record({required String customerId, required int amountDue, required String message, required DateTime at}) {
    final r = ReminderRecord(id: 'rm${_n++}', customerId: customerId, at: at, amountDuePaise: amountDue, message: message, by: currentUser);
    state = state.add(r);
    return r;
  }

  void undo(String id) => state = state.undo(id);
}

final reminderLogProvider = NotifierProvider<ReminderLogNotifier, ReminderLog>(ReminderLogNotifier.new);

// ------------------------------------------------------------------ fake data

/// Realistic credit data for the customers who have a balance: bills part-paid at the counter, later part payments,
/// old overdue bills, an opening balance for a few, and advances for some. Deterministic.
Map<String, CreditAccount> seedCredit(List<Customer> customers, DateTime now, {String billPrefix = 'A-0', int billBase = 19000, int seed = 2027}) {
  final r = Random(seed);
  final out = <String, CreditAccount>{};
  var seq = 1;
  String id() => 'seed${seq++}';
  for (final c in customers) {
    if (c.balancePaise == 0) continue;
    if (c.balancePaise < 0) {
      out[c.id] = CreditAccount(ledger: [LedgerEntry.advance(id: id(), customerId: c.id, paise: -c.balancePaise, at: now.subtract(Duration(days: 3 + r.nextInt(40))), note: 'Paid more than was due', by: 'Priya')]);
      continue;
    }
    var left = c.balancePaise;
    final ledger = <LedgerEntry>[];
    final bills = <BillDue>[];
    if (left > 300000 && r.nextInt(100) < 25) {
      final open = 100000 + r.nextInt(200000);
      ledger.add(LedgerEntry.opening(id: id(), customerId: c.id, paise: open, at: now.subtract(const Duration(days: 400)), by: 'Owner'));
      left -= open;
    }
    final n = left < 20000 ? 1 : 1 + r.nextInt(min(4, left ~/ 10000));
    var age = 4 + r.nextInt(40);
    for (var i = 0; i < n; i++) {
      final outstanding = i == n - 1 ? left : min(left - (n - 1 - i), max(1000, (left * (20 + r.nextInt(50)) ~/ 100)));
      left -= outstanding;
      final paidLater = r.nextInt(100) < 35 ? (outstanding * (10 + r.nextInt(40)) ~/ 100) : 0;
      final atCounter = r.nextInt(100) < 50 ? 5000 + r.nextInt(100000) : 0;
      final credit = outstanding + paidLater;
      final total = credit + atCounter;
      final date = DateTime(now.year, now.month, now.day, 10 + r.nextInt(8), r.nextInt(60)).subtract(Duration(days: age));
      final no = '$billPrefix${billBase + r.nextInt(900)}';
      ledger.add(LedgerEntry.billCredit(id: id(), customerId: c.id, paise: credit, at: date, billNo: no, by: 'Priya'));
      if (paidLater > 0) ledger.add(LedgerEntry.payment(id: id(), customerId: c.id, paise: paidLater, at: date.add(Duration(days: 2 + r.nextInt(8))), mode: r.nextBool() ? 'cash' : 'upi', by: 'Priya'));
      bills.add(BillDue(billNo: no, date: date, totalPaise: total, paidPaise: total - outstanding));
      age += 8 + r.nextInt(50);
    }
    ledger.sort((a, b) => a.at.compareTo(b.at));
    out[c.id] = CreditAccount(ledger: ledger, bills: bills);
  }
  return out;
}

ReminderLog seedReminders(Map<String, CreditAccount> credit, DateTime now) {
  final r = Random(2028);
  var log = const ReminderLog();
  var n = 1;
  for (final e in credit.entries) {
    if (e.value.balance <= 0 || r.nextInt(100) >= 22) continue;
    final times = 1 + r.nextInt(4);
    for (var i = 0; i < times; i++) {
      final ago = i == 0 && r.nextInt(100) < 25 ? Duration(hours: 1 + r.nextInt(20)) : Duration(days: 2 + i * 9 + r.nextInt(6), hours: r.nextInt(10));
      log = log.add(ReminderRecord(id: 'seedrm${n++}', customerId: e.key, at: now.subtract(ago), amountDuePaise: e.value.balance, message: 'Hello, a gentle reminder about your pending amount.', by: 'Owner'));
    }
  }
  return log;
}
