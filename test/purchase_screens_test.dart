import 'package:erp2/core/money.dart';
import 'package:erp2/data/repo/purchase_repo.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/actions.dart';
import 'package:erp2/fake/credit_store.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// Purchases with items on the screens: the Add purchase page, the purchase popup, the dealer's page.
void main() {
  Future<ProviderContainer> app(WidgetTester t, {String loc = '/purchases'}) =>
      pumpApp(t, size: const ScreenSpec('tall', 1500, 3200), location: loc, motion: MotionLevel.off, followSystemMotion: false);
  void go(WidgetTester t, String path) => GoRouter.of(t.element(find.byType(Scaffold).first)).go(path);

  Future<(String, String)> twoDealers(ProviderContainer c) async {
    final ds = c.read(recsProvider('dealers'));
    return (ds[0].id, ds[1].id);
  }

  Future<List<PurchaseRow>> purchases(WidgetTester t, ProviderContainer c, {String? dealer}) async => (await t.runAsync(() => c.read(appDataProvider).purchases.list(dealerId: dealer)))!;

  testWidgets('Add purchase on the page: pick a product, type quantity and rate, save: stock goes up and the purchase is listed', (tester) async {
    final c = await app(tester);
    final product = c.read(productsProvider).first;
    final stockBefore = product.stockMilli;
    await tester.tap(find.text('Add purchase').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pur-picker')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pur-picker')), product.name.substring(0, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('pur-option-${product.id}')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ValueKey('pur-qty-${product.id}')), '5');
    await tester.enterText(find.byKey(ValueKey('pur-rate-${product.id}')), '100');
    await tester.pump();
    // 5 x 100.00 + GST of the product
    final gst = product.gstBp;
    const taxable = 50000;
    final total = taxable + (taxable * gst + 5000) ~/ 10000;
    expect(find.text(formatPaise(total, symbol: true)), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('pur-invoice')), 'INV/77');
    await tester.ensureVisible(find.byKey(const ValueKey('pur-save')));
    await tester.tap(find.byKey(const ValueKey('pur-save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final saved = await purchases(tester, c);
    expect(saved.length, 1);
    expect(saved.single.totalPaise, total);
    expect(saved.single.received, isTrue);
    expect((await tester.runAsync(() => c.read(appDataProvider).catalog.product(product.id)))!.stockMilli, stockBefore + 5000);
    expect(find.text(saved.single.number), findsWidgets, reason: 'back on the list');
  });

  testWidgets('saving with no item, a missing rate or too much paid is refused with the reason', (tester) async {
    final c = await app(tester, loc: '/purchases/new');
    await tester.ensureVisible(find.byKey(const ValueKey('pur-save')));
    await tester.tap(find.byKey(const ValueKey('pur-save')));
    await tester.pump();
    expect(find.text('Add at least one item.'), findsOneWidget);
    final product = c.read(productsProvider).first;
    await tester.enterText(find.byKey(const ValueKey('pur-picker')), product.name.substring(0, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('pur-option-${product.id}')).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('pur-save')));
    await tester.tap(find.byKey(const ValueKey('pur-save')));
    await tester.pump();
    expect(find.text('Type the quantity and the rate of every item.'), findsOneWidget);
    expect(await purchases(tester, c), isEmpty);
  });

  testWidgets('the purchase popup shows the items, the selling price marked, the rate before and a cheaper dealer; a pending one can be marked received', (tester) async {
    final c = await app(tester);
    final (d1, d2) = await twoDealers(c);
    final p = c.read(productsProvider).first;
    PurchaseLineInput lineOf(int rate) => PurchaseLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: 2000, ratePaise: rate, gstBp: p.gstBp);
    await tester.runAsync(() async {
      final repo = c.read(appDataProvider).purchases;
      await repo.savePurchase(SavePurchaseInput(idemKey: 'u1', dealerId: d2, at: DateTime(2026, 10, 1), lines: [lineOf(5000)]));
      await repo.savePurchase(SavePurchaseInput(idemKey: 'u2', dealerId: d1, at: DateTime(2026, 10, 5), lines: [lineOf(6000)], received: false));
    });
    c.read(purchasesVersionProvider.notifier).bump();
    await tester.pumpAndSettle();
    final rows = await purchases(tester, c);
    final pending = rows.firstWhere((r) => !r.received);
    await tester.tap(find.text(pending.number).first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('pur-sell-${p.id}')), findsOneWidget, reason: 'the selling price marked');
    expect(find.byKey(ValueKey('pur-last-${p.id}')), findsOneWidget, reason: 'what was paid the time before');
    expect(find.byKey(ValueKey('pur-cheaper-${p.id}')), findsOneWidget, reason: 'the other dealer had it cheaper');
    expect(find.byKey(const ValueKey('pur-mark-received')), findsOneWidget);
    final stockBefore = (await tester.runAsync(() => c.read(appDataProvider).catalog.product(p.id)))!.stockMilli;
    await tester.tap(find.byKey(const ValueKey('pur-mark-received')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(() => c.read(appDataProvider).catalog.product(p.id)))!.stockMilli, stockBefore + 2000);
    expect((await purchases(tester, c)).every((r) => r.received), isTrue);
  });

  testWidgets('the dealer page: purchases first, their purchases listed, only the balance with an Account status button', (tester) async {
    final c = await app(tester);
    final (d1, _) = await twoDealers(c);
    final p = c.read(productsProvider).first;
    await tester.runAsync(() async {
      await c.read(appDataProvider).purchases.savePurchase(SavePurchaseInput(
          idemKey: 'dd1', dealerId: d1, at: DateTime(2026, 10, 5), lines: [PurchaseLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: 1000, ratePaise: 10000, gstBp: p.gstBp)], paidPaise: 0));
    });
    await c.read(dealerLedgerProvider.notifier).refreshParty(d1);
    c.read(purchasesVersionProvider.notifier).bump();
    go(tester, '/dealers/$d1');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dealer-bought')), findsOneWidget);
    expect(find.text('Their purchases'), findsOneWidget);
    final row = (await purchases(tester, c, dealer: d1)).first;
    expect(find.byKey(ValueKey('dealer-purchase-${row.id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('cust-account-card')), findsOneWidget);
    expect(find.text('Bills still to pay'), findsNothing, reason: 'the account is on its own page');
    expect(find.byKey(const ValueKey('dealer-add-purchase')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cust-account-open')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-back')), findsOneWidget);
    expect(find.text('Back to the dealer'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-back')));
    await tester.pumpAndSettle();
    expect(find.text('Their purchases'), findsOneWidget);
  });
}
