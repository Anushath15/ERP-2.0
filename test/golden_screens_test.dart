import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/app.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/store.dart';
import 'helpers.dart';

/// Golden images of the key screens. Update with: flutter test --update-goldens test/golden_screens_test.dart
void main() {
  Future<void> fillBill(WidgetTester tester, dynamic c, DocMode mode, {int lines = 8}) async {
    final products = c.read(productsProvider) as List;
    final n = c.read(cartProvider(mode).notifier) as CartNotifier;
    for (var i = 0; i < lines; i++) {
      n.add(products[i * 5 + 2]);
    }
    n.add(products.firstWhere((p) => p.outOfStock));
    await tester.pumpAndSettle();
  }

  testWidgets('billing, desktop 1366x768, dark, English', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/bill');
    await fillBill(tester, c, DocMode.invoice);
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/billing_desktop_dark_en.png'));
  });

  testWidgets('billing, desktop 1366x768, light, Tamil', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/bill', theme: ThemeMode.light, lang: 'ta');
    await fillBill(tester, c, DocMode.invoice);
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/billing_desktop_light_ta.png'));
  });

  testWidgets('billing, phone 390x844, bill tab', (tester) async {
    final c = await pumpApp(tester, size: phone390, location: '/bill');
    await fillBill(tester, c, DocMode.invoice, lines: 4);
    await tester.tap(find.textContaining('Bill ('));
    await tester.pumpAndSettle();
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/billing_phone_bill_dark_en.png'));
  });

  testWidgets('product picker with no match shows + Add row', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/bill');
    await tester.enterText(find.byType(TextField).first, 'zzzzz');
    await tester.pumpAndSettle();
    expect(find.text('No product found.'), findsOneWidget);
    expect(find.text('+ Add zzzzz'), findsOneWidget);
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/billing_no_product.png'));
  });

  testWidgets('saved estimations, desktop', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/estimates');
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/estimates_desktop_dark_en.png'));
  });

  testWidgets('products table, desktop: names wrap fully and Out of stock is separate from price', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/products');
    expect(find.text('Out of stock'), findsWidgets);
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/products_desktop_dark_en.png'));
  });

  testWidgets('dashboard, tablet portrait, light', (tester) async {
    await pumpApp(tester, size: tabletPortrait, location: '/', theme: ThemeMode.light);
    await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/screens/dashboard_tablet_light_en.png'));
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
}
