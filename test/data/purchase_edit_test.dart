import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/purchase_repo.dart';
import 'package:erp2/data/repo/purchase_return_repo.dart';
import 'package:erp2/data/repo/rebuild.dart';
import 'package:erp2/data/repo/self_check.dart';
import 'package:erp2/domain/credit/account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fake_cloud.dart';
import 'helpers.dart';
import 'package:erp2/data/sync/sync_engine.dart';

// What these tests prove: a saved purchase can be edited and every figure stays right: stock moves by the difference, the dealer account and the bill-wise due agree
// with the new total, the buying price follows a changed rate, the summaries still equal the raw rows, an edit that cannot be right is refused, and the other
// computer ends up with the same items.
void main() {
  late AppData d;
  setUp(() async {
    d = memoryShop();
    await d.catalog.saveProduct(sampleProduct('Bulb', price: 9000, cost: 6000, stock: 10000, id: 'p1', gst: 1800), create: true);
    await d.catalog.saveProduct(sampleProduct('Plug', price: 5000, cost: 3000, stock: 0, id: 'p2', gst: 1800), create: true);
    await d.catalog.saveProduct(sampleProduct('Switch', price: 7000, cost: 4000, stock: 0, id: 'p3', gst: 1800), create: true);
    await d.db.exec("INSERT INTO dealers(id, name, created_at, updated_at, device_id) VALUES ('d1','Sakthi',1,1,'x'), ('d2','Pandian',1,1,'x')");
  });
  tearDown(() => d.close());

  PurchaseLineInput line(String p, int qty, int rate) => PurchaseLineInput(productId: p, name: p, unit: 'pcs', qtyMilli: qty, ratePaise: rate, gstBp: 1800);
  SavePurchaseInput input(List<PurchaseLineInput> lines, {String key = 'k', String dealer = 'd1', int paid = 0, bool received = true, bool updateCost = true, String invoice = 'INV/1', String note = ''}) =>
      SavePurchaseInput(idemKey: key, dealerId: dealer, at: DateTime(2026, 10, 10, 10), lines: lines, invoiceNo: invoice, paidPaise: paid, received: received, updateCost: updateCost, note: note);
  Future<int> stock(String id) async => (await d.catalog.product(id))!.stockMilli;
  Future<void> checks() async {
    expect(await selfCheck(d.db, deep: true), isEmpty);
    final before = (await d.db.rows('SELECT bill_no, total_paise, paid_paise, cancelled FROM party_bills ORDER BY party_id, bill_no')).map((r) => '${r.read<String>('bill_no')}|${r.read<int>('total_paise')}|${r.read<int>('paid_paise')}|${r.read<int>('cancelled')}').toList();
    final bal = (await d.db.rows('SELECT party_id, balance_paise FROM party_balance ORDER BY party_id')).map((r) => '${r.read<String>('party_id')}|${r.read<int>('balance_paise')}').toList();
    await rebuildSummaries(d.db);
    final after = (await d.db.rows('SELECT bill_no, total_paise, paid_paise, cancelled FROM party_bills ORDER BY party_id, bill_no')).map((r) => '${r.read<String>('bill_no')}|${r.read<int>('total_paise')}|${r.read<int>('paid_paise')}|${r.read<int>('cancelled')}').toList();
    expect(after, before, reason: 'the bill-wise dues equal what the ledger says');
    expect((await d.db.rows('SELECT party_id, balance_paise FROM party_balance ORDER BY party_id')).map((r) => '${r.read<String>('party_id')}|${r.read<int>('balance_paise')}').toList(), bal);
  }

  test('a pending purchase is simply replaced: the same number, new items, no stock and no account yet', () async {
    final s = await d.purchases.savePurchase(input([line('p1', 5000, 5000)], received: false));
    final e = await d.purchases.editPurchase(s.id, input([line('p2', 2000, 2500), line('p3', 1000, 4000)], received: false, invoice: 'INV/9', note: 'changed'));
    expect(e.number, s.number);
    final det = (await d.purchases.detail(s.id))!;
    expect(det.lines.map((l) => l.productId), ['p2', 'p3']);
    expect(det.row.invoiceNo, 'INV/9');
    expect(det.note, 'changed');
    expect(det.row.received, isFalse);
    expect(await stock('p1'), 10000);
    expect(await stock('p2'), 0);
    expect(await d.ledger.balanceOf('d1'), 0);
    expect(await d.db.scalarInt('SELECT line_count FROM purchases WHERE id = ?', [s.id]), 2);
    await checks();
  });

  test('a received purchase: quantity up, one item removed, one added, a rate changed, more paid: stock by the difference, account and due agree, cost follows', () async {
    final s = await d.purchases.savePurchase(input([line('p1', 10000, 5500), line('p2', 4000, 2500)], paid: 20000));
    expect(s.totalPaise, 76700);
    expect(await stock('p1'), 20000);
    expect(await stock('p2'), 4000);
    expect(await d.ledger.balanceOf('d1'), 56700);
    // p1 12 pieces at 60.00, p2 removed, p3 3 pieces at 40.00, 300.00 paid
    final e = await d.purchases.editPurchase(s.id, input([line('p1', 12000, 6000), line('p3', 3000, 4000)], paid: 30000));
    expect(e.number, 'PUR-00001');
    // 12 x 60 = 720 + 18% = 849.60 ; 3 x 40 = 120 + 18% = 141.60 ; total 991.20
    expect(e.totalPaise, 99120);
    expect(await stock('p1'), 22000, reason: '12 now instead of 10: +2');
    expect(await stock('p2'), 0, reason: 'the item that was removed went out again');
    expect(await stock('p3'), 3000);
    expect((await d.catalog.product('p1'))!.costPaise, 6000, reason: 'the changed rate became the buying price');
    expect((await d.catalog.product('p3'))!.costPaise, 4000);
    expect(await d.ledger.balanceOf('d1'), 99120 - 30000, reason: 'owed = new total - paid');
    final due = (await d.ledger.dues('d1')).single;
    expect((due.totalPaise, due.outstanding), (99120, 99120 - 30000));
    expect(await d.db.scalarInt("SELECT COUNT(*) FROM audit WHERE what = 'purchaseEdit'"), 1);
    await checks();
  });

  test('edits that lower what is owed (cheaper, paid in full) and raise it again keep the account and the due exact', () async {
    final s = await d.purchases.savePurchase(input([line('p1', 10000, 5000)])); // 590.00 owed
    expect(await d.ledger.balanceOf('d1'), 59000);
    await d.purchases.editPurchase(s.id, input([line('p1', 10000, 4000)])); // 472.00
    expect(await d.ledger.balanceOf('d1'), 47200);
    await checks();
    await d.purchases.editPurchase(s.id, input([line('p1', 10000, 4000)], paid: 47200)); // paid in full
    expect(await d.ledger.balanceOf('d1'), 0);
    expect((await d.ledger.dues('d1')).single.outstanding, 0);
    await checks();
    await d.purchases.editPurchase(s.id, input([line('p1', 20000, 4000)], paid: 47200)); // twice as many, same money paid
    expect(await d.ledger.balanceOf('d1'), 94400 - 47200);
    expect((await d.ledger.dues('d1')).single.outstanding, 47200);
    await checks();
  });

  test('a payment made to the dealer since then counts: the total cannot go below what has been paid', () async {
    final s = await d.purchases.savePurchase(input([line('p1', 10000, 5000)])); // 590.00 owed
    await d.ledger.receivePayment(PartyKind.dealer, partyId: 'd1', partyName: 'Sakthi', amount: 40000, mode: 'cash', at: DateTime(2026, 10, 12));
    await expectLater(d.purchases.editPurchase(s.id, input([line('p1', 5000, 5000)])), throwsA(isA<StateError>())); // 295.00 < 400.00 paid since
    expect(await stock('p1'), 20000, reason: 'the refused edit changed nothing');
    expect(await d.ledger.balanceOf('d1'), 59000 - 40000);
    final ok = await d.purchases.editPurchase(s.id, input([line('p1', 10000, 4500)])); // 531.00 >= 400.00
    expect(ok.totalPaise, 53100);
    expect(await d.ledger.balanceOf('d1'), 53100 - 40000);
    await checks();
  });

  test('a purchase with a return keeps its items; the invoice number and the note can still change', () async {
    final s = await d.purchases.savePurchase(input([line('p1', 10000, 5000)]));
    final lineId = (await d.db.rows('SELECT id FROM purchase_lines WHERE purchase_id = ?', [s.id])).single.read<String>('id');
    await d.purchaseReturns.saveReturn(SavePurchaseReturnInput(idemKey: 'r', purchaseId: s.id, at: DateTime(2026, 10, 11), lines: {lineId: 2000}, reason: 'Damaged'));
    await expectLater(d.purchases.editPurchase(s.id, input([line('p1', 5000, 5000)])), throwsA(isA<StateError>()));
    final e = await d.purchases.editPurchase(s.id, input([line('p1', 10000, 5000)], invoice: 'INV/77', note: 'corrected number'));
    expect(e.number, s.number);
    final det = (await d.purchases.detail(s.id))!;
    expect((det.row.invoiceNo, det.note), ('INV/77', 'corrected number'));
    expect(det.lines.single.qtyMilli, 10000);
    await checks();
  });

  test('the dealer cannot be changed, and the usual checks apply (items, rates, money paid)', () async {
    final s = await d.purchases.savePurchase(input([line('p1', 1000, 5000)]));
    await expectLater(d.purchases.editPurchase(s.id, input([line('p1', 1000, 5000)], dealer: 'd2')), throwsA(isA<StateError>()));
    await expectLater(d.purchases.editPurchase(s.id, input(const [])), throwsA(isA<ArgumentError>()));
    await expectLater(d.purchases.editPurchase(s.id, input([line('p1', 1000, 5000)], paid: 999999)), throwsA(isA<ArgumentError>()));
    await expectLater(d.purchases.editPurchase('nope', input([line('p1', 1000, 5000)])), throwsA(isA<StateError>()));
  });

  test('the other computer gets the edit: the removed item is gone and the dues are the same', () async {
    final cloud = FakeCloud();
    final b = memoryShop(device: 'dev-b');
    addTearDown(b.close);
    final ea = SyncEngine(d.cx, cloud.client('dev-a')), eb = SyncEngine(b.cx, cloud.client('dev-b'));
    final s = await d.purchases.savePurchase(input([line('p1', 10000, 5500), line('p2', 4000, 2500), line('p3', 1000, 4000)], paid: 20000));
    await ea.run();
    await eb.run();
    expect(await b.db.scalarInt('SELECT COUNT(*) FROM purchase_lines'), 3);
    await d.purchases.editPurchase(s.id, input([line('p1', 12000, 6000), line('p3', 2000, 4000)], paid: 30000));
    await ea.run();
    await eb.run();
    expect(await b.db.scalarInt('SELECT COUNT(*) FROM purchase_lines'), 2, reason: 'the item that was removed is gone on the other computer too');
    List<String> lines(AppData x) => [];
    expect(lines(d), isEmpty);
    final onA = (await d.db.rows('SELECT line_no, product_id, qty_milli FROM purchase_lines ORDER BY line_no')).map((r) => '${r.read<int>('line_no')}|${r.read<String>('product_id')}|${r.read<int>('qty_milli')}').toList();
    final onB = (await b.db.rows('SELECT line_no, product_id, qty_milli FROM purchase_lines ORDER BY line_no')).map((r) => '${r.read<int>('line_no')}|${r.read<String>('product_id')}|${r.read<int>('qty_milli')}').toList();
    expect(onB, onA);
    expect((await b.ledger.dues('d1')).map((x) => '${x.billNo}|${x.totalPaise}|${x.paidPaise}'), (await d.ledger.dues('d1')).map((x) => '${x.billNo}|${x.totalPaise}|${x.paidPaise}'));
    expect(await b.ledger.balanceOf('d1'), await d.ledger.balanceOf('d1'));
    expect(await b.catalog.product('p1').then((p) => p!.stockMilli), await d.catalog.product('p1').then((p) => p!.stockMilli));
  });
}
