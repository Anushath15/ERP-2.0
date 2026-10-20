import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: the same product in another brand is another rate; on a bill line the person switches the brand and the line becomes
// that brand's product with that brand's rate, keeping quantity and discount; the same brand twice joins into one line.
class _Brands extends ProductsNotifier {
  @override
  List<Product> build() {
    final all = seedProducts(count: 30);
    final base = all[0].copyWith(name: 'BRASS BALL VALVE 1 INCH');
    return [
      base.copyWith(brand: 'PLATO', pricePaise: 105000),
      all[1].copyWith(name: 'brass ball  valve 1 inch', brand: 'HSG', pricePaise: 48000),
      all[2].copyWith(name: 'BRASS BALL VALVE 1 INCH', brand: 'KRISH', pricePaise: 88500),
      ...all.skip(3),
    ];
  }
}

void main() {
  test('the groups: only names that exist in more than one brand, ignoring capitals and extra spaces', () {
    final c = ProviderContainer(overrides: [productsProvider.overrideWith(_Brands.new)]);
    addTearDown(c.dispose);
    final groups = c.read(productVariantsProvider);
    expect(groups.length, 1);
    expect(groups.values.single.map((p) => p.brand).toSet(), {'PLATO', 'HSG', 'KRISH'});
  });

  test('switching the brand of a line: the rate, name and stock are the other product, quantity and discount stay; the same brand twice joins', () {
    final c = ProviderContainer(overrides: [productsProvider.overrideWith(_Brands.new)]);
    addTearDown(c.dispose);
    final list = c.read(productsProvider);
    final cart = c.read(cartProvider(DocMode.invoice).notifier);
    cart.add(list[0], qtyMilli: 2000);
    cart.setDiscount(0, 500);
    cart.swapProduct(0, list[1]);
    var lines = c.read(cartProvider(DocMode.invoice)).lines;
    expect(lines.length, 1);
    expect(lines.single.product.brand, 'HSG');
    expect(lines.single.rate, 48000);
    expect(lines.single.qtyMilli, 2000);
    expect(lines.single.discountBp, 500);
    cart.add(list[2], qtyMilli: 1000);
    cart.swapProduct(0, list[2]);
    lines = c.read(cartProvider(DocMode.invoice)).lines;
    expect(lines.length, 1, reason: 'the other brand was already on the bill: one line');
    expect(lines.single.qtyMilli, 3000);
    expect(lines.single.rate, 88500);
  });

  for (final path in ['/bill', '/estimate']) {
    testWidgets('$path: the line shows its brand and a menu with every brand, rate and stock; picking one changes the rate', (tester) async {
      final c = await pumpApp(tester, size: desktop1366, location: path, extraOverrides: [productsProvider.overrideWith(_Brands.new)]);
      final mode = path == '/bill' ? DocMode.invoice : DocMode.estimation;
      c.read(cartProvider(mode).notifier).add(c.read(productsProvider)[0]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('brand-switch-0')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('brand-switch-0')));
      await tester.pumpAndSettle();
      expect(find.textContaining('HSG'), findsWidgets);
      expect(find.textContaining('KRISH'), findsWidgets);
      await tester.tap(find.textContaining('KRISH').last);
      await tester.pumpAndSettle();
      final line = c.read(cartProvider(mode)).lines.single;
      expect(line.product.brand, 'KRISH');
      expect(line.rate, 88500);
    });
  }
}
