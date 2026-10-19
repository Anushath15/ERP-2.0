import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/domain/credit/dues.dart';
import 'package:erp2/domain/credit/ledger.dart';

// Pure rules behind the customer and dealer profiles: manual credit, reversal of a wrong entry (nothing is ever deleted),
// and putting payments back on the bills they were applied to.

DateTime d(int y, int m, int day) => DateTime(y, m, day);

LedgerEntry bill(String id, int paise, {String no = 'A-1'}) => LedgerEntry.billCredit(id: id, customerId: 'c', paise: paise, at: d(2026, 9, 1), billNo: no);

void main() {
  group('manual credit', () {
    test('adds to what the customer owes and needs a reason', () {
      final e = LedgerEntry.manualCredit(id: 'm1', customerId: 'c', paise: 25000, at: d(2026, 10, 1), reason: 'Goods taken without a bill', by: 'Owner');
      expect(e.kind, LedgerKind.manualCredit);
      expect(e.amountPaise, 25000);
      expect(e.note, 'Goods taken without a bill');
      expect(() => LedgerEntry.manualCredit(id: 'm', customerId: 'c', paise: 100, at: d(2026, 10, 1), reason: ' ', by: 'x'), throwsArgumentError);
      expect(() => LedgerEntry.manualCredit(id: 'm', customerId: 'c', paise: 0, at: d(2026, 10, 1), reason: 'x', by: 'x'), throwsArgumentError);
      expect(() => LedgerEntry.manualCredit(id: 'm', customerId: 'c', paise: -5, at: d(2026, 10, 1), reason: 'x', by: 'x'), throwsArgumentError);
    });
  });

  group('reversal (a wrong entry is fixed by a new entry, never deleted)', () {
    test('a reversal has the opposite amount, points to the original and needs a reason; the balance returns to what it was', () {
      final pay = LedgerEntry.payment(id: 'p1', customerId: 'c', paise: 4000, at: d(2026, 9, 5));
      final ledger = [bill('b1', 10000), pay];
      expect(ledgerBalance(ledger), 6000);
      final rev = LedgerEntry.reversal(id: 'r1', customerId: 'c', original: pay, at: d(2026, 9, 6), reason: 'Typed the wrong customer', by: 'Owner');
      expect(rev.amountPaise, 4000);
      expect(rev.reverses, 'p1');
      expect(rev.kind, LedgerKind.adjustment);
      expect(rev.note, contains('Typed the wrong customer'));
      expect(ledgerBalance([...ledger, rev]), 10000);
      expect(() => LedgerEntry.reversal(id: 'r', customerId: 'c', original: pay, at: d(2026, 9, 6), reason: '', by: 'x'), throwsArgumentError);
    });

    test('what can be reversed: payments, advances, manual credit, write-offs, opening; NOT bills, bill cancellations, sales returns or reversals themselves', () {
      final all = {
        LedgerKind.payment: true,
        LedgerKind.advance: true,
        LedgerKind.manualCredit: true,
        LedgerKind.writeOff: true,
        LedgerKind.opening: true,
        LedgerKind.returnCredit: false, // a sales return is final: its stock and totals moved with it
        LedgerKind.billCredit: false,
        LedgerKind.billCancel: false,
      };
      for (final k in all.keys) {
        final e = LedgerEntry(id: 'x', customerId: 'c', kind: k, amountPaise: k == LedgerKind.billCredit || k == LedgerKind.manualCredit || k == LedgerKind.opening ? 100 : -100, at: d(2026, 9, 1));
        expect(isReversible(e), all[k], reason: '$k');
      }
      final pay = LedgerEntry.payment(id: 'p1', customerId: 'c', paise: 100, at: d(2026, 9, 5));
      final rev = LedgerEntry.reversal(id: 'r1', customerId: 'c', original: pay, at: d(2026, 9, 6), reason: 'oops', by: 'x');
      expect(isReversible(rev), isFalse, reason: 'a reversal cannot be reversed again: make a new entry instead');
    });

    test('an entry can be reversed only once', () {
      final pay = LedgerEntry.payment(id: 'p1', customerId: 'c', paise: 100, at: d(2026, 9, 5));
      final rev = LedgerEntry.reversal(id: 'r1', customerId: 'c', original: pay, at: d(2026, 9, 6), reason: 'oops', by: 'x');
      expect(reversedIds([pay]), isEmpty);
      expect(reversedIds([pay, rev]), {'p1'});
    });

    test('reversing something that cannot be reversed throws', () {
      final b = bill('b1', 100);
      expect(() => LedgerEntry.reversal(id: 'r', customerId: 'c', original: b, at: d(2026, 9, 6), reason: 'x', by: 'x'), throwsStateError);
    });
  });

  group('allocations are kept on the payment so a reversal can put them back', () {
    test('payment entry carries its allocations; restoreAllocations is the exact inverse of applyAllocations (random)', () {
      final r = Random(7);
      for (var i = 0; i < 300; i++) {
        final bills = [for (var j = 0; j < 1 + r.nextInt(6); j++) BillDue(billNo: 'B$j', date: d(2026, 8, 1 + j), totalPaise: 1000 + r.nextInt(100000), paidPaise: 0)];
        final amount = 1 + r.nextInt(300000);
        final res = allocatePayment(bills: bills, amount: amount);
        final after = applyAllocations(bills, res.allocations);
        final back = restoreAllocations(after, res.allocations);
        for (var j = 0; j < bills.length; j++) {
          expect(back[j].paidPaise, bills[j].paidPaise);
          expect(back[j].outstanding, bills[j].outstanding);
        }
      }
    });

    test('LedgerEntry.payment can carry allocations', () {
      final e = LedgerEntry.payment(id: 'p', customerId: 'c', paise: 300, at: d(2026, 9, 5), allocations: const [Allocation('A-1', 200), Allocation('A-2', 100)]);
      expect(e.allocations.map((a) => a.paise).fold<int>(0, (s, x) => s + x), 300);
    });
  });
}
