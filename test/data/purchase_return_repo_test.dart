import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/purchase_repo.dart';
import 'package:erp2/data/repo/purchase_return_repo.dart';
import 'package:erp2/data/repo/rebuild.dart';
import 'package:erp2/data/repo/self_check.dart';
import 'package:erp2/domain/credit/ledger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// Giving goods back to a dealer from a received purchase: stock out, the dealer's account, the refund.
void main() {
  late AppData d;
  setUp(() async {
    d = memoryShop();
    await d.catalog.saveProduct(sampleProduct('Bulb', price: 9000, cost: 6000, stock: 0, id: 'p1', gst: 1800), create: true);
    await d.db.exec("INSERT INTO dealers(id, name, created_at, updated_at, device_id) VALUES ('d1','Sakthi',1,1,'x')");
  });
  tearDown(() => d.close());

  /// 10 bulbs at 50.00 + 18% GST = 590.00
  Future<SavedPurchase> buy({String key = 'a', int paid = 0, bool received = true, int qty = 10000}) => d.purchases.savePurchase(SavePurchaseInput(
      idemKey: key, dealerId: 'd1', at: DateTime(2026, 10, 10), lines: [PurchaseLineInput(productId: 'p1', name: 'Bulb', unit: 'pcs', qtyMilli: qty, ratePaise: 5000, gstBp: 1800)], paidPaise: paid, received: received));
  SavePurchaseReturnInput ret(String purchaseId, Map<String, int> lines, {String key = 'r1', int mode = 0, bool credit = false}) =>
      SavePurchaseReturnInput(idemKey: key, purchaseId: purchaseId, at: DateTime(2026, 10, 12), lines: lines, reason: 'Faulty', refundMode: mode, keepAsCredit: credit);
  Future<PurchaseReturnable> view(String id) async => (await d.purchaseReturns.returnable(id))!;
  Future<int> stock() async => (await d.catalog.product('p1'))!.stockMilli;
  Future<void> clean() async => expect(await selfCheck(d.db, deep: true), isEmpty);

  test('part of a purchase on credit goes back: stock out, taken off what the shop owes, nothing paid back', () async {
    final p = await buy();
    expect(await d.ledger.balanceOf('d1'), 59000);
    final lineId = (await view(p.id)).lines.single.purchaseLineId;
    final r = await d.purchaseReturns.saveReturn(ret(p.id, {lineId: 4000}));
    expect(r.number, 'PRT-0001');
    expect(r.totalPaise, 23600, reason: '4 of 10 bulbs: 236.00');
    expect(r.dueReducedPaise, 23600);
    expect(r.refundedPaise, 0);
    expect(await stock(), 6000);
    expect(await d.ledger.balanceOf('d1'), 59000 - 23600);
    expect((await d.ledger.account('d1')).ledger.last.kind, LedgerKind.returnCredit);
    expect((await d.db.rows("SELECT * FROM outbox WHERE coll = 'purchaseReturns'")).length, 1);
    expect((await view(p.id)).lines.single.remainingMilli, 6000);
    await clean();
  });

  test('a paid purchase: the dealer pays the money back; or it is kept as credit with the dealer', () async {
    final p = await buy(paid: 59000);
    final lineId = (await view(p.id)).lines.single.purchaseLineId;
    final a = await d.purchaseReturns.saveReturn(ret(p.id, {lineId: 2000}, key: 'r1', mode: 1));
    expect(a.refundedPaise, 11800);
    expect(a.dueReducedPaise, 0);
    expect(await d.ledger.balanceOf('d1'), 0, reason: 'nothing was owed, and the money came back');
    final b = await d.purchaseReturns.saveReturn(ret(p.id, {lineId: 2000}, key: 'r2', credit: true));
    expect(b.creditKeptPaise, 11800);
    expect(b.refundedPaise, 0);
    expect(await d.ledger.balanceOf('d1'), -11800, reason: 'the dealer holds 118.00 of credit for the shop');
    await clean();
  });

  test('two parts add up to exactly the purchase; more than what is left or in stock is refused', () async {
    final p = await buy(qty: 3000);
    final lineId = (await view(p.id)).lines.single.purchaseLineId;
    final total = p.totalPaise;
    final a = await d.purchaseReturns.saveReturn(ret(p.id, {lineId: 1000}, key: 'r1'));
    final b = await d.purchaseReturns.saveReturn(ret(p.id, {lineId: 2000}, key: 'r2'));
    expect(a.totalPaise + b.totalPaise, total);
    expect((await view(p.id)).anythingLeft, isFalse);
    await expectLater(d.purchaseReturns.saveReturn(ret(p.id, {lineId: 1000}, key: 'r3')), throwsStateError);
    await clean();
  });

  test('goods already sold cannot go back: only what is in stock', () async {
    final p = await buy(qty: 5000);
    final lineId = (await view(p.id)).lines.single.purchaseLineId;
    await d.db.exec("UPDATE stock_cache SET qty_milli = 2000 WHERE product_id = 'p1'"); // most of it was sold
    final v = await view(p.id);
    expect(v.lines.single.maxNowMilli, 2000);
    await expectLater(d.purchaseReturns.saveReturn(ret(p.id, {lineId: 3000})), throwsStateError);
    expect((await d.purchaseReturns.list()), isEmpty);
  });

  test('a pending purchase cannot be returned from; the same key is saved once; a reason is needed', () async {
    final pending = await buy(key: 'p', received: false);
    final lineP = (await view(pending.id)).lines.single.purchaseLineId;
    await expectLater(d.purchaseReturns.saveReturn(ret(pending.id, {lineP: 1000})), throwsStateError);
    final p = await buy(key: 'q');
    final lineId = (await view(p.id)).lines.single.purchaseLineId;
    final a = await d.purchaseReturns.saveReturn(ret(p.id, {lineId: 1000}));
    final again = await d.purchaseReturns.saveReturn(ret(p.id, {lineId: 1000}));
    expect(again.replay, isTrue);
    expect(again.id, a.id);
    expect(await stock(), 9000);
    await expectLater(d.purchaseReturns.saveReturn(SavePurchaseReturnInput(idemKey: 'z', purchaseId: p.id, at: DateTime(2026, 10, 12), lines: {lineId: 1000}, reason: ' ')), throwsArgumentError);
  });

  test('the preview equals what is saved; lookup by number; the list; Recalculate keeps the figures', () async {
    final p = await buy(paid: 20000);
    final v = await view(p.id);
    final lineId = v.lines.single.purchaseLineId;
    final preview = PurchaseReturnRepo.preview(v, {lineId: 5000});
    final r = await d.purchaseReturns.saveReturn(ret(p.id, {lineId: 5000}));
    expect(preview.total, r.totalPaise);
    expect(preview.dueReduced, r.dueReducedPaise);
    expect(preview.refunded, r.refundedPaise);
    expect(await d.purchaseReturns.purchaseIdByNumber(p.number.toLowerCase()), p.id);
    expect(await d.purchaseReturns.purchaseIdByNumber('nope'), isNull);
    expect((await d.purchaseReturns.list()).single.number, 'PRT-0001');
    expect(await d.purchaseReturns.returnedTotal(p.id), r.totalPaise);
    final stockBefore = await stock();
    final balBefore = await d.ledger.balanceOf('d1');
    await rebuildSummaries(d.db);
    expect(await stock(), stockBefore);
    expect(await d.ledger.balanceOf('d1'), balBefore);
    await clean();
  });
}
