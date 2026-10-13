import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/domain/credit/dues.dart';
import 'package:erp2/domain/credit/ledger.dart';
import 'package:erp2/domain/credit/payment_split.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

/// A random non-negative integer up to about 2^40 (Random.nextInt itself stops at 2^32).
int big(Random r) => (r.nextInt(1 << 30) << 10) | r.nextInt(1 << 10);

void main() {
  group('splitPayment', () {
    test('the owner example: bill 150, customer gives 100, 50 goes to credit', () {
      final s = splitPayment(total: 15000, received: 10000);
      expect(s.balance, 5000);
      expect(s.change, 0);
      expect(s.isPartPaid, true);
    });

    test('exact payment, zero payment, overpayment', () {
      expect(splitPayment(total: 15000, received: 15000).isFullyPaid, true);
      final none = splitPayment(total: 15000, received: 0);
      expect(none.isUnpaid, true);
      expect(none.balance, 15000);
      final over = splitPayment(total: 15000, received: 20000);
      expect(over.change, 5000);
      expect(over.balance, 0);
      expect(over.settled, 15000);
    });

    test('1 paisa edges and zero total', () {
      expect(splitPayment(total: 1, received: 0).balance, 1);
      expect(splitPayment(total: 1, received: 1).balance, 0);
      expect(splitPayment(total: 1, received: 2).change, 1);
      expect(splitPayment(total: 0, received: 0).isFullyPaid, true);
      expect(splitPayment(total: 0, received: 5).change, 5);
    });

    test('huge values stay exact (integers)', () {
      const big = 9000000000000000; // 90 trillion rupees in paise
      final s = splitPayment(total: big, received: big - 1);
      expect(s.balance, 1);
      expect(s.settled + s.balance, big);
    });

    test('rejects negative money', () {
      expect(() => splitPayment(total: -1, received: 0), throwsArgumentError);
      expect(() => splitPayment(total: 1, received: -1), throwsArgumentError);
    });

    test('property: settled + balance = total, received = settled + change, only one of balance/change is above zero (20,000 random cases)', () {
      final r = Random(1);
      for (var i = 0; i < 20000; i++) {
        final total = big(r);
        final received = r.nextBool() ? big(r) : (total + r.nextInt(3) - 1).clamp(0, 1 << 41);
        final s = splitPayment(total: total, received: received);
        expect(s.settled + s.balance, total);
        expect(s.settled + s.change, received);
        expect(s.balance >= 0 && s.change >= 0, true);
        expect(s.balance == 0 || s.change == 0, true);
      }
    });
  });

  group('parseRupeesToPaise (typed amounts, no floating point)', () {
    test('valid inputs', () {
      expect(parseRupeesToPaise('150'), 15000);
      expect(parseRupeesToPaise('150.5'), 15050);
      expect(parseRupeesToPaise('150.50'), 15050);
      expect(parseRupeesToPaise('0.07'), 7);
      expect(parseRupeesToPaise('.5'), 50);
      expect(parseRupeesToPaise('1,250.75'), 125075);
      expect(parseRupeesToPaise('₹ 99'), 9900);
      expect(parseRupeesToPaise('0'), 0);
      expect(parseRupeesToPaise('19.99'), 1999, reason: 'a double would give 1998.9999...');
      expect(parseRupeesToPaise('1.15'), 115);
    });
    test('rejects nonsense', () {
      for (final s in ['', ' ', 'abc', '1.2.3', '12.345', '-5', '5-', '1e5', '.', '₹', '9999999999999999999']) {
        expect(parseRupeesToPaise(s), isNull, reason: s);
      }
    });
    test('property: every amount in paise round-trips through text', () {
      final r = Random(2);
      for (var i = 0; i < 5000; i++) {
        final p = big(r);
        final text = '${p ~/ 100}.${(p % 100).toString().padLeft(2, '0')}';
        expect(parseRupeesToPaise(text), p);
      }
    });
  });

  group('ledger', () {
    LedgerEntry bill(String id, int paise, DateTime at, String no) => LedgerEntry.billCredit(id: id, customerId: 'c1', paise: paise, at: at, billNo: no);
    LedgerEntry pay(String id, int paise, DateTime at) => LedgerEntry.payment(id: id, customerId: 'c1', paise: paise, at: at);

    test('balance is the sum of entries; sign rules are forced by the factories', () {
      final e = [
        LedgerEntry.opening(id: 'o', customerId: 'c1', paise: 100000, at: d(2026, 1, 1)),
        bill('1', 5000, d(2026, 2, 1), 'A-1'),
        pay('2', 30000, d(2026, 2, 5)),
        LedgerEntry.returnCredit(id: '3', customerId: 'c1', paise: 1000, at: d(2026, 2, 6), billNo: 'A-1'),
        LedgerEntry.adjustment(id: '4', customerId: 'c1', signedPaise: 250, at: d(2026, 2, 7), reason: 'rounding'),
        LedgerEntry.writeOff(id: '5', customerId: 'c1', paise: 500, at: d(2026, 2, 8), reason: 'small', by: 'owner'),
      ];
      expect(ledgerBalance(e), 100000 + 5000 - 30000 - 1000 + 250 - 500);
      expect(e[2].amountPaise, -30000, reason: 'a payment is stored as a reduction');
    });

    test('advance makes the balance negative', () {
      final e = [bill('1', 5000, d(2026, 2, 1), 'A-1'), pay('2', 5000, d(2026, 2, 2)), LedgerEntry.advance(id: '3', customerId: 'c1', paise: 700, at: d(2026, 2, 2))];
      expect(ledgerBalance(e), -700);
    });

    test('rules: no zero or negative inputs, reasons are required', () {
      expect(() => LedgerEntry.billCredit(id: 'x', customerId: 'c', paise: 0, at: d(2026, 1, 1), billNo: 'A'), throwsArgumentError);
      expect(() => LedgerEntry.payment(id: 'x', customerId: 'c', paise: -5, at: d(2026, 1, 1)), throwsArgumentError);
      expect(() => LedgerEntry.adjustment(id: 'x', customerId: 'c', signedPaise: 0, at: d(2026, 1, 1), reason: 'r'), throwsArgumentError);
      expect(() => LedgerEntry.adjustment(id: 'x', customerId: 'c', signedPaise: 5, at: d(2026, 1, 1), reason: '  '), throwsArgumentError);
      expect(() => LedgerEntry.writeOff(id: 'x', customerId: 'c', paise: 5, at: d(2026, 1, 1), reason: '', by: 'owner'), throwsArgumentError);
    });

    test('running balance follows date order and ends at the balance', () {
      final e = [pay('2', 3000, d(2026, 3, 2)), bill('1', 10000, d(2026, 3, 1), 'A-1'), bill('3', 500, d(2026, 3, 3), 'A-2')];
      final lines = withRunningBalance(e);
      expect(lines.map((l) => l.runningPaise).toList(), [10000, 7000, 7500]);
      expect(lines.last.runningPaise, ledgerBalance(e));
    });

    test('write-off can never exceed what is owed', () {
      expect(maxWriteOff([bill('1', 5000, d(2026, 1, 1), 'A-1')]), 5000);
      expect(maxWriteOff([LedgerEntry.advance(id: 'a', customerId: 'c1', paise: 900, at: d(2026, 1, 1))]), 0);
    });

    test('cancelling a bill reverses exactly its credit, once', () {
      final e = [bill('1', 5000, d(2026, 2, 1), 'A-1'), bill('2', 3000, d(2026, 2, 2), 'A-2')];
      final rev = reverseBillCredit(entries: e, customerId: 'c1', billNo: 'A-1', at: d(2026, 2, 3), reason: 'wrong customer', by: 'owner', entryId: 'r1');
      expect(rev.amountPaise, -5000);
      expect(rev.kind, LedgerKind.billCancel);
      final after = [...e, rev];
      expect(ledgerBalance(after), 3000);
      expect(() => reverseBillCredit(entries: after, customerId: 'c1', billNo: 'A-1', at: d(2026, 2, 4), reason: 'again', by: 'owner', entryId: 'r2'), throwsStateError);
      expect(() => reverseBillCredit(entries: e, customerId: 'c1', billNo: 'A-9', at: d(2026, 2, 4), reason: 'x', by: 'owner', entryId: 'r3'), throwsStateError);
      expect(() => reverseBillCredit(entries: e, customerId: 'c1', billNo: 'A-2', at: d(2026, 2, 4), reason: '', by: 'owner', entryId: 'r4'), throwsArgumentError);
    });

    test('cancelling a bill that was partly paid later leaves an advance (nothing is lost)', () {
      final e = [bill('1', 5000, d(2026, 2, 1), 'A-1'), pay('2', 2000, d(2026, 2, 5))];
      final rev = reverseBillCredit(entries: e, customerId: 'c1', billNo: 'A-1', at: d(2026, 2, 6), reason: 'returned', by: 'owner', entryId: 'r');
      expect(ledgerBalance([...e, rev]), -2000, reason: 'the 2,000 they paid is now an advance');
    });
  });

  group('allocatePayment', () {
    final bills = [
      BillDue(billNo: 'A-3', date: d(2026, 3, 1), totalPaise: 3000, paidPaise: 0),
      BillDue(billNo: 'A-1', date: d(2026, 1, 1), totalPaise: 10000, paidPaise: 2000), // 8000 left
      BillDue(billNo: 'A-2', date: d(2026, 2, 1), totalPaise: 5000, paidPaise: 5000), // settled
    ];

    test('oldest unpaid bill is settled first, settled bills are skipped', () {
      final r = allocatePayment(bills: bills, amount: 9000);
      expect(r.allocations.map((a) => '${a.billNo}:${a.paise}').toList(), ['A-1:8000', 'A-3:1000']);
      expect(r.advancePaise, 0);
    });

    test('part payment stays inside the oldest bill', () {
      final r = allocatePayment(bills: bills, amount: 500);
      expect(r.allocations.single.billNo, 'A-1');
      expect(r.allocations.single.paise, 500);
    });

    test('paying more than the dues makes an advance', () {
      final r = allocatePayment(bills: bills, amount: 12000);
      expect(r.appliedPaise, 11000);
      expect(r.advancePaise, 1000);
    });

    test('manual choice: only the chosen bills are used, leftover is an advance', () {
      final r = allocatePayment(bills: bills, amount: 4000, onlyBills: {'A-3'});
      expect(r.allocations.single.billNo, 'A-3');
      expect(r.allocations.single.paise, 3000);
      expect(r.advancePaise, 1000);
    });

    test('same-day bills are settled in bill-number order', () {
      final r = allocatePayment(bills: [BillDue(billNo: 'A-9', date: d(2026, 1, 1), totalPaise: 100, paidPaise: 0), BillDue(billNo: 'A-2', date: d(2026, 1, 1), totalPaise: 100, paidPaise: 0)], amount: 150);
      expect(r.allocations.map((a) => a.billNo).toList(), ['A-2', 'A-9']);
    });

    test('no dues at all: the whole payment is an advance; zero or negative is refused', () {
      final r = allocatePayment(bills: [BillDue(billNo: 'A-1', date: d(2026, 1, 1), totalPaise: 100, paidPaise: 100)], amount: 700);
      expect(r.allocations, isEmpty);
      expect(r.advancePaise, 700);
      expect(() => allocatePayment(bills: bills, amount: 0), throwsArgumentError);
    });

    test('cancelled bills are never allocated to', () {
      final r = allocatePayment(bills: [BillDue(billNo: 'A-1', date: d(2026, 1, 1), totalPaise: 100, paidPaise: 0).cancel()], amount: 50);
      expect(r.allocations, isEmpty);
      expect(r.advancePaise, 50);
    });

    test('property: applied + advance = amount; nobody is paid more than they owe; outstanding drops by exactly the applied amount (5,000 random cases)', () {
      final r = Random(3);
      for (var i = 0; i < 5000; i++) {
        final n = 1 + r.nextInt(8);
        final list = [
          for (var k = 0; k < n; k++)
            () {
              final total = 100 + r.nextInt(500000);
              return BillDue(billNo: 'A-${r.nextInt(99999)}-$k', date: d(2026, 1 + r.nextInt(9), 1 + r.nextInt(27)), totalPaise: total, paidPaise: r.nextInt(total + 1));
            }()
        ];
        final amount = 1 + r.nextInt(1500000);
        final res = allocatePayment(bills: list, amount: amount);
        expect(res.appliedPaise + res.advancePaise, amount);
        final byNo = {for (final b in list) b.billNo: b};
        for (final a in res.allocations) {
          expect(a.paise, greaterThan(0));
          expect(a.paise <= byNo[a.billNo]!.outstanding, true);
        }
        final before = list.fold<int>(0, (s, b) => s + b.outstanding);
        final after = applyAllocations(list, res.allocations).fold<int>(0, (s, b) => s + b.outstanding);
        expect(before - after, res.appliedPaise);
        // oldest first: a newer bill gets money only if every older unpaid bill is fully settled
        final sorted = [...list]..sort((a, b) => a.date != b.date ? a.date.compareTo(b.date) : a.billNo.compareTo(b.billNo));
        var sawPartial = false;
        for (final b in sorted.where((b) => b.outstanding > 0)) {
          final got = res.allocations.where((a) => a.billNo == b.billNo).fold<int>(0, (s, a) => s + a.paise);
          if (sawPartial) expect(got, 0, reason: 'money went to a newer bill while an older one was not settled');
          if (got < b.outstanding) sawPartial = true;
        }
      }
    });
  });

  group('ageing', () {
    final today = d(2026, 10, 13);
    test('buckets 0-30, 31-60, 61-90, 90+ by calendar days', () {
      final bills = [
        BillDue(billNo: 'a', date: d(2026, 10, 13), totalPaise: 100, paidPaise: 0), // 0 days
        BillDue(billNo: 'b', date: d(2026, 9, 13), totalPaise: 200, paidPaise: 0), // 30
        BillDue(billNo: 'c', date: d(2026, 9, 12), totalPaise: 400, paidPaise: 0), // 31
        BillDue(billNo: 'd', date: d(2026, 8, 14), totalPaise: 800, paidPaise: 0), // 60
        BillDue(billNo: 'e', date: d(2026, 8, 13), totalPaise: 1600, paidPaise: 0), // 61
        BillDue(billNo: 'f', date: d(2026, 7, 15), totalPaise: 3200, paidPaise: 0), // 90
        BillDue(billNo: 'g', date: d(2026, 7, 14), totalPaise: 6400, paidPaise: 0), // 91
      ];
      final a = ageing(bills, today);
      expect(a.d0to30, 300);
      expect(a.d31to60, 1200);
      expect(a.d61to90, 4800);
      expect(a.d90plus, 6400);
      expect(a.total, 12700);
    });
    test('ageing uses what is still outstanding and ignores settled and cancelled bills; total equals the dues', () {
      final bills = [
        BillDue(billNo: 'a', date: d(2026, 6, 1), totalPaise: 1000, paidPaise: 400),
        BillDue(billNo: 'b', date: d(2026, 6, 1), totalPaise: 1000, paidPaise: 1000),
        BillDue(billNo: 'c', date: d(2026, 6, 1), totalPaise: 1000, paidPaise: 0).cancel(),
      ];
      expect(ageing(bills, today).total, 600);
      expect(ageing(bills, today).total, bills.fold<int>(0, (s, b) => s + b.outstanding));
    });
    test('overdue and oldest unpaid age; a bill dated in the future counts as 0 days', () {
      final bills = [BillDue(billNo: 'a', date: d(2026, 8, 1), totalPaise: 500, paidPaise: 0), BillDue(billNo: 'b', date: d(2026, 10, 1), totalPaise: 700, paidPaise: 0)];
      expect(overdueAmount(bills, today), 500);
      expect(overdueAmount(bills, today, termDays: 5), 1200);
      expect(oldestUnpaidDays(bills, today), 73);
      expect(oldestUnpaidDays([], today), isNull);
      expect(daysOld(d(2026, 11, 1), today), 0);
    });
  });

  group('statement', () {
    test('opening + charges - credits = closing, with a date range', () {
      final e = [
        LedgerEntry.opening(id: 'o', customerId: 'c', paise: 20000, at: d(2026, 1, 1)),
        LedgerEntry.billCredit(id: '1', customerId: 'c', paise: 5000, at: d(2026, 2, 10), billNo: 'A-1'),
        LedgerEntry.payment(id: '2', customerId: 'c', paise: 8000, at: d(2026, 2, 20)),
        LedgerEntry.billCredit(id: '3', customerId: 'c', paise: 1200, at: d(2026, 3, 5), billNo: 'A-2'),
      ];
      final s = buildStatement(entries: e, from: d(2026, 2, 1), to: d(2026, 2, 28));
      expect(s.openingPaise, 20000);
      expect(s.totalCharges, 5000);
      expect(s.totalCredits, 8000);
      expect(s.closingPaise, 17000);
      expect(s.openingPaise + s.totalCharges - s.totalCredits, s.closingPaise);
      expect(s.lines.last.runningPaise, 17000);
      final all = buildStatement(entries: e, from: d(2026, 1, 1), to: d(2026, 12, 31));
      expect(all.closingPaise, ledgerBalance(e));
      final empty = buildStatement(entries: e, from: d(2026, 6, 1), to: d(2026, 6, 30));
      expect(empty.lines, isEmpty);
      expect(empty.openingPaise, ledgerBalance(e));
      expect(empty.closingPaise, ledgerBalance(e));
    });

    test('property: statement closing always equals the ledger balance at the end date (random ledgers)', () {
      final r = Random(4);
      for (var i = 0; i < 500; i++) {
        final entries = <LedgerEntry>[];
        for (var k = 0; k < 1 + r.nextInt(30); k++) {
          final at = d(2026, 1 + r.nextInt(9), 1 + r.nextInt(27));
          final amt = 1 + r.nextInt(100000);
          entries.add(r.nextBool() ? LedgerEntry.billCredit(id: '$k', customerId: 'c', paise: amt, at: at, billNo: 'A-$k') : LedgerEntry.payment(id: '$k', customerId: 'c', paise: amt, at: at));
        }
        final from = d(2026, 1 + r.nextInt(5), 1);
        final to = d(2026, 6 + r.nextInt(4), 28);
        final s = buildStatement(entries: entries, from: from, to: to);
        expect(s.openingPaise + s.totalCharges - s.totalCredits, s.closingPaise);
        final upTo = entries.where((e) => e.at.isBefore(to.add(const Duration(days: 1))));
        expect(s.closingPaise, ledgerBalance(upTo));
      }
    });
  });

  test('ledger sums equal bill sums: part-paid bills put exactly their balance into the ledger', () {
    final r = Random(5);
    for (var i = 0; i < 1000; i++) {
      final total = 1 + r.nextInt(2000000);
      final received = r.nextInt(total + 200000);
      final s = splitPayment(total: total, received: received);
      final entries = <LedgerEntry>[
        if (s.balance > 0) LedgerEntry.billCredit(id: 'b', customerId: 'c', paise: s.balance, at: d(2026, 1, 1), billNo: 'A-1'),
        if (s.change > 0 && r.nextBool()) LedgerEntry.advance(id: 'a', customerId: 'c', paise: s.change, at: d(2026, 1, 1), billNo: 'A-1'),
      ];
      final kept = entries.any((e) => e.kind == LedgerKind.advance);
      expect(ledgerBalance(entries), s.balance - (kept ? s.change : 0));
    }
  });
}
