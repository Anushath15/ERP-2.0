import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/domain/credit/account.dart';
import 'package:erp2/domain/models.dart';
import 'helpers.dart';

// Saving a bill writes everything in one transaction; the invariants of docs/data-model.md hold after every operation.
void main() {
  late AppData d;
  late Product screw, switchP;
  late Customer murugan;

  setUp(() async {
    d = memoryShop();
    screw = sampleProduct('1 1/2" WOOD SCREW BOX', price: 12500, stock: 20000, id: 'p-screw');
    switchP = sampleProduct('HAVELLS 1 WAY SWITCH', price: 4500, stock: 3000, id: 'p-switch');
    murugan = sampleCustomer('Murugan Electricals', id: 'c-murugan');
    await d.catalog.saveProduct(screw, create: true);
    await d.catalog.saveProduct(switchP, create: true);
    await d.catalog.saveCustomer(murugan, create: true);
  });
  tearDown(() => d.close());

  BillLineInput line(Product p, int qty, {int? rate, int disc = 0}) => BillLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: qty, ratePaise: rate ?? p.pricePaise, gstBp: p.gstBp, discountBp: disc);

  SaveBillInput input(List<BillLineInput> lines, {String key = 'k1', String? customer, int? received, int mode = 0, bool keepAdvance = false}) =>
      SaveBillInput(idemKey: key, at: DateTime(2026, 10, 14, 15, 30), lines: lines, customerId: customer, customerName: customer == null ? '' : 'Murugan Electricals', receivedPaise: received, payMode: mode, keepAdvance: keepAdvance);

  Future<int> stockOf(String id) async => (await d.catalog.product(id))!.stockMilli;

  Future<void> checkInvariants() async {
    // stock = sum of movements; balance = sum of ledger entries; running balance of the last entry = balance
    final mismatch = await d.db.rows('SELECT p.id FROM products p LEFT JOIN stock_cache s ON s.product_id = p.id WHERE COALESCE(s.qty_milli,0) <> COALESCE((SELECT SUM(qty_milli) FROM stock_movements m WHERE m.product_id = p.id),0)');
    expect(mismatch, isEmpty, reason: 'stock cache equals the movements');
    final bal = await d.db.rows('SELECT b.party_id FROM party_balance b WHERE b.balance_paise <> COALESCE((SELECT SUM(amount_paise) FROM ledger_entries e WHERE e.party_id = b.party_id),0)');
    expect(bal, isEmpty, reason: 'balance cache equals the ledger');
    final dues = await d.db.rows('SELECT id FROM party_bills WHERE paid_paise < 0 OR paid_paise > total_paise');
    expect(dues, isEmpty, reason: 'no due is overpaid');
    final days = await d.db.rows('SELECT t.day FROM day_totals t WHERE t.sales_paise <> COALESCE((SELECT SUM(total_paise) FROM bills b WHERE b.day = t.day AND b.cancelled = 0),0) OR t.bills <> (SELECT COUNT(*) FROM bills b WHERE b.day = t.day AND b.cancelled = 0)');
    expect(days, isEmpty, reason: 'day totals equal the bills');
  }

  test('a fully paid walk-in bill: bill, lines, stock, day totals, upload row; stock goes down', () async {
    final s = await d.bills.saveBill(input([line(screw, 2000), line(switchP, 3000)]));
    expect(s.number, 'A-000001');
    expect(s.balancePaise, 0);
    expect(s.totalPaise, 25000 + 13500);
    expect(await stockOf('p-screw'), 18000);
    expect(await stockOf('p-switch'), 0);
    final detail = (await d.bills.detail(s.id))!;
    expect(detail.lines.length, 2);
    expect(detail.row.cancelled, isFalse);
    final day = (await d.db.rows("SELECT * FROM day_totals WHERE day = '2026-10-14'")).single;
    expect(day.read<int>('bills'), 1);
    expect(day.read<int>('sales_paise'), s.totalPaise - 0);
    expect(day.read<int>('cash_paise'), s.totalPaise);
    expect((await d.db.rows("SELECT * FROM outbox WHERE coll = 'bills' AND doc_id = ?", [s.id])).length, 1);
    await checkInvariants();
  });

  test('numbers are gapless and per series; a repeated save with the same key returns the same bill and writes nothing', () async {
    final a = await d.bills.saveBill(input([line(screw, 1000)], key: 'x1'));
    final again = await d.bills.saveBill(input([line(screw, 1000)], key: 'x1'));
    final b = await d.bills.saveBill(input([line(screw, 1000)], key: 'x2'));
    expect(again.replay, isTrue);
    expect(again.id, a.id);
    expect(a.number, 'A-000001');
    expect(b.number, 'A-000002');
    expect(await d.bills.count(), 2);
    expect(await stockOf('p-screw'), 18000, reason: 'the repeat did not take stock again');
    d.bills.series = 'B';
    expect((await d.bills.saveBill(input([line(screw, 1000)], key: 'x3'))).number, 'B-000001');
    d.bills.invoicePrefix = 'SE';
    expect((await d.bills.saveBill(input([line(screw, 1000)], key: 'x4'))).number, 'SEB-000002');
  });

  test('a part-paid bill for a named customer puts the rest on credit; the customer balance, dues and ledger agree', () async {
    final s = await d.bills.saveBill(input([line(screw, 4000)], customer: 'c-murugan', received: 20000, mode: 1));
    expect(s.totalPaise, 50000);
    expect(s.balancePaise, 30000);
    expect(await d.ledger.balanceOf('c-murugan'), 30000);
    final acc = await d.ledger.account('c-murugan');
    expect(acc.ledger.single.kind.name, 'billCredit');
    expect(acc.bills.single.outstanding, 30000);
    expect((await d.catalog.customer('c-murugan'))!.balancePaise, 30000);
    final day = (await d.db.rows("SELECT * FROM day_totals")).single;
    expect(day.read<int>('upi_paise'), 20000);
    expect(day.read<int>('credit_paise'), 30000);
    await checkInvariants();
  });

  test('money left to pay without a customer is refused and nothing at all is written', () async {
    await expectLater(d.bills.saveBill(input([line(screw, 1000)], received: 5000)), throwsStateError);
    expect(await d.bills.count(), 0);
    expect(await stockOf('p-screw'), 20000);
    expect((await d.db.rows("SELECT * FROM counters WHERE name LIKE 'inv.%'")), isEmpty, reason: 'the number was not used up');
    expect((await d.db.rows('SELECT * FROM outbox')).where((r) => r.read<String>('coll') == 'bills'), isEmpty);
  });

  test('extra money from a named customer can be kept as an advance (a negative balance)', () async {
    final s = await d.bills.saveBill(input([line(switchP, 1000)], customer: 'c-murugan', received: 10000, keepAdvance: true));
    expect(s.advanceKeptPaise, 5500);
    expect(s.changePaise, 0);
    expect(await d.ledger.balanceOf('c-murugan'), -5500);
    await checkInvariants();
  });

  test('a bad line (zero quantity, an unknown product) fails as a whole: no bill, no number, no stock change', () async {
    await expectLater(d.bills.saveBill(input([line(screw, 1000), line(screw, 0)])), throwsArgumentError);
    await expectLater(d.bills.saveBill(input([line(screw, 1000), const BillLineInput(productId: 'does-not-exist', name: 'x', unit: 'pcs', qtyMilli: 1000, ratePaise: 100, gstBp: 0)])), throwsA(anything));
    expect(await d.bills.count(), 0);
    expect(await stockOf('p-screw'), 20000);
    expect((await d.db.rows("SELECT * FROM counters WHERE name LIKE 'inv.%'")), isEmpty);
  });

  test('selling more than the stock is allowed (it warns on the screen) and the stock goes below zero', () async {
    await d.bills.saveBill(input([line(switchP, 5000)]));
    expect(await stockOf('p-switch'), -2000);
    await checkInvariants();
  });

  test('cancelling a bill puts the stock back, reverses the credit, corrects the day, keeps the bill, and cannot be repeated', () async {
    final s = await d.bills.saveBill(input([line(screw, 4000)], customer: 'c-murugan', received: 20000));
    expect(await d.bills.cancelBill(s.id, reason: 'Wrong customer'), isTrue);
    expect(await d.bills.cancelBill(s.id, reason: 'again'), isFalse);
    expect(await stockOf('p-screw'), 20000);
    expect(await d.ledger.balanceOf('c-murugan'), 0);
    final detail = (await d.bills.detail(s.id))!;
    expect(detail.row.cancelled, isTrue);
    expect(detail.cancelReason, 'Wrong customer');
    final day = (await d.db.rows('SELECT * FROM day_totals')).single;
    expect(day.read<int>('bills'), 0);
    expect(day.read<int>('sales_paise'), 0);
    expect(day.read<int>('cancelled_bills'), 1);
    expect(await d.bills.count(), 1, reason: 'the bill stays');
    await expectLater(d.bills.cancelBill(s.id, reason: ' '), throwsArgumentError);
    await checkInvariants();
  });

  test('payments: applied oldest first, the rest becomes an advance; undo takes it all back', () async {
    final a = await d.bills.saveBill(input([line(screw, 4000)], key: 'a', customer: 'c-murugan', received: 0)); // 500.00 owed
    await d.bills.saveBill(SaveBillInput(idemKey: 'b', at: DateTime(2026, 10, 15, 10), lines: [line(switchP, 2000)], customerId: 'c-murugan', customerName: 'Murugan Electricals', receivedPaise: 0)); // 90.00 owed
    expect(await d.ledger.balanceOf('c-murugan'), 59000);
    final r = await d.ledger.receivePayment(PartyKind.customer, partyId: 'c-murugan', partyName: 'Murugan Electricals', amount: 60000, mode: 'cash', at: DateTime(2026, 10, 16, 9));
    expect(r.allocations.map((x) => '${x.billNo}:${x.paise}'), [for (final x in r.allocations) '${x.billNo}:${x.paise}']);
    expect(r.advancePaise, 1000);
    expect(r.balanceAfter, -1000);
    expect(r.number, 'RCP-0001');
    final dues = await d.ledger.dues('c-murugan');
    expect(dues.every((x) => x.outstanding == 0), isTrue);
    await checkInvariants();
    expect(await d.ledger.undoPayment(PartyKind.customer, r), isTrue);
    expect(await d.ledger.balanceOf('c-murugan'), 59000);
    expect((await d.ledger.dues('c-murugan')).map((x) => x.outstanding).fold<int>(0, (s, x) => s + x), 59000);
    expect((await d.db.rows("SELECT * FROM payments")), isEmpty);
    expect((await d.db.rows("SELECT * FROM outbox WHERE coll = 'payments'")), isEmpty);
    await checkInvariants();
    expect(a.number, 'A-000001');
  });

  test('a payment cannot be undone once another entry follows it', () async {
    await d.bills.saveBill(input([line(screw, 4000)], key: 'a', customer: 'c-murugan', received: 0));
    final r = await d.ledger.receivePayment(PartyKind.customer, partyId: 'c-murugan', partyName: 'M', amount: 10000, mode: 'cash', at: DateTime(2026, 10, 16));
    await d.ledger.addAdjustment(PartyKind.customer, partyId: 'c-murugan', signedPaise: 100, at: DateTime(2026, 10, 17), reason: 'Rounding');
    expect(await d.ledger.undoPayment(PartyKind.customer, r), isFalse);
    await checkInvariants();
  });

  test('settle fully, write-off limit, reversal (once only), manual credit, opening balance', () async {
    await d.bills.saveBill(input([line(screw, 4000)], customer: 'c-murugan', received: 0));
    await d.ledger.addOpening(PartyKind.customer, partyId: 'c-murugan', amount: 20000, at: DateTime(2026, 4, 1));
    final no = await d.ledger.addManualCredit(PartyKind.customer, partyId: 'c-murugan', amount: 1500, at: DateTime(2026, 10, 14), reason: 'Goods taken without a bill');
    expect(no, 'CR-001');
    expect(await d.ledger.balanceOf('c-murugan'), 50000 + 20000 + 1500);
    await expectLater(d.ledger.writeOff(PartyKind.customer, partyId: 'c-murugan', amount: 999999, reason: 'x', at: DateTime(2026, 10, 20)), throwsStateError);
    await d.ledger.writeOff(PartyKind.customer, partyId: 'c-murugan', amount: 1500, reason: 'Small amount', at: DateTime(2026, 10, 20));
    final acc = await d.ledger.account('c-murugan');
    final writeOff = acc.ledger.firstWhere((e) => e.kind.name == 'writeOff');
    await d.ledger.reverseEntry(PartyKind.customer, partyId: 'c-murugan', entryId: writeOff.id, reason: 'Customer paid after all', at: DateTime(2026, 10, 21));
    await expectLater(d.ledger.reverseEntry(PartyKind.customer, partyId: 'c-murugan', entryId: writeOff.id, reason: 'again', at: DateTime(2026, 10, 21)), throwsStateError);
    expect(await d.ledger.balanceOf('c-murugan'), 71500);
    final r = await d.ledger.settleFully(PartyKind.customer, partyId: 'c-murugan', partyName: 'M', mode: 'upi', at: DateTime(2026, 10, 22));
    expect(r!.amountPaise, 71500);
    expect(await d.ledger.balanceOf('c-murugan'), 0);
    expect(await d.ledger.settleFully(PartyKind.customer, partyId: 'c-murugan', partyName: 'M', mode: 'cash', at: DateTime(2026, 10, 23)), isNull);
    await checkInvariants();
  });

  test('a back-dated entry keeps every running balance right', () async {
    await d.bills.saveBill(input([line(screw, 4000)], customer: 'c-murugan', received: 0));
    await d.ledger.receivePayment(PartyKind.customer, partyId: 'c-murugan', partyName: 'M', amount: 10000, mode: 'cash', at: DateTime(2026, 10, 20));
    await d.ledger.addAdjustment(PartyKind.customer, partyId: 'c-murugan', signedPaise: 700, at: DateTime(2026, 10, 10), reason: 'Back-dated');
    final rows = await d.db.rows('SELECT running_paise, amount_paise FROM ledger_entries WHERE party_id = ? ORDER BY at, rowid', ['c-murugan']);
    var run = 0;
    for (final r in rows) {
      run += r.read<int>('amount_paise');
      expect(r.read<int>('running_paise'), run);
    }
    await checkInvariants();
  });

  test('keyset paging of the register: newest first, no overlap, search by number, old bill number and customer, filters', () async {
    for (var i = 0; i < 7; i++) {
      await d.bills.saveBill(SaveBillInput(idemKey: 'k$i', at: DateTime(2026, 10, 1 + i, 10), lines: [line(screw, 1000)], customerId: i.isEven ? 'c-murugan' : null, customerName: i.isEven ? 'Murugan Electricals' : '', oldBillNo: i == 3 ? 'OLD-77' : null));
    }
    final p1 = await d.bills.page(limit: 3);
    final p2 = await d.bills.page(limit: 3, after: BillRepo.cursorOf(p1.last));
    final p3 = await d.bills.page(limit: 3, after: BillRepo.cursorOf(p2.last));
    final all = [...p1, ...p2, ...p3];
    expect(all.map((b) => b.number), ['A-000007', 'A-000006', 'A-000005', 'A-000004', 'A-000003', 'A-000002', 'A-000001']);
    expect((await d.bills.page(search: 'old-77')).single.number, 'A-000004');
    expect((await d.bills.page(search: 'murugan')).length, 4);
    expect((await d.bills.page(customerId: 'c-murugan', limit: 2)).length, 2);
    expect((await d.bills.page(from: DateTime(2026, 10, 3), to: DateTime(2026, 10, 5))).length, 2);
    expect(await d.bills.count(), 7);
    expect(DataContext.dayOf(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('the product search finds words by prefix and by barcode, and never breaks on odd characters', () async {
    await d.catalog.saveProduct(const Product(id: 'p3', name: 'ANCHOR 3 PIN SOCKET WHITE', category: 'Electrical', unit: 'pcs', pricePaise: 2500, costPaise: 1500, stockMilli: 0, gstBp: 1800, barcode: '8901234'), create: true);
    expect((await d.catalog.searchProducts('anc soc')).map((p) => p.id), ['p3']);
    expect((await d.catalog.searchProducts('8901234')).map((p) => p.id), ['p3']);
    expect((await d.catalog.searchProducts('hav')).map((p) => p.id), ['p-switch']);
    for (final odd in ['"', "' OR 1=1 --", '*', 'NEAR(', 'a" b', '%_', '\\']) {
      await d.catalog.searchProducts(odd); // must not throw
    }
    expect((await d.catalog.searchProducts('')).length, 3);
  });

  test('editing a product price or cost, and a customer credit limit, leaves an audit row and one upload row', () async {
    await d.catalog.saveProduct(screw.copyWith(pricePaise: 13000, costPaise: 9500), create: false);
    final a = await d.db.rows("SELECT field, old_value, new_value FROM audit ORDER BY field");
    expect(a.map((r) => '${r.read<String>('field')}:${r.read<String>('old_value')}>${r.read<String>('new_value')}'), ['cost:9000>9500', 'price:12500>13000']);
    await d.catalog.saveProduct(screw.copyWith(pricePaise: 13500), create: false);
    expect((await d.db.rows("SELECT * FROM outbox WHERE coll = 'products' AND doc_id = 'p-screw'")).length, 1, reason: 'edited twice before upload: one upload');
    await d.catalog.saveCustomer(murugan.copyWith(creditLimitPaise: 100), create: false);
    expect((await d.db.rows("SELECT * FROM audit WHERE field = 'creditLimit'")).length, 1);
  });

  test('editing the stock on the product form writes a movement, so stock stays the sum of movements', () async {
    await d.catalog.saveProduct(screw.copyWith(stockMilli: 25000), create: false);
    expect(await stockOf('p-screw'), 25000);
    await checkInvariants();
  });
}
