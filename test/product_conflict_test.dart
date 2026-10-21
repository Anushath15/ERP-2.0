import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/product_conflict.dart';
import 'package:erp2/domain/models.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: when another computer changed a product while its form was open here, saving asks first (Save my version or leave theirs);
// the stock figure alone does not count as a change; with no change nothing is asked.
void main() {
  const p = Product(id: 'x', name: 'VALVE', category: 'Plumbing', unit: 'pcs', pricePaise: 10000, costPaise: 7000, stockMilli: 5000, gstBp: 1800, barcode: '');

  test('a change in anything that can be edited counts; the stock figure alone does not', () {
    expect(productChangedElsewhere(p, p.copyWith()), isFalse);
    expect(productChangedElsewhere(p, p.copyWith(stockMilli: 1000)), isFalse, reason: 'sales move the stock all the time');
    for (final other in [p.copyWith(name: 'X'), p.copyWith(pricePaise: 10100), p.copyWith(costPaise: 1), p.copyWith(mrpPaise: 5), p.copyWith(brand: 'B'), p.copyWith(gstBp: 500), p.copyWith(barcode: '1'), p.copyWith(hsn: '9'), p.copyWith(minStockMilli: 1), p.copyWith(unit: 'box'), p.copyWith(category: 'C')]) {
      expect(productChangedElsewhere(p, other), isTrue);
    }
  });

  for (final keepMine in [true, false]) {
    testWidgets(keepMine ? 'the price was changed elsewhere: Save my version replaces it' : 'the price was changed elsewhere: Cancel keeps their price and shows it', (tester) async {
      final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 1800), location: '/products', motion: MotionLevel.off, followSystemMotion: false);
      final first = c.read(productsProvider).first;
      await tester.tap(find.text(first.name).first);
      await tester.pumpAndSettle();
      // meanwhile, on another computer, the price was changed
      await tester.runAsync(() => c.read(appDataProvider).catalog.saveProduct(first.copyWith(pricePaise: first.pricePaise + 5000), create: false));
      await tester.tap(find.text('Save').last);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      expect(find.text('Changed on another computer'), findsOneWidget);
      await tester.tap(find.text(keepMine ? 'Save my version' : 'Cancel').last);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      final inDb = (await tester.runAsync(() => c.read(appDataProvider).catalog.product(first.id)))!;
      if (keepMine) {
        expect(inDb.pricePaise, first.pricePaise, reason: 'the version typed here replaced the other change');
      } else {
        expect(inDb.pricePaise, first.pricePaise + 5000);
        expect(c.read(productsProvider).firstWhere((x) => x.id == first.id).pricePaise, first.pricePaise + 5000, reason: 'the screen shows their price now');
      }
    });
  }

  testWidgets('nothing changed elsewhere: Save just saves, with no question', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 1800), location: '/products', motion: MotionLevel.off, followSystemMotion: false);
    final first = c.read(productsProvider).first;
    await tester.tap(find.text(first.name).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Changed on another computer'), findsNothing);
  });
}
