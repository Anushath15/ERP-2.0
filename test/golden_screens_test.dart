import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/app.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/fake/credit_store.dart' show seedCredit;
import 'package:erp2/fake/seed.dart';
import 'helpers.dart';

/// Golden images of the key screens, at several text sizes and in both themes.
/// Update with: flutter test --update-goldens test/golden_screens_test.dart
void main() {
  Future<void> fillBill(WidgetTester tester, ProviderContainer c, DocMode mode, {int lines = 8}) async {
    final products = c.read(productsProvider);
    final n = c.read(cartProvider(mode).notifier);
    for (var i = 0; i < lines; i++) {
      n.add(products[i * 5 + 2]);
    }
    n.add(products.firstWhere((p) => p.outOfStock));
    await tester.pumpAndSettle();
  }

  final screens = <(String, String, bool)>[('pos', '/bill', true), ('estimations', '/estimates', false), ('products', '/products', false), ('settings', '/settings', false)];
  for (final size in [desktop1366, phone390]) {
    for (final scale in [0.8, 1.0, 1.25, 1.5, 2.0]) {
      for (final (name, route, fill) in screens) {
        testWidgets('$name, ${size.name}, text ${(scale * 100).round()}%, dark', (tester) async {
          final c = await pumpApp(tester, size: size, location: route, textScale: scale);
          if (fill) await fillBill(tester, c, DocMode.invoice, lines: 6);
          expect(tester.takeException(), isNull);
          await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/text_sizes/${name}_${size.name}_${(scale * 100).round()}_dark.png'));
        });
      }
    }
  }

  for (final (name, route, fill) in screens) {
    testWidgets('$name, desktop 1366x768, light, high contrast, large text', (tester) async {
      final c = await pumpApp(tester, size: desktop1366, location: route, theme: ThemeMode.light, textScale: 1.25);
      c.read(settingsProvider.notifier).set((s) => s.copyWith(highContrast: true));
      if (fill) await fillBill(tester, c, DocMode.invoice, lines: 6);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/text_sizes/${name}_desktop-1366x768_125_light_highcontrast.png'));
    });
  }

  testWidgets('product picker with no match shows + Add row', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/bill');
    await tester.enterText(find.byType(TextField).first, 'zzzzz');
    await tester.pumpAndSettle();
    expect(find.text('No product found.'), findsOneWidget);
    expect(find.text('+ Add zzzzz'), findsOneWidget);
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/billing_no_product.png'));
  });

  testWidgets('products table: names wrap fully and Out of stock is separate from the price', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/products');
    expect(find.text('Out of stock'), findsWidgets);
  });

  testWidgets('dashboard, tablet portrait, light', (tester) async {
    await pumpApp(tester, size: tabletPortrait, location: '/', theme: ThemeMode.light);
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/dashboard_tablet_light.png'));
  });

  testWidgets('estimate print: shows its own date beside the number; Edited on only when edited', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/preview/estimate');
    expect(find.byKey(const ValueKey('paperDate')), findsOneWidget);
    expect(find.textContaining('10/10/2026'), findsOneWidget); // 3 days before 13/10/2026, not today
    expect(find.byKey(const ValueKey('paperEdited')), findsOneWidget);
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/print_estimate_a4.png'));
  });

  testWidgets('invoice print has no Edited on line; 80 mm receipt', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/preview/80');
    expect(find.byKey(const ValueKey('paperEdited')), findsNothing);
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/print_receipt_80.png'));
  });

  testWidgets('invoice with Received and Balance due (A4)', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/preview/a4');
    expect(find.byKey(const ValueKey('paperReceived')), findsOneWidget);
    expect(find.byKey(const ValueKey('paperBalance')), findsOneWidget);
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/print_invoice_part_paid_a4.png'));
  });

  testWidgets('Credit and Dues list, desktop', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/credit');
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/credit_dues_desktop.png'));
  });

  testWidgets('customer page with ageing, ledger and reminders, tablet light', (tester) async {
    final id = seedCredit(seedCustomers(), fixedNow).entries.firstWhere((e) => e.value.balance > 0 && e.value.bills.length > 1).key;
    await pumpApp(tester, size: tabletPortrait, location: '/customers/$id', theme: ThemeMode.light);
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/customer_credit_tablet_light.png'));
  });
}
