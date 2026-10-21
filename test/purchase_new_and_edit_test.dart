import 'package:erp2/data/repo/purchase_repo.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/actions.dart' show purchasesVersionProvider;
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove, on the purchase screens: a product that is not in the list is made from the Add purchase page and goes straight into the items, the
// purchase brings its stock; a saved purchase is opened for editing from its popup (filled in, the dealer fixed), and saving changes the stock and the account.
void main() {
  Future<ProviderContainer> app(WidgetTester t, {String loc = '/purchases'}) => pumpApp(t, size: const ScreenSpec('tall', 1500, 3600), location: loc, motion: MotionLevel.off, followSystemMotion: false);
  Finder field(String label) => find.widgetWithText(TextFormField, label).last;
  Future<void> settle(WidgetTester t, [int ms = 500]) async {
    await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await t.pumpAndSettle();
  }

  testWidgets('New product on the Add purchase page: the form has no stock box, the product joins the items, the purchase brings its stock', (tester) async {
    final c = await app(tester, loc: '/purchases/new');
    final before = c.read(productsProvider).length;
    await tester.ensureVisible(find.byKey(const ValueKey('pur-new-product')));
    await tester.tap(find.byKey(const ValueKey('pur-new-product')));
    await tester.pumpAndSettle();
    expect(find.text('Stock now'), findsNothing, reason: 'the purchase brings the stock');
    await tester.enterText(field('Product name'), 'BRAND NEW SOCKET');
    await tester.enterText(field('Selling price'), '120');
    await tester.enterText(field('Buying price'), '80');
    await tester.enterText(field('Minimum stock (warn me when stock falls to this)'), '2');
    await tester.pump();
    await tester.tap(find.text('Save').last);
    await settle(tester);
    expect(c.read(productsProvider).length, before + 1);
    final made = c.read(productsProvider).firstWhere((p) => p.name == 'BRAND NEW SOCKET');
    expect(made.stockMilli, 0);
    expect(made.code, isNotEmpty);
    expect(find.byKey(ValueKey('pur-qty-${made.id}')), findsOneWidget, reason: 'it is already in the items');
    expect((tester.widget(find.byKey(ValueKey('pur-rate-${made.id}'))) as TextField).controller!.text, '80.00', reason: 'the buying price became the rate');
    await tester.enterText(find.byKey(ValueKey('pur-qty-${made.id}')), '6');
    await tester.ensureVisible(find.byKey(const ValueKey('pur-save')));
    await tester.tap(find.byKey(const ValueKey('pur-save')));
    await settle(tester, 700);
    expect(tester.takeException(), isNull);
    final p = (await tester.runAsync(() => c.read(appDataProvider).catalog.product(made.id)))!;
    expect(p.stockMilli, 6000, reason: 'the purchase put the stock in');
    final list = (await tester.runAsync(() => c.read(appDataProvider).purchases.list()))!;
    expect(list.single.items, 1);
  });

  testWidgets('a saved purchase is edited from its popup: filled in, dealer fixed, a changed quantity moves the stock and the account', (tester) async {
    final c = await app(tester);
    final product = c.read(productsProvider).first;
    final dealer = c.read(recsProvider('dealers')).first;
    final d = c.read(appDataProvider);
    final saved = (await tester.runAsync(() => d.purchases.savePurchase(SavePurchaseInput(
          idemKey: 'edit-1',
          dealerId: dealer.id,
          at: DateTime(2026, 10, 10, 10),
          lines: [PurchaseLineInput(productId: product.id, name: product.name, unit: product.unit, qtyMilli: 5000, ratePaise: 10000, gstBp: product.gstBp)],
          paidPaise: 0,
        ))))!;
    await tester.runAsync(() => c.read(productsProvider.notifier).reload([product.id]));
    final stockAfterFirst = c.read(productsProvider).firstWhere((p) => p.id == product.id).stockMilli;
    c.read(purchasesVersionProvider.notifier).bump(); // the list reads again
    await settle(tester, 200);
    await tester.tap(find.text(saved.number).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pur-edit')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pur-edit')));
    await settle(tester);
    expect(find.text('Edit purchase ${saved.number}'), findsWidgets);
    final qty = tester.widget<TextField>(find.byKey(ValueKey('pur-qty-${product.id}')));
    expect(qty.controller!.text, '5', reason: 'the form is filled in from the saved purchase');
    expect(tester.widget<DropdownButtonFormField<String>>(find.byKey(const ValueKey('pur-dealer'))).onChanged, isNull, reason: 'the dealer is fixed');
    await tester.enterText(find.byKey(ValueKey('pur-qty-${product.id}')), '8');
    await tester.ensureVisible(find.byKey(const ValueKey('pur-save')));
    await tester.tap(find.byKey(const ValueKey('pur-save')));
    await settle(tester, 700);
    expect(tester.takeException(), isNull);
    final detail = (await tester.runAsync(() => d.purchases.detail(saved.id)))!;
    expect(detail.lines.single.qtyMilli, 8000);
    expect(detail.row.number, saved.number);
    expect((await tester.runAsync(() => d.catalog.product(product.id)))!.stockMilli, stockAfterFirst + 3000, reason: '8 instead of 5: three more pieces');
    final balance = (await tester.runAsync(() => d.ledger.balanceOf(dealer.id)))!;
    expect(balance, detail.row.totalPaise, reason: 'the dealer is owed the new total');
    expect(find.text('Changes to ${saved.number} saved.'), findsWidgets);
  });
}
