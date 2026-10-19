import 'package:erp2/data/repo/purchase_repo.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/actions.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// Giving goods back to a dealer, on the screens: the purchase's items are listed, the person picks how many, saving takes the stock
// out and lists the return.
void main() {
  Future<ProviderContainer> app(WidgetTester t, {String loc = '/purchase-returns'}) =>
      pumpApp(t, size: const ScreenSpec('tall', 1500, 3200), location: loc, motion: MotionLevel.off, followSystemMotion: false);
  void go(WidgetTester t, String path) => GoRouter.of(t.element(find.byType(Scaffold).first)).go(path);

  Future<SavedPurchase> buy(WidgetTester t, ProviderContainer c, {bool received = true}) async {
    final p = c.read(productsProvider).first;
    final dealer = c.read(recsProvider('dealers')).first.id;
    return (await t.runAsync(() => c.read(billActionsProvider).savePurchase(SavePurchaseInput(
        idemKey: 'k${received ? 1 : 2}', dealerId: dealer, at: DateTime(2026, 10, 10), lines: [PurchaseLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: 6000, ratePaise: 5000, gstBp: p.gstBp)], received: received))))!;
  }

  testWidgets('the purchase\'s items are listed; Give back all + a reason + Save takes the stock out and lists the return', (tester) async {
    final c = await app(tester);
    final saved = await buy(tester, c);
    final v = (await tester.runAsync(() => c.read(appDataProvider).purchaseReturns.returnable(saved.id)))!;
    final line = v.lines.single;
    go(tester, '/purchase-returns/purchase/${saved.id}');
    await tester.pumpAndSettle();
    expect(find.text(line.name), findsWidgets);
    final stockBefore = (await tester.runAsync(() => c.read(appDataProvider).catalog.product(line.productId)))!.stockMilli;
    await tester.tap(find.byKey(ValueKey('pret-all-${line.purchaseLineId}')));
    await tester.pump();
    expect(find.byKey(const ValueKey('pret-total')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('pret-save')));
    await tester.tap(find.byKey(const ValueKey('pret-save')));
    await tester.pump();
    expect(find.byKey(const ValueKey('pret-error')), findsOneWidget, reason: 'a reason is needed');
    await tester.enterText(find.byKey(const ValueKey('pret-reason')), 'Faulty');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pret-save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    final list = (await tester.runAsync(() => c.read(appDataProvider).purchaseReturns.list()))!;
    expect(list.length, 1);
    expect(list.single.totalPaise, saved.totalPaise);
    expect((await tester.runAsync(() => c.read(appDataProvider).catalog.product(line.productId)))!.stockMilli, stockBefore - 6000);
    expect(find.text(list.single.number), findsWidgets, reason: 'back on the list');
  });

  testWidgets('more than what is left, or a pending purchase: refused with the reason', (tester) async {
    final c = await app(tester);
    final saved = await buy(tester, c);
    final line = (await tester.runAsync(() => c.read(appDataProvider).purchaseReturns.returnable(saved.id)))!.lines.single;
    go(tester, '/purchase-returns/purchase/${saved.id}');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ValueKey('pret-qty-${line.purchaseLineId}')), '99');
    await tester.pump();
    expect(find.textContaining('At most'), findsOneWidget);
    final pending = await buy(tester, c, received: false);
    go(tester, '/purchase-returns/purchase/${pending.id}');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pret-not-received')), findsOneWidget);
  });

  testWidgets('Add return asks for a purchase number: an unknown one says so, a real one opens its return page; the purchase popup has Return items', (tester) async {
    final c = await app(tester);
    final saved = await buy(tester, c);
    await tester.tap(find.text('Add return').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Purchase no.').last, 'NOPE');
    await tester.tap(find.text('Continue').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('There is no purchase with that number.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('Add return').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Purchase no.').last, saved.number);
    await tester.tap(find.text('Continue').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Return items from ${saved.number}'), findsWidgets);

    // from the purchase popup
    go(tester, '/purchases');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(saved.number).first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pur-return-items')));
    await tester.pumpAndSettle();
    expect(find.text('Return items from ${saved.number}'), findsWidgets);
  });
}
