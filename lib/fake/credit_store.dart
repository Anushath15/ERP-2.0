/// Prototype state for customer credit (Phase 1: in memory, fake data). The rules live in lib/domain/credit (pure Dart, tested);
/// this file only holds the data and calls those rules. Phase 2 stores the same entries in the database (docs/data-model.md).
library;

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/credit/dues.dart';
import '../domain/credit/ledger.dart';
import '../domain/credit/payment_split.dart';
import '../domain/credit/reminder.dart';
import 'models.dart';
import 'store.dart';

const currentUser = 'Owner';

class CreditAccount {
  const CreditAccount({this.ledger = const [], this.bills = const []});
  final List<LedgerEntry> ledger;
  final List<BillDue> bills;

  /// Positive = the customer owes us ("Money to collect"); negative = we hold their advance.
  int get balance => ledgerBalance(ledger);
  int get unbilledBalance => balance - bills.fold<int>(0, (s, b) => s + b.outstanding); // e.g. an opening balance
  DateTime? get lastPaymentAt {
    DateTime? last;
    for (final e in ledger) {
      if ((e.kind == LedgerKind.payment || e.kind == LedgerKind.advance) && (last == null || e.at.isAfter(last))) last = e.at;
    }
    return last;
  }

  CreditAccount copyWith({List<LedgerEntry>? ledger, List<BillDue>? bills}) => CreditAccount(ledger: ledger ?? this.ledger, bills: bills ?? this.bills);
}

/// A payment receipt (printable): what came in and where it went.
class PaymentReceipt {
  const PaymentReceipt({required this.number, required this.customerId, required this.customerName, required this.amountPaise, required this.mode, required this.at, required this.note, required this.allocations, required this.advancePaise, required this.balanceAfter});
  final String number, customerId, customerName, mode, note;
  final int amountPaise, advancePaise, balanceAfter;
  final DateTime at;
  final List<Allocation> allocations;
}

class CreditNotifier extends Notifier<Map<String, CreditAccount>> {
  int _seq = 1000;
  int _rcp = 40;

  @override
  Map<String, CreditAccount> build() => seedCredit(ref.watch(customersProvider), ref.watch(clockProvider));

  CreditAccount account(String customerId) => state[customerId] ?? const CreditAccount();
  int balanceOf(String customerId) => account(customerId).balance;
  int get totalToCollect => state.values.fold<int>(0, (s, a) => a.balance > 0 ? s + a.balance : s);
  int get totalAdvances => state.values.fold<int>(0, (s, a) => a.balance < 0 ? s - a.balance : s);

  String _id() => 'le${_seq++}';

  void _put(String cid, CreditAccount a) => state = {...state, cid: a};

  /// Called when a bill is saved. [balance] goes to credit; [advance] (if the customer chose "keep as advance") is kept on account.
  /// Returns the credit added.
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

  /// Receive a payment: applied to the oldest unpaid bills (or only [onlyBills]); any rest becomes an advance.
  PaymentReceipt receivePayment({required String customerId, required String customerName, required int amount, required String mode, required DateTime at, String note = '', Set<String>? onlyBills}) {
    final a = account(customerId);
    final res = allocatePayment(bills: a.bills, amount: amount, onlyBills: onlyBills);
    final ledger = [...a.ledger];
    if (res.appliedPaise > 0) {
      ledger.add(LedgerEntry.payment(id: _id(), customerId: customerId, paise: res.appliedPaise, at: at, mode: mode, note: note, by: currentUser));
    }
    if (res.advancePaise > 0) {
      ledger.add(LedgerEntry.advance(id: _id(), customerId: customerId, paise: res.advancePaise, at: at, mode: mode, note: note.isEmpty ? 'Paid more than was due' : note, by: currentUser));
    }
    final updated = a.copyWith(ledger: ledger, bills: applyAllocations(a.bills, res.allocations));
    _put(customerId, updated);
    return PaymentReceipt(number: 'RCP-${(_rcp++).toString().padLeft(4, '0')}', customerId: customerId, customerName: customerName, amountPaise: amount, mode: mode, at: at, note: note, allocations: res.allocations, advancePaise: res.advancePaise, balanceAfter: updated.balance);
  }

  /// Owner only. Cannot write off more than is owed.
  void writeOff({required String customerId, required int amount, required String reason, required DateTime at}) {
    final a = account(customerId);
    if (amount > maxWriteOff(a.ledger)) throw StateError('cannot write off more than is owed');
    // the written-off money is taken off the oldest bills too, so bill-wise dues and the ledger stay equal
    final res = allocatePayment(bills: a.bills, amount: amount);
    final entry = LedgerEntry.writeOff(id: _id(), customerId: customerId, paise: amount, at: at, reason: reason, by: currentUser);
    _put(customerId, a.copyWith(ledger: [...a.ledger, entry], bills: applyAllocations(a.bills, res.allocations)));
  }

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

class ReminderLogNotifier extends Notifier<ReminderLog> {
  @override
  ReminderLog build() => seedReminders(ref.watch(creditProvider), ref.watch(clockProvider));
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
Map<String, CreditAccount> seedCredit(List<Customer> customers, DateTime now) {
  final r = Random(2027);
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
      final no = 'A-0${19000 + r.nextInt(900)}';
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
