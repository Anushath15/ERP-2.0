import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/purchase_repo.dart';
import 'package:erp2/domain/average_cost.dart';
import 'package:erp2/domain/credit/account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: the average buying cost is the weighted average of what was bought (selling never changes it); a purchase edited so that the
// money typed with GST changes by a paisa still changes the saved lines; and the day's cash book counts EVERY cash movement, not only cash sales.
void main() {
  test('movingAverage: the usual cases', () {
    expect(movingAverage(haveMilli: 10000, haveCost: 10000, inMilli: 10000, inCost: 20000), 15000, reason: '10 at 100 and 10 at 200 average 150');
    expect(movingAverage(haveMilli: 15000, haveCost: 15000, inMilli: 5000, inCost: 30000), 18750, reason: '15 at 150 and 5 at 300: 187.50');
    expect(movingAverage(haveMilli: 0, haveCost: 9999, inMilli: 4000, inCost: 700), 700, reason: 'no stock: the new rate is the average');
    expect(movingAverage(haveMilli: -3000, haveCost: 500, inMilli: 4000, inCost: 700), 700, reason: 'negative stock carries no value');
    expect(movingAverage(haveMilli: 1000, haveCost: 0, inMilli: 1000, inCost: 700), 700, reason: 'no known cost before');
    expect(movingAverage(haveMilli: 3000, haveCost: 100, inMilli: 0, inCost: 700), 100, reason: 'nothing arrived');
    expect(movingAverage(haveMilli: 1000, haveCost: 101, inMilli: 1000, inCost: 102), 102, reason: '101.5 rounds half up');
  });

  group('a real shop', () {
    late AppData d;
    setUp(() async {
      d = memoryShop();
      await d.catalog.saveProduct(sampleProduct('Bulb', price: 20000, cost: 10000, stock: 10000, id: 'p1', gst: 1800), create: true);
      await d.db.exec("INSERT INTO dealers(id, name, created_at, updated_at, device_id) VALUES ('d1','Sakthi',1,1,'x')");
      await d.catalog.saveCustomer(sampleCustomer('Murugan', id: 'c1', limit: 100000000), create: true);
    });
    tearDown(() => d.close());
    Future<int> avg() => d.db.scalarInt("SELECT avg_cost_paise FROM products WHERE id = 'p1'");
    PurchaseLineInput line(int qty, int rate) => PurchaseLineInput(productId: 'p1', name: 'Bulb', unit: 'pcs', qtyMilli: qty, ratePaise: rate, gstBp: 1800);
    SavePurchaseInput buy(String key, List<PurchaseLineInput> ls, {int paid = 0}) => SavePurchaseInput(idemKey: key, dealerId: 'd1', at: DateTime(2026, 10, 10, 10), lines: ls, paidPaise: paid);

    test('purchases average the cost; a sale does not move it; the buying price is the latest rate', () async {
      await d.purchases.savePurchase(buy('a', [line(10000, 20000)])); // 10 in stock at 100 (the price on the product) + 10 at 200
      expect(await avg(), 15000);
      await d.bills.saveBill(SaveBillInput(idemKey: 's', at: DateTime(2026, 10, 11), lines: [const BillLineInput(productId: 'p1', name: 'Bulb', unit: 'pcs', qtyMilli: 5000, ratePaise: 25000, gstBp: 1800)]));
      expect(await avg(), 15000, reason: 'selling does not change the average');
      await d.purchases.savePurchase(buy('b', [line(5000, 30000)])); // 15 left at 150 + 5 at 300
      expect(await avg(), 18750);
      expect((await d.catalog.product('p1'))!.costPaise, 30000, reason: 'the buying price is the latest rate');
    });

    test('a purchase edited to more pieces moves the average; one edited to fewer leaves it', () async {
      final s = await d.purchases.savePurchase(buy('a', [line(10000, 20000)]));
      expect(await avg(), 15000);
      await d.purchases.editPurchase(s.id, buy('a', [line(20000, 20000)])); // 10 more at 200: 20 at 100 + ... the stock was 20, now 30
      expect(await avg(), 16667, reason: '(20 x 150 + 10 x 200) / 30');
      await d.purchases.editPurchase(s.id, buy('a', [line(5000, 20000)]));
      expect(await avg(), 16667, reason: 'fewer pieces: the average stays');
    });

    test('a purchase typed with GST whose rate without GST is the same but whose money differs by a paisa is saved with the new money', () async {
      // 3.13 and 3.14 with 18 % both come to 2.65 / 2.66; pick two inclusive amounts that give the same rate without GST
      const a = PurchaseLineInput(productId: 'p1', name: 'Bulb', unit: 'pcs', qtyMilli: 10000, ratePaise: 265, gstBp: 1800, grossPaise: 3130);
      const b = PurchaseLineInput(productId: 'p1', name: 'Bulb', unit: 'pcs', qtyMilli: 10000, ratePaise: 265, gstBp: 1800, grossPaise: 3131);
      final s = await d.purchases.savePurchase(buy('a', [a]));
      expect(s.totalPaise, 3130);
      final e = await d.purchases.editPurchase(s.id, buy('a', [b]));
      expect(e.totalPaise, 3131);
      expect((await d.purchases.detail(s.id))!.lines.single.totalPaise, 3131, reason: 'the saved line moved with the total');
      expect(await d.ledger.balanceOf('d1'), 3131);
    });

    test('the cash book counts cash sales, cash from customers, cash to dealers, with-purchase payments and dealer refunds, and ignores reversed or non-cash money', () async {
      final day = DateTime(2026, 10, 12, 11);
      await d.bills.saveBill(SaveBillInput(idemKey: 'cash', at: day, lines: [const BillLineInput(productId: 'p1', name: 'Bulb', unit: 'pcs', qtyMilli: 1000, ratePaise: 11800, gstBp: 1800)])); // Rs 118 cash
      await d.bills.saveBill(SaveBillInput(idemKey: 'cr', at: day, customerId: 'c1', customerName: 'Murugan', receivedPaise: 0, lines: [const BillLineInput(productId: 'p1', name: 'Bulb', unit: 'pcs', qtyMilli: 2000, ratePaise: 11800, gstBp: 1800)])); // Rs 236 credit
      await d.ledger.receivePayment(PartyKind.customer, partyId: 'c1', partyName: 'Murugan', amount: 10000, mode: 'cash', at: day); // Rs 100 cash in
      await d.ledger.receivePayment(PartyKind.customer, partyId: 'c1', partyName: 'Murugan', amount: 5000, mode: 'upi', at: day); // not cash
      await d.purchases.savePurchase(SavePurchaseInput(idemKey: 'pu', dealerId: 'd1', at: day, lines: [line(10000, 20000)], paidPaise: 7000)); // Rs 70 paid with the purchase
      await d.purchases.savePurchase(SavePurchaseInput(idemKey: 'pu2', dealerId: 'd1', at: day, lines: [line(10000, 20000)], paidPaise: 4000, payMode: 1)); // Rs 40 paid by UPI with the purchase: not cash
      expect((await d.purchases.detail((await d.purchases.list()).first.id))!.payMode, 1, reason: 'the way it was paid is kept');
      await d.ledger.receivePayment(PartyKind.dealer, partyId: 'd1', partyName: 'Sakthi', amount: 3000, mode: 'cash', at: day); // Rs 30 paid later
      await d.ledger.receivePayment(PartyKind.dealer, partyId: 'd1', partyName: 'Sakthi', amount: 2000, mode: 'upi', at: day); // not cash
      final book = await d.reports.cashBook(day);
      expect(book.salesCash, 11800);
      expect(book.receivedFromCustomers, 10000);
      expect(book.paidWithPurchases, 7000);
      expect(book.paidToDealersLater, 3000);
      expect(book.expected(opening: 500000, expenses: 2500), 500000 + 11800 + 10000 - 7000 - 3000 - 2500);
      final other = await d.reports.cashBook(DateTime(2026, 10, 13));
      expect((other.cashIn, other.cashOutBeforeExpenses), (0, 0), reason: 'another day has nothing');
    });
  });
}
