/// Pure Dart: bill-wise dues, payment allocation, ageing and the customer statement.
library;

import 'ledger.dart';

export 'ledger.dart' show Allocation;

class BillDue {
  const BillDue({required this.billNo, required this.date, required this.totalPaise, required this.paidPaise, this.cancelled = false});
  final String billNo;
  final DateTime date;
  final int totalPaise, paidPaise;
  final bool cancelled;

  /// Still to collect on this bill (0 when settled or cancelled).
  int get outstanding => cancelled ? 0 : (totalPaise - paidPaise).clamp(0, totalPaise);

  BillDue paid(int more) => BillDue(billNo: billNo, date: date, totalPaise: totalPaise, paidPaise: paidPaise + more, cancelled: cancelled);
  BillDue cancel() => BillDue(billNo: billNo, date: date, totalPaise: totalPaise, paidPaise: paidPaise, cancelled: true);
}

class AllocationResult {
  const AllocationResult(this.allocations, this.advancePaise);
  final List<Allocation> allocations;

  /// Money left after settling everything chosen: kept on account as an advance.
  final int advancePaise;
  int get appliedPaise => allocations.fold<int>(0, (s, a) => s + a.paise);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Oldest bill first (by date, then bill number).
int _oldestFirst(BillDue a, BillDue b) {
  final c = _day(a.date).compareTo(_day(b.date));
  return c != 0 ? c : a.billNo.compareTo(b.billNo);
}

/// Applies a payment to the OLDEST unpaid bills first. With [onlyBills] the person chose which bills to settle: only those
/// are used (still oldest first among them). Whatever is left over becomes an advance. Invariant (property-tested):
/// `applied + advance == amount`, and no bill receives more than it still owes.
AllocationResult allocatePayment({required List<BillDue> bills, required int amount, Set<String>? onlyBills}) {
  if (amount <= 0) throw ArgumentError.value(amount, 'amount', 'must be above zero');
  final open = [for (final b in bills) if (b.outstanding > 0 && (onlyBills == null || onlyBills.contains(b.billNo))) b]..sort(_oldestFirst);
  var left = amount;
  final out = <Allocation>[];
  for (final b in open) {
    if (left == 0) break;
    final take = left < b.outstanding ? left : b.outstanding;
    out.add(Allocation(b.billNo, take));
    left -= take;
  }
  return AllocationResult(out, left);
}

/// Returns the bills with the allocations added to what they have paid.
List<BillDue> applyAllocations(List<BillDue> bills, List<Allocation> allocations) {
  final by = {for (final a in allocations) a.billNo: a.paise};
  return [for (final b in bills) by.containsKey(b.billNo) ? b.paid(by[b.billNo]!) : b];
}

/// The exact inverse of [applyAllocations]: takes the allocated money off the bills again (used when a payment is reversed).
List<BillDue> restoreAllocations(List<BillDue> bills, List<Allocation> allocations) {
  final by = {for (final a in allocations) a.billNo: a.paise};
  return [for (final b in bills) by.containsKey(b.billNo) ? b.paid(-by[b.billNo]!) : b];
}

class AgeingBuckets {
  const AgeingBuckets({this.d0to30 = 0, this.d31to60 = 0, this.d61to90 = 0, this.d90plus = 0});
  final int d0to30, d31to60, d61to90, d90plus;
  int get total => d0to30 + d31to60 + d61to90 + d90plus;
}

/// Whole days between the bill date and [today] (calendar days, never negative).
int daysOld(DateTime billDate, DateTime today) {
  final d = _day(today).difference(_day(billDate)).inDays;
  return d < 0 ? 0 : d;
}

/// Splits what is outstanding into 0-30, 31-60, 61-90 and 90+ days old.
AgeingBuckets ageing(Iterable<BillDue> bills, DateTime today) {
  var a = 0, b = 0, c = 0, d = 0;
  for (final x in bills) {
    final o = x.outstanding;
    if (o == 0) continue;
    final days = daysOld(x.date, today);
    if (days <= 30) {
      a += o;
    } else if (days <= 60) {
      b += o;
    } else if (days <= 90) {
      c += o;
    } else {
      d += o;
    }
  }
  return AgeingBuckets(d0to30: a, d31to60: b, d61to90: c, d90plus: d);
}

/// What is overdue: outstanding on bills older than [termDays] (default 30).
int overdueAmount(Iterable<BillDue> bills, DateTime today, {int termDays = 30}) =>
    bills.where((b) => daysOld(b.date, today) > termDays).fold<int>(0, (s, b) => s + b.outstanding);

/// Bills that still have something to pay, oldest first.
List<BillDue> unpaidBills(Iterable<BillDue> bills) => [for (final b in bills) if (b.outstanding > 0) b]..sort(_oldestFirst);

/// Age in days of the oldest unpaid bill, or null when nothing is owed.
int? oldestUnpaidDays(Iterable<BillDue> bills, DateTime today) {
  final u = unpaidBills(bills);
  return u.isEmpty ? null : daysOld(u.first.date, today);
}

// ---------------------------------------------------------------- statement

class StatementLine {
  const StatementLine(this.at, this.kind, this.billNo, this.note, this.chargePaise, this.creditPaise, this.runningPaise);
  final DateTime at;
  final LedgerKind kind;
  final String? billNo;
  final String note;
  final int chargePaise; // adds to what they owe
  final int creditPaise; // reduces it
  final int runningPaise;
}

class Statement {
  const Statement({required this.from, required this.to, required this.openingPaise, required this.lines, required this.closingPaise});
  final DateTime from, to;
  final int openingPaise;
  final List<StatementLine> lines;
  final int closingPaise;
  int get totalCharges => lines.fold<int>(0, (s, l) => s + l.chargePaise);
  int get totalCredits => lines.fold<int>(0, (s, l) => s + l.creditPaise);
}

/// Statement for [from]..[to] (inclusive days). Invariant: `opening + charges - credits == closing`.
Statement buildStatement({required List<LedgerEntry> entries, required DateTime from, required DateTime to}) {
  final f = _day(from), t = _day(to).add(const Duration(days: 1));
  final lines = withRunningBalance(entries);
  var opening = 0;
  final out = <StatementLine>[];
  var closing = 0;
  for (final l in lines) {
    final e = l.entry;
    if (e.at.isBefore(f)) {
      opening = l.runningPaise;
      closing = l.runningPaise;
    } else if (e.at.isBefore(t)) {
      out.add(StatementLine(e.at, e.kind, e.billNo, e.note, e.amountPaise > 0 ? e.amountPaise : 0, e.amountPaise < 0 ? -e.amountPaise : 0, l.runningPaise));
      closing = l.runningPaise;
    }
  }
  return Statement(from: f, to: _day(to), openingPaise: opening, lines: out, closingPaise: closing);
}
