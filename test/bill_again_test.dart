import 'package:erp2/data/context.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// What this test proves: "Bill again" on a saved bill opens the New bill page with the same items and quantities for the same customer, each at
// today's selling price; nothing is saved until the person saves.
void main() {
  testWidgets('Bill again copies the items to a new bill at today\'s prices', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('wide', 1600, 1200), location: '/sales', motion: MotionLevel.off, followSystemMotion: false);
    final d = c.read(appDataProvider);
    final row = (await tester.runAsync(() => d.db.rows('SELECT id FROM bills WHERE cancelled = 0 ORDER BY customer_id IS NULL, billed_at DESC LIMIT 1')))!.single;
    final id = row.read<String>('id');
    final detail = (await tester.runAsync(() => d.bills.detail(id)))!;
    final before = (await tester.runAsync(() => d.db.scalarInt('SELECT COUNT(*) FROM bills')))!;
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/sales?open=${Uri.encodeQueryComponent(id)}');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('bill-again')));
    await tester.tap(find.byKey(const ValueKey('bill-again')));
    await tester.pumpAndSettle();
    expect(GoRouter.of(tester.element(find.byType(Scaffold).first)).routerDelegate.currentConfiguration.uri.path, '/bill');
    final cart = c.read(cartProvider(DocMode.invoice));
    expect([for (final l in cart.lines) (l.product.id, l.qtyMilli)], [for (final l in detail.lines) (l.productId, l.qtyMilli)]);
    expect(cart.customer?.id, detail.row.customerId);
    final products = {for (final p in c.read(productsProvider)) p.id: p};
    for (final l in cart.lines) {
      expect(l.rate, products[l.product.id]!.pricePaise, reason: 'today\'s price');
    }
    expect((await tester.runAsync(() => d.db.scalarInt('SELECT COUNT(*) FROM bills')))!, before, reason: 'nothing saved yet');
  });
}
