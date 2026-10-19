import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/purchase_repo.dart';
import 'package:erp2/domain/margin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'data/helpers.dart';

// What these tests prove: when a purchase brings a new buying price, the selling price moves by the same ratio so the margin stays,
// both ways (dearer -> up, cheaper -> down), and nothing moves when there is no old buying price or the shop switched it off.
// What they do NOT prove: that the shop likes the rounding (nearest 50 paise); that is a shop decision.
void main() {
  group('sellingPriceKeepingMargin', () {
    test('dearer stock raises the selling price by the same ratio', () {
      // cost 100 -> 110 (+10%), selling 150 -> 165 : margin 50% kept
      expect(sellingPriceKeepingMargin(oldCost: 10000, newCost: 11000, oldSell: 15000), 16500);
    });
    test('cheaper stock lowers it by the same ratio', () {
      // cost 110 -> 88 (-20%), selling 165 -> 132
      expect(sellingPriceKeepingMargin(oldCost: 11000, newCost: 8800, oldSell: 16500), 13200);
    });
    test('the margin percentage is the same after the change (within the rounding)', () {
      for (final c in [(5000, 5650, 7500), (23400, 21000, 31000), (999, 1100, 1400)]) {
        final now = sellingPriceKeepingMargin(oldCost: c.$1, newCost: c.$2, oldSell: c.$3);
        expect((now / c.$2 - c.$3 / c.$1).abs(), lessThan(0.02), reason: '$c -> $now');
      }
    });
    test('nothing to base it on: price stays', () {
      expect(sellingPriceKeepingMargin(oldCost: 0, newCost: 5000, oldSell: 9000), 9000);
      expect(sellingPriceKeepingMargin(oldCost: 5000, newCost: 5000, oldSell: 9000), 9000);
      expect(sellingPriceKeepingMargin(oldCost: 5000, newCost: 0, oldSell: 9000), 9000);
      expect(sellingPriceKeepingMargin(oldCost: 5000, newCost: 6000, oldSell: 0), 0);
    });
    test('a price is kept to the nearest 50 paise (or the paisa under Rs. 10)', () {
      expect(sellingPriceKeepingMargin(oldCost: 7300, newCost: 7777, oldSell: 9990), 10650);
      expect(sellingPriceKeepingMargin(oldCost: 300, newCost: 330, oldSell: 450), 495);
    });
  });

  group('receiving a purchase', () {
    late AppData d;
    setUp(() async {
      d = memoryShop();
      await d.catalog.saveProduct(sampleProduct('Bulb', price: 15000, cost: 10000, stock: 0, id: 'p1', gst: 1800), create: true);
      await d.catalog.saveProduct(sampleProduct('New item', price: 9000, cost: 0, stock: 0, id: 'p2', gst: 1800), create: true);
      await d.db.exec("INSERT INTO dealers(id, name, created_at, updated_at, device_id) VALUES ('d1','Sakthi',1,1,'x')");
    });
    tearDown(() => d.close());

    SavePurchaseInput buy(String key, String product, int rate, {bool updateCost = true, bool received = true}) => SavePurchaseInput(
        idemKey: key, dealerId: 'd1', at: DateTime(2026, 10, 10, 10), invoiceNo: 'I', paidPaise: 0, received: received, updateCost: updateCost,
        lines: [PurchaseLineInput(productId: product, name: product, unit: 'pcs', qtyMilli: 1000, ratePaise: rate, gstBp: 1800)]);

    test('the buying price goes up: the selling price goes up with it; then down: it comes down by the same ratio', () async {
      await d.purchases.savePurchase(buy('a', 'p1', 11000));
      var p = (await d.catalog.product('p1'))!;
      expect((p.costPaise, p.pricePaise), (11000, 16500));
      await d.purchases.savePurchase(buy('b', 'p1', 8800));
      p = (await d.catalog.product('p1'))!;
      expect((p.costPaise, p.pricePaise), (8800, 13200));
      expect((await d.db.rows("SELECT * FROM audit WHERE field = 'price'")).length, 2, reason: 'each change of the selling price is in the audit trail');
    });

    test('a product with no buying price yet keeps its selling price (no margin to keep)', () async {
      await d.purchases.savePurchase(buy('c', 'p2', 5000));
      final p = (await d.catalog.product('p2'))!;
      expect((p.costPaise, p.pricePaise), (5000, 9000));
    });

    test('switched off, or still pending: nothing changes (pending changes at receiving)', () async {
      await d.purchases.savePurchase(buy('d', 'p1', 11000, updateCost: false));
      expect((await d.catalog.product('p1'))!.pricePaise, 15000);
      final s = await d.purchases.savePurchase(buy('e', 'p1', 12000, received: false));
      expect((await d.catalog.product('p1'))!.pricePaise, 15000);
      await d.purchases.markReceived(s.id);
      expect((await d.catalog.product('p1'))!.pricePaise, 18000);
    });

    test('a selling price the shop typed itself becomes the base for the next purchase', () async {
      await d.catalog.saveProduct((await d.catalog.product('p1'))!.copyWith(pricePaise: 14000), create: false);
      await d.purchases.savePurchase(buy('f', 'p1', 12000));
      // cost 100 -> 120, selling 140 -> 168
      expect((await d.catalog.product('p1'))!.pricePaise, 16800);
    });
  });
}
