import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/domain/credit/dues.dart';
import 'package:erp2/domain/credit/ledger.dart';
import 'package:erp2/fake/credit_store.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/fake/seed.dart';
import 'helpers.dart';

// Settle fully (with Undo), manual credit, reversal of wrong entries, opening balances and the profile facts, on the fake store.
ProviderContainer fresh() {
  final c = ProviderContainer(overrides: [clockProvider.overrideWithValue(fixedNow)]);
  addTearDown(c.dispose);
  return c;
}

DateTime daysAgo(int n) => fixedNow.subtract(Duration(days: n));

void main() {
  const id = 'zz1';

  CreditNotifier setup(ProviderContainer c) {
    final n = c.read(creditProvider.notifier);
    n.addBill(customerId: id, billNo: 'B-1', at: daysAgo(50), total: 30000, received: 10000); // 20000 credit, 50 days old
    n.addBill(customerId: id, billNo: 'B-2', at: daysAgo(10), total: 15000, received: 5000); // 10000 credit
    return n;
  }

  test('settle fully records the whole balance as received, oldest bill first; the balance is zero and a receipt exists', () {
    final c = fresh();
    final n = setup(c);
    expect(n.balanceOf(id), 30000);
    final r = n.settleFully(customerId: id, customerName: 'Z', mode: 'upi', at: fixedNow)!;
    expect(r.amountPaise, 30000);
    expect(r.allocations.map((a) => a.billNo).toList(), ['B-1', 'B-2']);
    expect(n.balanceOf(id), 0);
    expect(c.read(creditProvider)[id]!.bills.every((b) => b.outstanding == 0), isTrue);
    expect(c.read(creditProvider)[id]!.ledger.last.mode, 'upi');
    expect(n.settleFully(customerId: id, customerName: 'Z', mode: 'cash', at: fixedNow), isNull, reason: 'nothing left to settle');
  });

  test('Undo takes the payment back, exactly; it refuses once something else changed on that account', () {
    final c = fresh();
    final n = setup(c);
    final before = c.read(creditProvider)[id]!;
    final r = n.settleFully(customerId: id, customerName: 'Z', mode: 'cash', at: fixedNow)!;
    expect(n.undoPayment(r), isTrue);
    expect(c.read(creditProvider)[id], same(before));
    expect(n.balanceOf(id), 30000);

    final r2 = n.settleFully(customerId: id, customerName: 'Z', mode: 'cash', at: fixedNow)!;
    n.addManualCredit(customerId: id, amount: 500, at: fixedNow, reason: 'later change');
    expect(n.undoPayment(r2), isFalse);
    expect(n.balanceOf(id), 500);
  });

  test('reversing a payment puts the money back on the same bills and keeps both entries in the ledger; only once', () {
    final c = fresh();
    final n = setup(c);
    final r = n.receivePayment(customerId: id, customerName: 'Z', amount: 25000, mode: 'cash', at: fixedNow);
    expect(r.allocations.map((a) => '${a.billNo}:${a.paise}').toList(), ['B-1:20000', 'B-2:5000']);
    final pay = c.read(creditProvider)[id]!.ledger.firstWhere((e) => e.kind == LedgerKind.payment);
    n.reverseEntry(partyId: id, entryId: pay.id, reason: 'Wrong customer', at: fixedNow);
    final a = c.read(creditProvider)[id]!;
    expect(a.balance, 30000);
    expect(a.bills.firstWhere((b) => b.billNo == 'B-1').outstanding, 20000);
    expect(a.bills.firstWhere((b) => b.billNo == 'B-2').outstanding, 10000);
    expect(a.ledger.where((e) => e.kind == LedgerKind.payment).length, 1, reason: 'the wrong entry stays');
    expect(a.ledger.where((e) => e.reverses == pay.id).length, 1);
    expect(a.balance, a.bills.fold<int>(0, (s, b) => s + b.outstanding), reason: 'bill-wise dues still equal the ledger');
    expect(() => n.reverseEntry(partyId: id, entryId: pay.id, reason: 'again', at: fixedNow), throwsStateError);
  });

  test('manual credit ages like a bill; payments settle it oldest first; reversing it removes it from the dues', () {
    final c = fresh();
    final n = setup(c);
    final no = n.addManualCredit(customerId: id, amount: 7000, at: daysAgo(70), reason: 'Old debt');
    var a = c.read(creditProvider)[id]!;
    expect(a.balance, 37000);
    expect(a.lastCredit!.billNo, isNotNull);
    expect(a.creditStart, a.bills.firstWhere((b) => b.billNo == no).date, reason: 'the manual credit is the oldest');
    expect(ageing(a.bills, fixedNow).d61to90, 7000);
    final entry = a.ledger.firstWhere((e) => e.kind == LedgerKind.manualCredit);
    n.reverseEntry(partyId: id, entryId: entry.id, reason: 'Entered twice', at: fixedNow);
    a = c.read(creditProvider)[id]!;
    expect(a.balance, 30000);
    expect(a.bills.fold<int>(0, (s, b) => s + b.outstanding), 30000);
  });

  test('an opening balance with a start date: appears in the dues and ages from that date', () {
    final c = fresh();
    final n = c.read(creditProvider.notifier);
    n.addOpening(customerId: 'zz2', amount: 90000, at: daysAgo(120));
    final a = c.read(creditProvider)['zz2']!;
    expect(a.balance, 90000);
    expect(a.creditStart, DateTime(fixedNow.year, fixedNow.month, fixedNow.day).subtract(const Duration(days: 120)).add(Duration(hours: daysAgo(120).hour, minutes: daysAgo(120).minute)));
    expect(ageing(a.bills, fixedNow).d90plus, 90000);
  });

  test('profile facts: start of credit, next due date, last payment and last credit with date and amount', () {
    final c = fresh();
    final n = setup(c);
    n.receivePayment(customerId: id, customerName: 'Z', amount: 4000, mode: 'cash', at: daysAgo(3));
    final a = c.read(creditProvider)[id]!;
    expect(a.creditStart, daysAgo(50));
    expect(a.nextDue(), daysAgo(50).add(const Duration(days: 30)).copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0));
    expect(a.lastPayment!.amountPaise, -4000);
    expect(a.lastPayment!.at, daysAgo(3));
    expect(a.lastCredit!.amountPaise, 10000, reason: 'the newest credit is bill B-2');
  });

  test('write-off keeps its allocations so it can be reversed too', () {
    final c = fresh();
    final n = setup(c);
    n.writeOff(customerId: id, amount: 12000, reason: 'Customer closed shop', at: fixedNow);
    var a = c.read(creditProvider)[id]!;
    expect(a.balance, 18000);
    n.reverseEntry(partyId: id, entryId: a.ledger.firstWhere((e) => e.kind == LedgerKind.writeOff).id, reason: 'Paid after all', at: fixedNow);
    a = c.read(creditProvider)[id]!;
    expect(a.balance, 30000);
    expect(a.bills.fold<int>(0, (s, b) => s + b.outstanding), 30000);
  });

  test('adding a customer (or taking a payment) must not reset the credit data or the reminder history already made', () {
    final c = fresh();
    final n = setup(c);
    final rem = c.read(reminderLogProvider.notifier);
    rem.record(customerId: id, amountDue: 30000, message: 'm', at: fixedNow);
    final remindersBefore = c.read(reminderLogProvider).countFor(id);
    expect(remindersBefore, greaterThanOrEqualTo(1));
    n.addManualCredit(customerId: id, amount: 123, at: fixedNow, reason: 'x');
    c.read(customersProvider.notifier).add(const Customer(id: 'new1', name: 'New Person', phone: '', city: '', balancePaise: 0));
    expect(n.balanceOf(id), 30123, reason: 'the credit data was not rebuilt from the seed');
    n.receivePayment(customerId: id, customerName: 'Z', amount: 100, mode: 'cash', at: fixedNow);
    expect(c.read(reminderLogProvider).countFor(id), remindersBefore, reason: 'the reminder history survives a credit change');
  });

  test('adjustments by hand: plus makes a new due line, minus is taken off the oldest bills; both can be reversed', () {
    final c = fresh();
    final n = setup(c);
    n.addAdjustment(partyId: id, signedPaise: 5000, at: fixedNow, reason: 'Freight charged');
    expect(n.balanceOf(id), 35000);
    n.addAdjustment(partyId: id, signedPaise: -8000, at: fixedNow, reason: 'Discount given');
    var a = c.read(creditProvider)[id]!;
    expect(a.balance, 27000);
    expect(a.bills.firstWhere((b) => b.billNo == 'B-1').outstanding, 12000, reason: 'the discount came off the oldest bill');
    expect(a.balance, a.bills.fold<int>(0, (s, b) => s + b.outstanding));
    for (final e in a.ledger.where((e) => e.kind == LedgerKind.adjustment).toList()) {
      n.reverseEntry(partyId: id, entryId: e.id, reason: 'Entered by mistake', at: fixedNow);
    }
    a = c.read(creditProvider)[id]!;
    expect(a.balance, 30000);
    expect(a.balance, a.bills.fold<int>(0, (s, b) => s + b.outstanding));
  });

  test('dealers use the same rules: a payment to a dealer settles the oldest purchase first', () {
    final c = fresh();
    final d = c.read(dealerLedgerProvider.notifier);
    d.addBill(customerId: 'dd1', billNo: 'PUR-1', at: daysAgo(40), total: 500000, received: 0);
    d.addBill(customerId: 'dd1', billNo: 'PUR-2', at: daysAgo(5), total: 200000, received: 0);
    final r = d.receivePayment(customerId: 'dd1', customerName: 'D', amount: 600000, mode: 'upi', at: fixedNow, note: 'UTR 123');
    expect(r.number, startsWith('PAY-'));
    expect(r.allocations.map((a) => '${a.billNo}:${a.paise}').toList(), ['PUR-1:500000', 'PUR-2:100000']);
    expect(d.balanceOf('dd1'), 100000);
  });

  test('an old opening balance (no bill behind it) is paid off by a payment, never turned into a fake advance', () {
    final c = fresh();
    final customers = seedCustomers();
    final seeded = seedCredit(customers, fixedNow);
    final entry = seeded.entries.firstWhere((e) => e.value.unbilledBalance > 0);
    final n = c.read(creditProvider.notifier);
    final key = entry.key;
    final owed = n.balanceOf(key);
    expect(c.read(creditProvider)[key]!.unbilledBalance, greaterThan(0));
    final r = n.settleFully(customerId: key, customerName: 'X', mode: 'cash', at: fixedNow)!;
    final a = c.read(creditProvider)[key]!;
    expect(a.balance, 0);
    expect(r.amountPaise, owed);
    expect(r.advancePaise, 0, reason: 'nothing was paid ahead');
    expect(a.ledger.where((e) => e.kind == LedgerKind.advance).isEmpty, isTrue);
    // and a part payment larger than the bills but below the balance also pays the opening balance
    final key2 = seeded.entries.firstWhere((e) => e.key != key && e.value.unbilledBalance > 0).key;
    final billsOwed = c.read(creditProvider)[key2]!.bills.fold<int>(0, (s, b) => s + b.outstanding);
    final r2 = n.receivePayment(customerId: key2, customerName: 'Y', amount: billsOwed + 100, mode: 'cash', at: fixedNow);
    expect(r2.advancePaise, 0);
    expect(n.balanceOf(key2), c.read(creditProvider)[key2]!.unbilledBalance, reason: 'what remains is only the rest of the opening balance');
  });
}
