/// Sample credit data for the demo (pure Dart): customers with part-paid bills, later payments, old overdue bills, opening balances
/// and advances. Deterministic.
library;

import 'dart:math';
import '../domain/credit/account.dart';
import '../domain/credit/dues.dart';
import '../domain/credit/ledger.dart';
import '../domain/credit/reminder.dart';
import '../domain/models.dart';

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
