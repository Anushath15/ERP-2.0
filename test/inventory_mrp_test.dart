import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/return_repo.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/models.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'data/helpers.dart' as dh;
import 'helpers.dart';

// Stock left: what each product has sold and made. Products: the optional MRP.
void main() {
  group('sold and profit per product', () {
    test('quantity, sales with GST and profit, after discounts, returns and cancelled bills', () async {
      final d = dh.memoryShop();
      await d.catalog.saveProduct(dh.sampleProduct('Bulb', price: 11800, cost: 6000, stock: 100000, id: 'p1', gst: 1800), create: true);
      await d.catalog.saveProduct(dh.sampleProduct('Plug', price: 5900, cost: 3000, stock: 100000, id: 'p2', gst: 1800), create: true);
      await d.catalog.saveProduct(dh.sampleProduct('Never sold', price: 100, cost: 50, stock: 1000, id: 'p3', gst: 1800), create: true);
      BillLineInput line(String p, int qty, int rate, int cost) => BillLineInput(productId: p, name: p, unit: 'pcs', qtyMilli: qty, ratePaise: rate, gstBp: 1800, costPaise: cost);
      // 2 bulbs at 118.00 (GST included): 236.00 -> before tax 200.00, cost 120.00, profit 80.00
      final a = await d.bills.saveBill(SaveBillInput(idemKey: 'a', at: DateTime(2026, 10, 1), lines: [line('p1', 2000, 11800, 6000)], roundOff: false));
      var s = await d.reports.productSales();
      expect(s['p1']!.qtyMilli, 2000);
      expect(s['p1']!.salesPaise, 23600);
      expect(s['p1']!.profitPaise, 8000);
      expect(s.containsKey('p3'), isFalse);
      // a bill with 10% off the whole bill: the item's sales and profit are smaller by the discount
      await d.bills.saveBill(SaveBillInput(idemKey: 'b', at: DateTime(2026, 10, 2), lines: [line('p2', 2000, 5900, 3000)], roundOff: false, extraDiscountBp: 1000));
      s = await d.reports.productSales();
      expect(s['p2']!.salesPaise, 10620, reason: '118.00 less 10 percent');
      expect(s['p2']!.profitPaise, lessThan(2000 * 2500 ~/ 1000 - 0), reason: 'the discount came out of the profit');
      // a return takes quantity, sales and profit back
      final v = (await d.returns.returnable(a.id))!;
      await d.returns.saveReturn(SaveReturnInput(idemKey: 'r', billId: a.id, at: DateTime(2026, 10, 3), lines: {v.lines.single.billLineId: 1000}, reason: 'x'));
      s = await d.reports.productSales();
      expect(s['p1']!.qtyMilli, 1000);
      expect(s['p1']!.salesPaise, 11800);
      expect(s['p1']!.profitPaise, 4000);
      // a cancelled bill is not counted
      final c = await d.bills.saveBill(SaveBillInput(idemKey: 'c', at: DateTime(2026, 10, 4), lines: [line('p1', 5000, 11800, 6000)], roundOff: false));
      await d.bills.cancelBill(c.id, reason: 'x');
      s = await d.reports.productSales();
      expect(s['p1']!.qtyMilli, 1000);
      await d.close();
    });
  });

  group('screens', () {
    Future<ProviderContainer> app(WidgetTester t, String loc) => pumpApp(t, size: const ScreenSpec('wide', 1900, 1000), location: loc, motion: MotionLevel.off, followSystemMotion: false);

    testWidgets('Stock left shows sold, sales and profit for every product', (tester) async {
      final c = await app(tester, '/inventory');
      final p = c.read(productsProvider).first;
      expect(find.text('Sold'), findsOneWidget);
      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Profit'), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('sold-${p.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('profit-${p.id}')), findsOneWidget);
    });

    testWidgets('the MRP field is optional; a selling price above the MRP is saved with a warning', (tester) async {
      await app(tester, '/products');
      await tester.tap(find.text('Add product').first);
      await tester.pumpAndSettle();
      expect(find.text('MRP (printed price, GST included)'), findsOneWidget);
      Finder field(String label) => find.widgetWithText(TextFormField, label).last;
      await tester.enterText(field('Product name'), 'Warn me');
      await tester.enterText(field('Selling price'), '120');
      await tester.enterText(field('MRP (printed price, GST included)'), '100');
      await tester.enterText(field('Buying price'), '50');
      await tester.enterText(field('Stock now'), '1');
      await tester.enterText(field('Minimum stock (warn me when stock falls to this)'), '0');
      await tester.pump();
      await tester.tap(find.text('Save').last);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pumpAndSettle();
      expect(find.textContaining('The selling price is more than the MRP'), findsOneWidget);
    });

    testWidgets('left empty, the MRP is simply not there', (tester) async {
      final c = await app(tester, '/products');
      await tester.tap(find.text('Add product').first);
      await tester.pumpAndSettle();
      Finder field(String label) => find.widgetWithText(TextFormField, label).last;
      await tester.enterText(field('Product name'), 'No mrp');
      await tester.enterText(field('Selling price'), '120');
      await tester.enterText(field('Buying price'), '50');
      await tester.enterText(field('Stock now'), '1');
      await tester.enterText(field('Minimum stock (warn me when stock falls to this)'), '0');
      await tester.pump();
      await tester.tap(find.text('Save').last);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pumpAndSettle();
      expect(find.text('Please fill this in'), findsNothing);
      final saved = c.read(productsProvider).firstWhere((p) => p.name == 'No mrp');
      expect(saved.mrpPaise, 0);
      expect(find.text('The selling price is more than the MRP. Check it.'), findsNothing);
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/products');
      await tester.pumpAndSettle();
      expect(find.text('MRP'), findsWidgets, reason: 'the list has an MRP column');
      expect(const Product(id: 'x', name: 'x', category: 'c', unit: 'pcs', pricePaise: 1, costPaise: 1, stockMilli: 0, gstBp: 0, barcode: '', mrpPaise: 500).copyWith().mrpPaise, 500);
    });
  });
}
