import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/rebuild.dart';
import 'package:erp2/data/repo/return_repo.dart';
import 'package:erp2/data/repo/self_check.dart';
import 'package:erp2/domain/credit/ledger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// A sales return from a saved bill: stock back, the customer's debt or a refund, the day totals of the return day,
// and everything in one transaction. See lib/data/repo/return_repo.dart for the rules.
void main() {
  late AppData d;
  const bulb = 'p-bulb', plug = 'p-plug';
  final billDay = DateTime(2026, 10, 15, 10);
  final returnDay = DateTime(2026, 10, 17, 11);

  setUp(() async {
    d = memoryShop();
    await d.catalog.saveProduct(sampleProduct('12v bulb', price: 9000, cost: 6000, stock: 50000, id: bulb, gst: 1800), create: true);
    await d.catalog.saveProduct(sampleProduct('Plug', price: 3333, cost: 2000, stock: 50000, id: plug, gst: 1800), create: true);
    await d.catalog.saveCustomer(sampleCustomer('Murugan', id: 'c1'), create: true);
  });
  tearDown(() => d.close());

  BillLineInput line(String p, int qty, int rate, {int cost = 0}) => BillLineInput(productId: p, name: p, unit: 'pcs', qtyMilli: qty, ratePaise: rate, gstBp: 1800, costPaise: cost);
  Future<SavedBill> bill(List<BillLineInput> lines, {String key = 'b1', String? customer, int? received, int mode = 0}) =>
      d.bills.saveBill(SaveBillInput(idemKey: key, at: billDay, lines: lines, customerId: customer, customerName: customer == null ? '' : 'Murugan', receivedPaise: received, payMode: mode));
  Future<ReturnableBill> view(String billId) async => (await d.returns.returnable(billId))!;
  SaveReturnInput ret(String billId, Map<String, int> lines, {String key = 'r1', int mode = 0, bool credit = false, DateTime? at}) =>
      SaveReturnInput(idemKey: key, billId: billId, at: at ?? returnDay, lines: lines, reason: 'Not working', refundMode: mode, keepAsCredit: credit);
  Future<int> stock(String id) async => (await d.catalog.product(id))!.stockMilli;
  Future<void> clean() async => expect(await selfCheck(d.db, deep: true), isEmpty);

  Future<Map<String, List<String>>> summaries() async {
    final out = <String, List<String>>{};
    for (final t in ['stock_cache', 'party_balance', 'day_totals', 'product_month']) {
      final r = await d.db.rows('SELECT * FROM $t');
      out[t] = [for (final x in r) x.data.entries.map((e) => '${e.key}=${e.value}').toList().join('|')]..sort();
    }
    return out;
  }

  test('a walk-in bill: part of one line comes back; stock up, cash refunded, return-day totals down, bill and its day unchanged', () async {
    final s = await bill([line(bulb, 4000, 9000, cost: 6000)]); // 4 bulbs, 360.00
    final v = await view(s.id);
    expect(v.lines.single.remainingMilli, 4000);
    final stockBefore = await stock(bulb);
    final r = await d.returns.saveReturn(ret(s.id, {v.lines.single.billLineId: 1000}));
    expect(r.number, 'SRT-0001');
    expect(r.totalPaise, 9000, reason: 'one bulb is a quarter of the line');
    expect(r.refundedPaise, 9000);
    expect(r.dueReducedPaise, 0);
    expect(await stock(bulb), stockBefore + 1000);
    final billDayRow = (await d.db.rows("SELECT * FROM day_totals WHERE day = '2026-10-15'")).single;
    expect(billDayRow.read<int>('sales_paise'), 36000, reason: 'the bill day is not changed');
    final retDay = (await d.db.rows("SELECT * FROM day_totals WHERE day = '2026-10-17'")).single;
    expect(retDay.read<int>('sales_paise'), -9000);
    expect(retDay.read<int>('cash_paise'), -9000);
    expect(retDay.read<int>('bills'), 0);
    expect((await view(s.id)).lines.single.remainingMilli, 3000);
    expect((await d.db.rows('SELECT * FROM outbox WHERE coll = ?', ['salesReturns'])).length, 1);
    await clean();
  });

  test('returning in two parts adds up exactly and the last part brings back the bill round-off', () async {
    final s = await bill([line(plug, 3000, 3333)]); // 3 plugs: 99.99 + gst-inclusive, rounded to the rupee
    final total = s.totalPaise;
    final v = await view(s.id);
    final id = v.lines.single.billLineId;
    final a = await d.returns.saveReturn(ret(s.id, {id: 1000}, key: 'r1'));
    final b = await d.returns.saveReturn(ret(s.id, {id: 2000}, key: 'r2'));
    expect(a.totalPaise + b.totalPaise, total, reason: 'the customer gets back exactly what the bill charged');
    expect(a.number, 'SRT-0001');
    expect(b.number, 'SRT-0002');
    expect((await view(s.id)).anythingLeft, isFalse);
    await clean();
  });

  test('more than what is left is refused and nothing is written', () async {
    final s = await bill([line(bulb, 2000, 9000)]);
    final id = (await view(s.id)).lines.single.billLineId;
    await d.returns.saveReturn(ret(s.id, {id: 1500}, key: 'r1'));
    await expectLater(d.returns.saveReturn(ret(s.id, {id: 1000}, key: 'r2')), throwsStateError);
    await expectLater(d.returns.saveReturn(ret(s.id, {id: 0}, key: 'r3')), throwsArgumentError);
    await expectLater(d.returns.saveReturn(ret(s.id, {'not-a-line': 1000}, key: 'r4')), throwsStateError);
    expect((await d.returns.list()).length, 1);
    await clean();
  });

  test('the same return sent twice (same key) is saved once', () async {
    final s = await bill([line(bulb, 2000, 9000)]);
    final id = (await view(s.id)).lines.single.billLineId;
    final a = await d.returns.saveReturn(ret(s.id, {id: 1000}));
    final again = await d.returns.saveReturn(ret(s.id, {id: 1000}));
    expect(again.replay, isTrue);
    expect(again.id, a.id);
    expect((await d.returns.list()).length, 1);
    expect(await stock(bulb), 50000 - 2000 + 1000);
  });

  test('a customer who owes on the bill: the refund comes off the debt first, nothing is handed back', () async {
    final s = await bill([line(bulb, 4000, 9000)], customer: 'c1', received: 0); // all 360.00 on credit
    expect(await d.ledger.balanceOf('c1'), 36000);
    final id = (await view(s.id)).lines.single.billLineId;
    final r = await d.returns.saveReturn(ret(s.id, {id: 2000}));
    expect(r.totalPaise, 18000);
    expect(r.dueReducedPaise, 18000);
    expect(r.refundedPaise, 0);
    expect(await d.ledger.balanceOf('c1'), 18000);
    final acc = await d.ledger.account('c1');
    expect(acc.ledger.last.kind, LedgerKind.returnCredit);
    expect(acc.bills.single.outstanding, 18000);
    final day = (await d.db.rows("SELECT * FROM day_totals WHERE day = '2026-10-17'")).single;
    expect(day.read<int>('credit_paise'), -18000);
    expect(day.read<int>('cash_paise'), 0);
    await clean();
  });

  test('a customer who owes only part: the debt is cleared first, the rest is handed back (UPI here)', () async {
    final s = await bill([line(bulb, 4000, 9000)], customer: 'c1', received: 30000); // owes 60.00
    final id = (await view(s.id)).lines.single.billLineId;
    final r = await d.returns.saveReturn(ret(s.id, {id: 4000}, mode: 1));
    expect(r.totalPaise, 36000);
    expect(r.dueReducedPaise, 6000);
    expect(r.refundedPaise, 30000);
    expect(await d.ledger.balanceOf('c1'), 0);
    final day = (await d.db.rows("SELECT * FROM day_totals WHERE day = '2026-10-17'")).single;
    expect(day.read<int>('upi_paise'), -30000);
    await clean();
  });

  test('keep the rest as credit on the account: nothing handed back, the customer is left with an advance', () async {
    final s = await bill([line(bulb, 4000, 9000)], customer: 'c1', received: 36000); // fully paid
    final id = (await view(s.id)).lines.single.billLineId;
    final r = await d.returns.saveReturn(ret(s.id, {id: 2000}, credit: true));
    expect(r.creditKeptPaise, 18000);
    expect(r.refundedPaise, 0);
    expect(await d.ledger.balanceOf('c1'), -18000, reason: 'an advance: the shop owes the customer');
    await clean();
  });

  test('a cancelled bill cannot be returned from, and a bill with returns cannot be cancelled', () async {
    final a = await bill([line(bulb, 1000, 9000)], key: 'a');
    await d.bills.cancelBill(a.id, reason: 'Wrong');
    await expectLater(d.returns.saveReturn(ret(a.id, {(await view(a.id)).lines.single.billLineId: 1000})), throwsStateError);
    final b = await bill([line(bulb, 2000, 9000)], key: 'b');
    await d.returns.saveReturn(ret(b.id, {(await view(b.id)).lines.single.billLineId: 1000}));
    await expectLater(d.bills.cancelBill(b.id, reason: 'Wrong'), throwsStateError);
    await clean();
  });

  test('Recalculate gives back exactly the figures the return kept (returns on a day with no bills, two kinds of refund)', () async {
    final s1 = await bill([line(bulb, 4000, 9000, cost: 6000), line(plug, 3000, 3333, cost: 2000)], key: 's1', customer: 'c1', received: 10000);
    final s2 = await bill([line(bulb, 2000, 9000, cost: 6000)], key: 's2');
    final v1 = await view(s1.id);
    await d.returns.saveReturn(ret(s1.id, {v1.lines[0].billLineId: 1000, v1.lines[1].billLineId: 1000}, key: 'r1'));
    await d.returns.saveReturn(ret(s2.id, {(await view(s2.id)).lines.single.billLineId: 2000}, key: 'r2', mode: 2, at: DateTime(2026, 10, 18, 9)));
    final before = await summaries();
    await rebuildSummaries(d.db);
    expect(await summaries(), before);
    await clean();
  });

  test('the sales returns list shows the newest first with their totals', () async {
    final s = await bill([line(bulb, 4000, 9000)]);
    final id = (await view(s.id)).lines.single.billLineId;
    await d.returns.saveReturn(ret(s.id, {id: 1000}, key: 'r1', at: DateTime(2026, 10, 16, 9)));
    await d.returns.saveReturn(ret(s.id, {id: 1000}, key: 'r2', at: DateTime(2026, 10, 17, 9)));
    final list = await d.returns.list();
    expect(list.map((r) => r.number), ['SRT-0002', 'SRT-0001']);
    expect(list.first.billNo, s.number);
    expect(list.first.items, 1);
  });

  test('bill lookup by number ignores case; an unknown number gives nothing', () async {
    final s = await bill([line(bulb, 1000, 9000)]);
    expect(await d.returns.billIdByNumber(s.number.toLowerCase()), s.id);
    expect(await d.returns.billIdByNumber('nope'), isNull);
  });
}
