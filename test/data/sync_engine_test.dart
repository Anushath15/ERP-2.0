import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/records_repo.dart' show EstimateLine;
import 'package:erp2/data/sync/sync_api.dart';
import 'package:erp2/data/sync/sync_engine.dart';
import 'package:erp2/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fake_cloud.dart';
import 'helpers.dart';

// What these tests prove: what one shop computer does reaches the cloud copy and the other computer, without losing anything, in any order,
// with the internet coming and going, and the derived totals agree afterwards.
void main() {
  late FakeCloud cloud;
  late AppData a, b;
  late SyncEngine ea, eb;

  setUp(() {
    cloud = FakeCloud();
    a = memoryShop(device: 'dev-aaaa');
    b = memoryShop(device: 'dev-bbbb');
    ea = SyncEngine(a.cx, cloud.client('dev-aaaa'));
    eb = SyncEngine(b.cx, cloud.client('dev-bbbb'));
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  Product prod(String id, String name, {int stock = 10000}) => sampleProduct(name, id: id, stock: stock, price: 10000);
  BillLineInput line(Product p, int qty) => BillLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: qty, ratePaise: p.pricePaise, gstBp: p.gstBp, discountBp: 0);
  SaveBillInput bill(List<BillLineInput> l, {String key = 'k1', String? customer, int? received}) =>
      SaveBillInput(idemKey: key, at: DateTime(2026, 10, 14, 15, 30), lines: l, customerId: customer, customerName: customer == null ? '' : 'Murugan', receivedPaise: received);

  Future<int> stock(AppData d, String id) async => (await d.catalog.product(id))!.stockMilli;
  Future<int> count(AppData d, String t) => d.db.scalarInt('SELECT COUNT(*) FROM $t');

  test('a product and a bill made on one computer arrive on the other, with stock and totals', () async {
    final p = prod('p1', 'WOOD SCREW');
    await a.catalog.saveProduct(p, create: true);
    final s = await a.bills.saveBill(bill([line(p, 2000)]));
    final r1 = await ea.run();
    expect(r1.pushed, greaterThan(3), reason: 'product, bill, line, movement...');
    expect(await a.db.scalarInt('SELECT COUNT(*) FROM outbox'), 0);
    await eb.run();
    expect(await count(b, 'bills'), 1);
    expect(await count(b, 'bill_lines'), 1);
    expect(await stock(b, 'p1'), 8000, reason: 'the sale movement came too; the stock figure was rebuilt');
    expect((await b.bills.detail(s.id))!.row.number, s.number);
    final day = await b.db.rows("SELECT sales_paise FROM day_totals WHERE day = '2026-10-14'");
    expect(day.single.read<int>('sales_paise'), s.totalPaise);
  });

  test('nothing that came from the cloud is sent back, and a second round with no changes sends nothing', () async {
    await a.catalog.saveProduct(prod('p1', 'X'), create: true);
    await ea.run();
    await eb.run();
    expect(await b.db.scalarInt('SELECT COUNT(*) FROM outbox'), 0, reason: 'applied rows are not queued');
    final before = cloud.pushCalls;
    final r = await eb.run();
    expect(r.pushed, 0);
    expect(cloud.pushCalls, before);
  });

  test('two computers selling the same product: both sales are kept and the stock is the sum of both', () async {
    final p = prod('p1', 'SWITCH');
    await a.catalog.saveProduct(p, create: true);
    await ea.run();
    await eb.run();
    await a.bills.saveBill(bill([line(p, 1000)], key: 'ka'));
    await b.bills.saveBill(bill([line(p, 3000)], key: 'kb'));
    await ea.run();
    await eb.run();
    await ea.run();
    expect(await stock(a, 'p1'), 6000);
    expect(await stock(b, 'p1'), 6000);
    expect(await count(a, 'bills'), 2);
    expect(await count(b, 'bills'), 2);
    final numbers = (await b.db.rows('SELECT number FROM bills ORDER BY number')).map((r) => r.read<String>('number')).toList();
    expect(numbers.toSet().length, 2, reason: 'both bills were numbered the same offline: the arriving one got a suffix, none is lost');
  });

  test('offline: changes wait, nothing is lost or repeated, and go when the internet is back', () async {
    final p = prod('p1', 'X');
    await a.catalog.saveProduct(p, create: true);
    cloud.offline = true;
    await a.bills.saveBill(bill([line(p, 1000)]));
    await expectLater(ea.run(), throwsA(isA<SyncOffline>()));
    expect(await a.db.scalarInt('SELECT COUNT(*) FROM outbox'), greaterThan(0));
    cloud.offline = false;
    await ea.run();
    expect(await a.db.scalarInt('SELECT COUNT(*) FROM outbox'), 0);
    expect(cloud.docs.keys.where((k) => k.startsWith('bills/')).length, 1);
  });

  test('a newer edit wins on the other computer, and an older copy arriving later never overwrites a newer one', () async {
    final p = prod('p1', 'OLD NAME');
    await a.catalog.saveProduct(p, create: true);
    await ea.run();
    await eb.run();
    await a.catalog.saveProduct(p.copyWith(name: 'NEW NAME'), create: false);
    await ea.run();
    await eb.run();
    expect((await b.catalog.product('p1'))!.name, 'NEW NAME');
    await b.catalog.saveProduct((await b.catalog.product('p1'))!.copyWith(name: 'B NAME'), create: false);
    await eb.run();
    await ea.run();
    expect((await a.catalog.product('p1'))!.name, 'B NAME');
  });

  test('a document the cloud refuses is set aside as needs-attention; the rest of its batch still goes', () async {
    await a.catalog.saveProduct(prod('p1', 'GOOD'), create: true);
    await a.catalog.saveProduct(prod('p2', 'BAD'), create: true);
    cloud.reject = (d) => d.coll == 'products' && d.id == 'p2';
    await ea.run();
    expect(cloud.docs.containsKey('products/p1'), isTrue);
    expect(cloud.docs.containsKey('products/p2'), isFalse);
    final att = await a.db.rows("SELECT doc_id, last_error FROM outbox WHERE state = 'attention'");
    expect(att.single.read<String>('doc_id'), 'p2');
    expect((await a.outbox.counts()).attention, 1);
  });

  test('paging: more documents than one page are all pulled', () async {
    for (var i = 0; i < 25; i++) {
      await a.catalog.saveProduct(prod('p$i', 'ITEM $i'), create: true);
    }
    await ea.run();
    final small = SyncEngine(b.cx, cloud.client('dev-bbbb'), pullLimit: 10, batch: 7);
    await small.run();
    expect(await count(b, 'products'), 25);
  });

  test('a shop that already had data before sync was switched on uploads it all once', () async {
    await a.catalog.saveProduct(prod('p1', 'OLD STOCK'), create: true);
    await a.db.exec('DELETE FROM outbox');
    await ea.run();
    expect(cloud.docs.containsKey('products/p1'), isTrue);
  });

  test('a credit sale: the customer balance agrees on both computers', () async {
    final c = sampleCustomer('Murugan', id: 'c1');
    await a.catalog.saveCustomer(c, create: true);
    final p = prod('p1', 'X');
    await a.catalog.saveProduct(p, create: true);
    await a.bills.saveBill(bill([line(p, 1000)], customer: 'c1', received: 0));
    await ea.run();
    await eb.run();
    final x = await a.db.rows("SELECT balance_paise FROM party_balance WHERE party_id = 'c1'");
    final y = await b.db.rows("SELECT balance_paise FROM party_balance WHERE party_id = 'c1'");
    expect(y.single.read<int>('balance_paise'), x.single.read<int>('balance_paise'));
    expect(x.single.read<int>('balance_paise'), greaterThan(0));
  });

  test('two computers both gave an estimate the number EST-00001: both are kept, and each can carry on saving (it once failed with "something went wrong")', () async {
    const line = EstimateLine(productId: 'p1', name: 'X', unit: 'pcs', qtyMilli: 1000, ratePaise: 10000);
    await a.catalog.saveProduct(prod('p1', 'X'), create: true);
    await ea.run();
    await eb.run();
    final ea1 = await a.estimations.save(lines: const [line], totalPaise: 10000, customerName: '', at: DateTime(2026, 10, 20));
    final eb1 = await b.estimations.save(lines: const [line], totalPaise: 20000, customerName: '', at: DateTime(2026, 10, 20));
    expect((ea1.number, eb1.number), ('EST-00001', 'EST-00001'));
    await ea.run();
    await eb.run();
    await ea.run();
    expect(await count(a, 'estimations'), 2);
    expect(await count(b, 'estimations'), 2);
    // the counter of each computer is now past what exists, so the next estimate saves
    final ea2 = await a.estimations.save(lines: const [line], totalPaise: 30000, customerName: '', at: DateTime(2026, 10, 20));
    final eb2 = await b.estimations.save(lines: const [line], totalPaise: 40000, customerName: '', at: DateTime(2026, 10, 20));
    expect(ea2.number, isNot(ea1.number));
    expect(await a.estimations.peekNextNumber(), isNot(ea2.number));
    expect(eb2.number, isNot(eb1.number));
    await ea.run();
    await eb.run();
    await ea.run();
    expect(await count(a, 'estimations'), 4);
    expect(await count(b, 'estimations'), 4);
  });

  test('a counter that is behind the numbers that exist (restore, import) skips forward instead of failing the save', () async {
    const line = EstimateLine(productId: 'p1', name: 'X', unit: 'pcs', qtyMilli: 1000, ratePaise: 10000);
    await a.catalog.saveProduct(prod('p1', 'X'), create: true);
    await a.db.exec("INSERT INTO estimations(id, number, at, total_paise, created_at, updated_at, device_id) VALUES ('old1', 'EST-00001', 1, 1, 1, 1, 'dev-x')");
    await a.db.exec("INSERT INTO estimations(id, number, at, total_paise, created_at, updated_at, device_id) VALUES ('old2', 'EST-00002', 1, 1, 1, 1, 'dev-x')");
    expect(await a.estimations.peekNextNumber(), 'EST-00003');
    final e = await a.estimations.save(lines: const [line], totalPaise: 10000, customerName: '', at: DateTime(2026, 10, 20));
    expect(e.number, 'EST-00003');
  });
}
