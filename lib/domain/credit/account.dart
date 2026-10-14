/// The shape of one person-account (customer or dealer): its ledger and its bill-wise dues. Pure Dart.
library;

import 'dues.dart';
import 'ledger.dart';

/// Whose account: a customer (they owe us) or a dealer (we owe them). Both use the same ledger rules.
enum PartyKind { customer, dealer }

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

  /// The latest payment (not an advance) with its date and amount.
  LedgerEntry? get lastPayment => _latest(const {LedgerKind.payment, LedgerKind.advance}, skipReversed: true);

  /// The latest credit added (a bill's unpaid part, manual credit or an opening balance).
  LedgerEntry? get lastCredit => _latest(const {LedgerKind.billCredit, LedgerKind.manualCredit, LedgerKind.opening}, skipReversed: true);

  LedgerEntry? _latest(Set<LedgerKind> kinds, {bool skipReversed = false}) {
    final gone = skipReversed ? reversedIds(ledger) : const <String>{};
    LedgerEntry? best;
    for (final e in ledger) {
      if (!kinds.contains(e.kind) || gone.contains(e.id) || e.amountPaise == 0) continue;
      if (best == null || e.at.isAfter(best.at)) best = e;
    }
    return best;
  }

  /// The date the oldest unpaid bill was made: when this credit started (null when nothing is owed).
  DateTime? get creditStart {
    final u = unpaidBills(bills);
    return u.isEmpty ? null : u.first.date;
  }

  /// When the oldest unpaid bill falls due ([termDays] after it was made); it is overdue when this is in the past.
  DateTime? nextDue({int termDays = 30}) {
    final s = creditStart;
    return s == null ? null : DateTime(s.year, s.month, s.day).add(Duration(days: termDays));
  }

  CreditAccount copyWith({List<LedgerEntry>? ledger, List<BillDue>? bills}) => CreditAccount(ledger: ledger ?? this.ledger, bills: bills ?? this.bills);
}

/// A payment receipt (printable): what came in and where it went.
class PaymentReceipt {
  const PaymentReceipt({this.id = '', required this.number, required this.customerId, required this.customerName, required this.amountPaise, required this.mode, required this.at, required this.note, required this.allocations, required this.advancePaise, required this.balanceAfter});
  /// The id of the payment record (empty for a sample receipt); used to undo it in the first seconds.
  final String id;
  final String number, customerId, customerName, mode, note;
  final int amountPaise, advancePaise, balanceAfter;
  final DateTime at;
  final List<Allocation> allocations;
}
