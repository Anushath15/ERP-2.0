import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/purchase_repo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: a purchase typed WITH GST adds up to what was typed (10 x Rs 3.13 = Rs 31.30, not Rs 31.27 from a rate rounded without GST), the GST part
// is the GST in that amount, and the saved purchase keeps exactly that.
void main() {
  PurchaseLineInput inclusive(int qty, int ratePaise, {int gst = 1800}) =>
      PurchaseLineInput(productId: 'p1', name: 'TUBE', unit: 'pcs', qtyMilli: qty, ratePaise: (ratePaise * 10000 / (10000 + gst)).round(), gstBp: gst, grossPaise: ratePaise * qty ~/ 1000);

  test('10 x Rs 3.13 with GST is Rs 31.30: value Rs 26.53 + GST Rs 4.77', () {
    final l = inclusive(10000, 313);
    expect((l.total, l.taxable, l.tax), (3130, 2653, 477));
  });

  test('typed without GST nothing changes: 10 x Rs 2.65 + 18 % = Rs 31.27', () {
    const l = PurchaseLineInput(productId: 'p1', name: 'TUBE', unit: 'pcs', qtyMilli: 10000, ratePaise: 265, gstBp: 1800);
    expect((l.total, l.taxable, l.tax), (3127, 2650, 477));
  });

  test('saved and read back: the purchase total is Rs 31.30 and the dealer is owed Rs 31.30', () async {
    final d = memoryShop();
    addTearDown(d.close);
    await d.catalog.saveProduct(sampleProduct('TUBE', price: 500, cost: 265, stock: 0, id: 'p1', gst: 1800), create: true);
    await d.db.exec("INSERT INTO dealers(id, name, created_at, updated_at, device_id) VALUES ('d1','JES',1,1,'x')");
    final s = await d.purchases.savePurchase(SavePurchaseInput(idemKey: 'k', dealerId: 'd1', at: DateTime(2026, 10, 21, 10), lines: [inclusive(10000, 313)]));
    expect(s.totalPaise, 3130);
    expect(await d.ledger.balanceOf('d1'), 3130);
    final det = (await d.purchases.detail(s.id))!;
    expect((det.lines.single.totalPaise, det.taxPaise), (3130, 477));
  });
}
