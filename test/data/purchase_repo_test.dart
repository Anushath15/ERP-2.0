import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/purchase_repo.dart';
import 'package:erp2/data/repo/rebuild.dart';
import 'package:erp2/data/repo/self_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// Purchases from dealers: items, stock, the dealer's account, rates remembered per product.
void main() {
  late AppData d;
  setUp(() async {
    d = memoryShop();
    await d.catalog.saveProduct(sampleProduct('Bulb', price: 9000, cost: 6000, stock: 10000, id: 'p1', gst: 1800), create: true);
    await d.catalog.saveProduct(sampleProduct('Plug', price: 5000, cost: 3000, stock: 0, id: 'p2', gst: 1800), create: true);
    await d.db.exec("INSERT INTO dealers(id, name, created_at, updated_at, device_id) VALUES ('d1','Sakthi',1,1,'x'), ('d2','Pandian',1,1,'x')");
  });
  tearDown(() => d.close());

  PurchaseLineInput line(String p, int qty, int rate) => PurchaseLineInput(productId: p, name: p, unit: 'pcs', qtyMilli: qty, ratePaise: rate, gstBp: 1800);
  SavePurchaseInput input(String key, String dealer, List<PurchaseLineInput> lines, {int paid = 0, bool received = true, bool updateCost = true, DateTime? at}) =>
      SavePurchaseInput(idemKey: key, dealerId: dealer, at: at ?? DateTime(2026, 10, 10, 10), lines: lines, invoiceNo: 'INV/1', paidPaise: paid, received: received, updateCost: updateCost);
  Future<int> stock(String id) async => (await d.catalog.product(id))!.stockMilli;

  test('a received purchase: stock in, the buying price follows, the unpaid part is on the dealer account, totals add up with GST', () async {
    final s = await d.purchases.savePurchase(input('a', 'd1', [line('p1', 10000, 5500), line('p2', 4000, 2500)], paid: 20000));
    // 10 x 55.00 = 550.00 + 18% = 649.00 ; 4 x 25.00 = 100.00 + 18% = 118.00 ; total 767.00
    expect(s.totalPaise, 76700);
    expect(s.number, 'PUR-00001');
    expect(s.received, isTrue);
    expect(await stock('p1'), 20000);
    expect(await stock('p2'), 4000);
    expect((await d.catalog.product('p1'))!.costPaise, 5500, reason: 'the new rate became the buying price');
    expect(await d.ledger.balanceOf('d1'), 76700 - 20000, reason: 'what is still unpaid is owed to the dealer');
    expect((await d.db.rows("SELECT * FROM outbox WHERE coll = 'purchases'")).length, 1);
    expect(await selfCheck(d.db, deep: true), isEmpty);
  });

  test('a pending purchase changes nothing until it is received; then stock and the dealer account move', () async {
    final s = await d.purchases.savePurchase(input('b', 'd1', [line('p1', 5000, 5000)], received: false));
    expect(await stock('p1'), 10000);
    expect(await d.ledger.balanceOf('d1'), 0);
    expect((await d.catalog.product('p1'))!.costPaise, 6000);
    expect(await d.purchases.markReceived(s.id, at: DateTime(2026, 10, 12)), isTrue);
    expect(await d.purchases.markReceived(s.id), isFalse, reason: 'a second time does nothing');
    expect(await stock('p1'), 15000);
    expect(await d.ledger.balanceOf('d1'), s.totalPaise);
    expect((await d.purchases.detail(s.id))!.row.received, isTrue);
    expect(await selfCheck(d.db, deep: true), isEmpty);
  });

  test('keeping the old buying price when asked; refusing bad input; the same key is saved once', () async {
    await d.purchases.savePurchase(input('c', 'd1', [line('p1', 1000, 7000)], updateCost: false, paid: 8260));
    expect((await d.catalog.product('p1'))!.costPaise, 6000);
    await expectLater(d.purchases.savePurchase(input('x', 'd1', [])), throwsArgumentError);
    await expectLater(d.purchases.savePurchase(input('x', 'd1', [line('p1', 0, 100)])), throwsArgumentError);
    await expectLater(d.purchases.savePurchase(input('x', 'd1', [line('p1', 1000, 100)], paid: 999999)), throwsArgumentError);
    await expectLater(d.purchases.savePurchase(input('x', 'nobody', [line('p1', 1000, 100)])), throwsStateError);
    final a = await d.purchases.savePurchase(input('same', 'd1', [line('p1', 1000, 100)]));
    final again = await d.purchases.savePurchase(input('same', 'd1', [line('p1', 1000, 100)]));
    expect(again.replay, isTrue);
    expect(again.id, a.id);
    expect((await d.purchases.list()).length, 2);
  });

  test('rates remembered: the rate paid the time before, and a cheaper dealer for the same product', () async {
    await d.purchases.savePurchase(input('r1', 'd1', [line('p1', 1000, 6000)], at: DateTime(2026, 9, 1)));
    await d.purchases.savePurchase(input('r2', 'd2', [line('p1', 1000, 5200)], at: DateTime(2026, 9, 15)));
    final third = await d.purchases.savePurchase(input('r3', 'd1', [line('p1', 1000, 5800)], at: DateTime(2026, 10, 1)));
    final l = (await d.purchases.detail(third.id))!.lines.single;
    expect(l.lastBefore!.ratePaise, 5200, reason: 'the time before, from the other dealer');
    expect(l.lastBefore!.dealerName, 'Pandian');
    expect(l.cheaper!.dealerName, 'Pandian');
    expect(l.cheaper!.ratePaise, 5200);
    expect(l.sellingPaise, 8700, reason: 'the selling price the shop marked, moved with the buying price (60 -> 52 -> 58) keeping the margin');
    final first = (await d.purchases.detail((await d.purchases.idOfNumber('PUR-00001'))!))!;
    expect(first.lines.single.lastBefore, isNull);
    expect(first.lines.single.cheaper!.dealerName, 'Pandian', reason: 'another dealer sold it cheaper later: still worth knowing');
    final h = await d.purchases.rateHints('p1', dealerId: 'd1', ratePaise: 6100);
    expect(h.last!.ratePaise, 5800);
    expect(h.cheaper!.ratePaise, 5200);
    expect((await d.purchases.rateHints('p2', dealerId: 'd1', ratePaise: 100)).last, isNull);
  });

  test('dealer summary and the list per dealer', () async {
    await d.purchases.savePurchase(input('s1', 'd1', [line('p1', 1000, 1000)], paid: 1180, at: DateTime(2026, 10, 1)));
    await d.purchases.savePurchase(input('s2', 'd1', [line('p2', 1000, 2000)], received: false, at: DateTime(2026, 10, 5)));
    await d.purchases.savePurchase(input('s3', 'd2', [line('p2', 1000, 3000)]));
    final sum = await d.purchases.dealerSummary('d1');
    expect(sum.purchases, 2);
    expect(sum.pending, 1);
    expect(sum.boughtPaise, 1180, reason: 'only received purchases count as bought');
    expect(sum.lastAt, DateTime(2026, 10, 5));
    expect((await d.purchases.list(dealerId: 'd1')).map((r) => r.number), ['PUR-00002', 'PUR-00001']);
    expect((await d.purchases.list()).length, 3);
  });

  test('Recalculate keeps the stock and the dealer balances', () async {
    await d.purchases.savePurchase(input('q1', 'd1', [line('p1', 3000, 5000)], paid: 100));
    final stockBefore = await stock('p1');
    final balBefore = await d.ledger.balanceOf('d1');
    await rebuildSummaries(d.db);
    expect(await stock('p1'), stockBefore);
    expect(await d.ledger.balanceOf('d1'), balBefore);
  });
}
