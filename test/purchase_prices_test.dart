import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: on the Add purchase page each item has its MRP, the buying price and the new selling price, each price also as a percent of the MRP
// (MRP 200 and 50% makes 100); typing a price gives the percent back; changing the MRP moves the prices; and saving puts the typed selling price and MRP on the product.
void main() {
  testWidgets('MRP and percents fill the buying and selling prices; saving sets the product selling price and MRP', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1500, 3200), location: '/purchases', motion: MotionLevel.off, followSystemMotion: false);
    final product = c.read(productsProvider).first;
    await tester.tap(find.text('Add purchase').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pur-picker')), product.name.substring(0, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('pur-option-${product.id}')).first);
    await tester.pumpAndSettle();
    Finder f(String k) => find.byKey(ValueKey('pur-$k-${product.id}'));
    String text(String k) => tester.widget<TextField>(f(k)).controller!.text;
    await tester.enterText(f('qty'), '2');
    await tester.enterText(f('mrp'), '200');
    await tester.enterText(f('buypct'), '50');
    await tester.pump();
    expect(text('rate'), '100.00', reason: '50% off the MRP');
    await tester.enterText(f('sellpct'), '25');
    await tester.pump();
    expect(text('sellbox'), '150.00');
    await tester.enterText(f('rate'), '120');
    await tester.pump();
    expect(text('buypct'), '40');
    await tester.enterText(f('mrp'), '300');
    await tester.pump();
    expect(text('rate'), '180.00', reason: 'the percent stays, the price follows the MRP');
    expect(text('sellbox'), '225.00');
    await tester.enterText(f('sellbox'), '260');
    await tester.pump();
    expect(text('sellpct'), '13.33');
    await tester.ensureVisible(find.byKey(const ValueKey('pur-save')));
    await tester.tap(find.byKey(const ValueKey('pur-save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final after = (await tester.runAsync(() => c.read(appDataProvider).catalog.product(product.id)))!;
    expect(after.pricePaise, 26000, reason: 'the typed selling price, not the margin rule');
    expect(after.mrpPaise, 30000);
    expect(after.costPaise, 18000);
  });
}
