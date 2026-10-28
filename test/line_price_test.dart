import 'package:erp2/core/money.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/features/billing/bill_panel.dart' show BillLines;
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// What these tests prove: the Change price box of a bill or estimate line shows the MRP, the buying price and the discounts from the MRP, and all of them can
// be edited (MRP 100 with a 25% selling discount gives 75). Save changes this line only; Save to product also keeps the MRP, buying price and selling price on the
// product. The same box on the bill and on the estimate.
void main() {
  for (final mode in [DocMode.invoice, DocMode.estimation]) {
    testWidgets('${mode.name}: edit MRP and discounts; Save changes the line only; Save to product also changes the product', (tester) async {
      final c = await pumpApp(tester, size: desktop1920, location: mode == DocMode.invoice ? '/bill' : '/estimate', motion: MotionLevel.off, followSystemMotion: false);
      final p = c.read(productsProvider).firstWhere((x) => x.pricePaise > 0 && x.costPaise > 0);
      c.read(cartProvider(mode).notifier).add(p);
      await tester.pumpAndSettle();
      Finder lp(String k) => find.byKey(ValueKey('lp-$k'));
      String text(String k) => tester.widget<TextField>(lp(k)).controller!.text;
      Future<void> open() async {
        await tester.tap(find.descendant(of: find.byType(BillLines), matching: find.text(formatPaise(c.read(cartProvider(mode)).lines.single.rate))).first);
        await tester.pumpAndSettle();
      }

      await open();
      for (final k in ['mrp', 'buy', 'buypct', 'rate', 'ratepct', 'disc']) {
        expect(lp(k), findsOneWidget, reason: k);
      }
      expect(lp('save-product'), findsOneWidget);
      await tester.enterText(lp('mrp'), '1000');
      await tester.enterText(lp('buypct'), '50');
      expect(text('buy'), '500.00');
      await tester.enterText(lp('ratepct'), '25');
      expect(text('rate'), '750.00');
      await tester.tap(lp('save'));
      await tester.pumpAndSettle();
      expect(c.read(cartProvider(mode)).lines.single.rate, 75000);
      final same = c.read(productsProvider).firstWhere((x) => x.id == p.id);
      expect((same.pricePaise, same.mrpPaise, same.costPaise), (p.pricePaise, p.mrpPaise, p.costPaise), reason: 'Save changes this line only');

      await open();
      await tester.enterText(lp('mrp'), '1000');
      await tester.enterText(lp('buypct'), '50');
      await tester.enterText(lp('ratepct'), '25');
      await tester.tap(lp('save-product'));
      await tester.pumpAndSettle();
      final saved = c.read(productsProvider).firstWhere((x) => x.id == p.id);
      expect((saved.pricePaise, saved.mrpPaise, saved.costPaise), (75000, 100000, 50000), reason: 'Save to product');
      expect(c.read(cartProvider(mode)).lines.single.product.costPaise, 50000, reason: 'the line follows the product');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the buying price is not shown while the profit is hidden', (tester) async {
    final c = await pumpApp(tester, size: desktop1920, location: '/bill', motion: MotionLevel.off, followSystemMotion: false);
    final p = c.read(productsProvider).firstWhere((x) => x.pricePaise > 0);
    c.read(cartProvider(DocMode.invoice).notifier).add(p);
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first));
    await tester.tap(find.byIcon(Icons.visibility_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(BillLines), matching: find.text(formatPaise(p.pricePaise))).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lp-buy')), findsNothing);
    expect(find.byKey(const ValueKey('lp-mrp')), findsOneWidget);
  });
}
