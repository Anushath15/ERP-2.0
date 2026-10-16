import 'package:erp2/data/context.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/stock_value_provider.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await t.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('Fix these: type a buying price (it is saved and the product leaves the list); correct negative stock with a visible stock change', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/');
    await tester.pump(const Duration(seconds: 1));
    final d = c.read(appDataProvider);
    final prods = c.read(productsProvider).where((p) => p.stockMilli > 5000).take(2).toList();
    final noCost = prods[0], neg = prods[1];
    await tester.runAsync(() async {
      c.read(productsProvider.notifier).update(noCost.copyWith(costPaise: 0));
      await c.read(writeQueueProvider).flush();
      await d.db.customStatement('UPDATE products SET avg_cost_paise = 0 WHERE id = ?', [noCost.id]);
      await d.stock.adjust(productId: neg.id, qtyMilli: -(neg.stockMilli + 3000), reason: 'test: sold more than was in stock', at: DateTime(2026, 10, 13));
      await c.read(productsProvider.notifier).reload([neg.id]);
    });
    c.invalidate(stockValuationProvider);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/fix');
    await settle(tester);

    final sv = (await tester.runAsync(() => c.read(stockValuationProvider.future)))!;
    expect(sv.unpricedItems.map((x) => x.id), contains(noCost.id));
    expect(sv.negatives.map((x) => x.id), contains(neg.id));
    expect(find.text('Fix these'), findsWidgets);
    expect(find.byKey(ValueKey('cost-${noCost.id}')), findsOneWidget);

    // 1. an invalid price is refused with a message
    await tester.ensureVisible(find.byKey(ValueKey('price-${noCost.id}')));
    await tester.enterText(find.byKey(ValueKey('price-${noCost.id}')), '0');
    await tester.tap(find.byKey(ValueKey('save-${noCost.id}')));
    await tester.pump();
    expect(find.text('Type a price above zero.'), findsOneWidget);

    // 2. a real price is saved to the database and the product is valued again
    await tester.enterText(find.byKey(ValueKey('price-${noCost.id}')), '85.50');
    await tester.tap(find.byKey(ValueKey('save-${noCost.id}')));
    await settle(tester);
    final cost = await tester.runAsync(() => d.db.scalarInt('SELECT cost_paise FROM products WHERE id = ?', [noCost.id]));
    expect(cost, 8550);
    final sv2 = (await tester.runAsync(() => c.read(stockValuationProvider.future)))!;
    expect(sv2.unpricedItems.map((x) => x.id), isNot(contains(noCost.id)));

    // 3. negative stock: one tap, a confirmation that says what will be written, then a stock change with a reason
    await tester.ensureVisible(find.byKey(ValueKey('correct-${neg.id}')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('correct-${neg.id}')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('This writes a stock change'), findsOneWidget);
    await tester.tap(find.text('Correct with a stock change').last);
    await settle(tester);
    final qty = await tester.runAsync(() => d.db.scalarInt('SELECT qty_milli FROM stock_cache WHERE product_id = ?', [neg.id]));
    expect(qty, 0);
    final note = await tester.runAsync(() => d.db.rows("SELECT note, qty_milli FROM stock_movements WHERE product_id = ? AND note LIKE 'Corrected negative stock%'", [neg.id]));
    expect(note, hasLength(1));
    expect(note!.single.read<String>('note'), startsWith('Corrected negative stock (was -'));
    final sv3 = (await tester.runAsync(() => c.read(stockValuationProvider.future)))!;
    expect(sv3.negatives.map((x) => x.id), isNot(contains(neg.id)));
  });

  testWidgets('Fix these with nothing to fix says so', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/fix');
    await settle(tester);
    expect(find.text('Nothing needs fixing.'), findsOneWidget);
  });

  testWidgets('the Health page shows the real counts of what is in the data', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/health');
    await settle(tester);
    expect(find.text('What is in your data'), findsOneWidget);
    expect(find.textContaining('products,'), findsWidgets);
    expect(find.textContaining('customers,'), findsWidgets);
  });

  for (final (size, scale) in [(phone360, 2.0), (phone360, 1.0), (desktop1280, 1.5)]) {
    testWidgets('Fix these with rows to fix lays out cleanly at ${size.name}, text ${(scale * 100).round()}%', (tester) async {
      final c = await pumpApp(tester, size: size, location: '/', textScale: scale);
      await tester.pump(const Duration(seconds: 1));
      final d = c.read(appDataProvider);
      final prods = c.read(productsProvider).where((p) => p.stockMilli > 5000).take(6).toList();
      await tester.runAsync(() async {
        for (final p in prods.take(3)) {
          c.read(productsProvider.notifier).update(p.copyWith(costPaise: 0));
        }
        await c.read(writeQueueProvider).flush();
        await d.db.customStatement('UPDATE products SET avg_cost_paise = 0');
        for (final p in prods.skip(3)) {
          await d.stock.adjust(productId: p.id, qtyMilli: -(p.stockMilli + 1000), reason: 'test', at: DateTime(2026, 10, 13));
        }
        await c.read(productsProvider.notifier).reload(prods.skip(3).map((x) => x.id));
      });
      c.invalidate(stockValuationProvider);
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/fix');
      await settle(tester);
      expect(find.byKey(ValueKey('cost-${prods.first.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
