import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/domain/credit/dues.dart';
import 'package:erp2/domain/credit/ledger.dart';
import 'package:erp2/fake/credit_store.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/domain/models.dart';
import 'package:erp2/demo/seed.dart';
import 'data/helpers.dart' as db;
import 'helpers.dart';

// Settle fully (with Undo), manual credit, reversal of wrong entries, opening balances and the profile facts, on the real database
// (in memory) through the same notifiers the screens use.
DateTime daysAgo(int n) => fixedNow.subtract(Duration(days: n));

Future<ProviderContainer> fresh({AppData? shop}) async {
  final d = shop ?? db.memoryShop(now: fixedNow);
  final boot = await Bootstrap.load(d, now: fixedNow);
  final c = ProviderContainer(overrides: [clockProvider.overrideWithValue(fixedNow), appDataProvider.overrideWithValue(d), bootstrapProvider.overrideWithValue(boot)]);
  addTearDown(() async {
    c.dispose();
    await d.close();
  });
  return c;
}

void main() {
  const id = 'zz1';

  Future<CreditNotifier> setup(ProviderContainer c) async {
    final d = c.read(appDataProvider);
    c.read(customersProvider.notifier).add(db.sampleCustomer('Z', id: id)); // the way a screen adds a customer
    await c.read(writeQueueProvider).flush();
    await d.db.transaction(() async {
      await d.ledger.addBillCredit(d.db, PartyKind.customer, partyId: id, billNo: 'B-1', at: daysAgo(50), total: 30000, received: 10000); // 20000 credit, 50 days old
      await d.ledger.addBillCredit(d.db, PartyKind.customer, partyId: id, billNo: 'B-2', at: daysAgo(10), total: 15000, received: 5000); // 10000 credit
    });
    final n = c.read(creditProvider.notifier);
    await n.refreshParty(id);
    return n;
  }

  test('settle fully records the whole balance as received, oldest bill first; the balance is zero and a receipt exists', () async {
    final c = await fresh();
    final n = await setup(c);
    expect(n.balanceOf(id), 30000);
    final r = (await n.settleFully(customerId: id, customerName: 'Z', mode: 'upi', at: fixedNow))!;
    expect(r.amountPaise, 30000);
    expect(r.allocations.map((a) => a.billNo).toList(), ['B-1', 'B-2']);
    expect(n.balanceOf(id), 0);
    expect(c.read(creditProvider)[id]!.bills.every((b) => b.outstanding == 0), isTrue);
    expect(c.read(creditProvider)[id]!.ledger.last.mode, 'upi');
    expect(await n.settleFully(customerId: id, customerName: 'Z', mode: 'cash', at: fixedNow), isNull, reason: 'nothing left to settle');
    expect(c.read(customersProvider).firstWhere((x) => x.id == id).balancePaise, 0, reason: 'the customer list shows the new balance too');
  });

  test('Undo takes the payment back, exactly; it refuses once something else changed on that account', () async {
    final c = await fresh();
    final n = await setup(c);
    final before = c.read(creditProvider)[id]!;
    final r = (await n.settleFully(customerId: id, customerName: 'Z', mode: 'cash', at: fixedNow))!;
    expect(await n.undoPayment(r), isTrue);
    final after = c.read(creditProvider)[id]!;
    expect(after.balance, before.balance);
    expect(after.ledger.length, before.ledger.length);
    expect([for (final b in after.bills) '${b.billNo}:${b.outstanding}'], [for (final b in before.bills) '${b.billNo}:${b.outstanding}']);
    expect(n.balanceOf(id), 30000);

    final r2 = (await n.settleFully(customerId: id, customerName: 'Z', mode: 'cash', at: fixedNow))!;
    await n.addManualCredit(customerId: id, amount: 500, at: fixedNow, reason: 'later change');
    expect(await n.undoPayment(r2), isFalse);
    expect(n.balanceOf(id), 500);
  });

  test('reversing a payment puts the money back on the same bills and keeps both entries in the ledger; only once', () async {
    final c = await fresh();
    final n = await setup(c);
    final r = await n.receivePayment(customerId: id, customerName: 'Z', amount: 25000, mode: 'cash', at: fixedNow);
    expect(r.allocations.map((a) => '${a.billNo}:${a.paise}').toList(), ['B-1:20000', 'B-2:5000']);
    final pay = c.read(creditProvider)[id]!.ledger.firstWhere((e) => e.kind == LedgerKind.payment);
    await n.reverseEntry(partyId: id, entryId: pay.id, reason: 'Wrong customer', at: fixedNow);
    final a = c.read(creditProvider)[id]!;
    expect(a.balance, 30000);
    expect(a.bills.firstWhere((b) => b.billNo == 'B-1').outstanding, 20000);
    expect(a.bills.firstWhere((b) => b.billNo == 'B-2').outstanding, 10000);
    expect(a.ledger.where((e) => e.kind == LedgerKind.payment).length, 1, reason: 'the wrong entry stays');
    expect(a.ledger.where((e) => e.reverses == pay.id).length, 1);
    expect(a.balance, a.bills.fold<int>(0, (s, b) => s + b.outstanding), reason: 'bill-wise dues still equal the ledger');
    await expectLater(n.reverseEntry(partyId: id, entryId: pay.id, reason: 'again', at: fixedNow), throwsStateError);
  });

  test('manual credit ages like a bill; payments settle it oldest first; reversing it removes it from the dues', () async {
    final c = await fresh();
    final n = await setup(c);
    final no = await n.addManualCredit(customerId: id, amount: 7000, at: daysAgo(70), reason: 'Old debt');
    var a = c.read(creditProvider)[id]!;
    expect(a.balance, 37000);
    expect(a.lastCredit!.billNo, isNotNull);
    expect(a.creditStart, a.bills.firstWhere((b) => b.billNo == no).date, reason: 'the manual credit is the oldest');
    expect(ageing(a.bills, fixedNow).d61to90, 7000);
    final entry = a.ledger.firstWhere((e) => e.kind == LedgerKind.manualCredit);
    await n.reverseEntry(partyId: id, entryId: entry.id, reason: 'Entered twice', at: fixedNow);
    a = c.read(creditProvider)[id]!;
    expect(a.balance, 30000);
    expect(a.bills.fold<int>(0, (s, b) => s + b.outstanding), 30000);
  });

  test('an opening balance with a start date: appears in the dues and ages from that date', () async {
    final c = await fresh();
    await c.read(appDataProvider).catalog.saveCustomer(db.sampleCustomer('Z2', id: 'zz2'), create: true);
    final n = c.read(creditProvider.notifier);
    await n.addOpening(customerId: 'zz2', amount: 90000, at: daysAgo(120));
    final a = c.read(creditProvider)['zz2']!;
    expect(a.balance, 90000);
    expect(a.creditStart, daysAgo(120));
    expect(ageing(a.bills, fixedNow).d90plus, 90000);
  });

  test('profile facts: start of credit, next due date, last payment and last credit with date and amount', () async {
    final c = await fresh();
    final n = await setup(c);
    await n.receivePayment(customerId: id, customerName: 'Z', amount: 4000, mode: 'cash', at: daysAgo(3));
    final a = c.read(creditProvider)[id]!;
    expect(a.creditStart, daysAgo(50));
    expect(a.nextDue(), daysAgo(50).add(const Duration(days: 30)).copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0));
    expect(a.lastPayment!.amountPaise, -4000);
    expect(a.lastPayment!.at, daysAgo(3));
    expect(a.lastCredit!.amountPaise, 10000, reason: 'the newest credit is bill B-2');
  });

  test('write-off keeps its allocations so it can be reversed too', () async {
    final c = await fresh();
    final n = await setup(c);
    await n.writeOff(customerId: id, amount: 12000, reason: 'Customer closed shop', at: fixedNow);
    var a = c.read(creditProvider)[id]!;
    expect(a.balance, 18000);
    await n.reverseEntry(partyId: id, entryId: a.ledger.firstWhere((e) => e.kind == LedgerKind.writeOff).id, reason: 'Paid after all', at: fixedNow);
    a = c.read(creditProvider)[id]!;
    expect(a.balance, 30000);
    expect(a.bills.fold<int>(0, (s, b) => s + b.outstanding), 30000);
  });

  test('adding a customer (or taking a payment) must not reset the credit data or the reminder history already made', () async {
    final c = await fresh();
    final n = await setup(c);
    final rem = c.read(reminderLogProvider.notifier);
    rem.record(customerId: id, amountDue: 30000, message: 'm', at: fixedNow);
    final remindersBefore = c.read(reminderLogProvider).countFor(id);
    expect(remindersBefore, greaterThanOrEqualTo(1));
    await n.addManualCredit(customerId: id, amount: 123, at: fixedNow, reason: 'x');
    c.read(customersProvider.notifier).add(const Customer(id: 'new1', name: 'New Person', phone: '', city: '', balancePaise: 0));
    expect(n.balanceOf(id), 30123, reason: 'the credit data was not rebuilt from the seed');
    await n.receivePayment(customerId: id, customerName: 'Z', amount: 100, mode: 'cash', at: fixedNow);
    expect(c.read(reminderLogProvider).countFor(id), remindersBefore, reason: 'the reminder history survives a credit change');
    await c.read(writeQueueProvider).flush();
    expect((await c.read(appDataProvider).db.rows('SELECT * FROM reminders WHERE customer_id = ?', [id])).length, 1, reason: 'the reminder reached the database');
    expect((await c.read(appDataProvider).catalog.customer('new1'))?.name, 'New Person', reason: 'and so did the new customer');
  });

  test('adjustments by hand: plus makes a new due line, minus is taken off the oldest bills; both can be reversed', () async {
    final c = await fresh();
    final n = await setup(c);
    await n.addAdjustment(partyId: id, signedPaise: 5000, at: fixedNow, reason: 'Freight charged');
    expect(n.balanceOf(id), 35000);
    await n.addAdjustment(partyId: id, signedPaise: -8000, at: fixedNow, reason: 'Discount given');
    var a = c.read(creditProvider)[id]!;
    expect(a.balance, 27000);
    expect(a.bills.firstWhere((b) => b.billNo == 'B-1').outstanding, 12000, reason: 'the discount came off the oldest bill');
    expect(a.balance, a.bills.fold<int>(0, (s, b) => s + b.outstanding));
    for (final e in a.ledger.where((e) => e.kind == LedgerKind.adjustment).toList()) {
      await n.reverseEntry(partyId: id, entryId: e.id, reason: 'Entered by mistake', at: fixedNow);
    }
    a = c.read(creditProvider)[id]!;
    expect(a.balance, 30000);
    expect(a.balance, a.bills.fold<int>(0, (s, b) => s + b.outstanding));
  });

  test('dealers use the same rules: a payment to a dealer settles the oldest purchase first', () async {
    final c = await fresh();
    final dl = c.read(appDataProvider);
    await dl.catalog.saveDealer(const Rec('dd1', {'name': 'D', 'phone': '', 'city': ''}), create: true);
    await dl.db.transaction(() async {
      await dl.ledger.addBillCredit(dl.db, PartyKind.dealer, partyId: 'dd1', billNo: 'PUR-1', at: daysAgo(40), total: 500000, received: 0);
      await dl.ledger.addBillCredit(dl.db, PartyKind.dealer, partyId: 'dd1', billNo: 'PUR-2', at: daysAgo(5), total: 200000, received: 0);
    });
    final d = c.read(dealerLedgerProvider.notifier);
    await d.refreshParty('dd1');
    final r = await d.receivePayment(customerId: 'dd1', customerName: 'D', amount: 600000, mode: 'upi', at: fixedNow, note: 'UTR 123');
    expect(r.number, startsWith('PAY-'));
    expect(r.allocations.map((a) => '${a.billNo}:${a.paise}').toList(), ['PUR-1:500000', 'PUR-2:100000']);
    expect(d.balanceOf('dd1'), 100000);
  });

  test('an old opening balance (no bill behind it) is paid off by a payment, never turned into a fake advance', () async {
    final seeded = seedCredit(seedCustomers(), fixedNow);
    final shop = await openDemoShop();
    final c = await fresh(shop: shop);
    final entry = seeded.entries.firstWhere((e) => e.value.unbilledBalance > 0);
    final n = c.read(creditProvider.notifier);
    final key = entry.key;
    final owed = n.balanceOf(key);
    expect(c.read(creditProvider)[key]!.unbilledBalance, greaterThan(0));
    final r = (await n.settleFully(customerId: key, customerName: 'X', mode: 'cash', at: fixedNow))!;
    final a = c.read(creditProvider)[key]!;
    expect(a.balance, 0);
    expect(r.amountPaise, owed);
    expect(r.advancePaise, 0, reason: 'nothing was paid ahead');
    expect(a.ledger.where((e) => e.kind == LedgerKind.advance).isEmpty, isTrue);
    // and a part payment larger than the bills but below the balance also pays the opening balance
    final key2 = seeded.entries.firstWhere((e) => e.key != key && e.value.unbilledBalance > 0).key;
    final billsOwed = c.read(creditProvider)[key2]!.bills.fold<int>(0, (s, b) => s + b.outstanding);
    final r2 = await n.receivePayment(customerId: key2, customerName: 'Y', amount: billsOwed + 100, mode: 'cash', at: fixedNow);
    expect(r2.advancePaise, 0);
    expect(n.balanceOf(key2), c.read(creditProvider)[key2]!.unbilledBalance, reason: 'what remains is only the rest of the opening balance');
  });
}
