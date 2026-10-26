import 'package:erp2/design/motion_level.dart';
import 'package:erp2/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// What these tests prove: the side menu is short (Inventory, no Purchases / Purchase returns / Fix stock / Categories / Orders), those pages open from inside
// Inventory and Purchases, and while one of them is open the menu shows Inventory as the current place.
void main() {
  test('the menu has Inventory and none of the pages that now live inside it', () {
    final paths = [for (final g in navGroups) for (final i in g.items) i.path];
    expect(paths, contains('/inventory'));
    for (final p in ['/purchases', '/purchase-returns', '/adjustments', '/categories', '/orders']) {
      expect(paths, isNot(contains(p)), reason: p);
    }
    expect(navHome('/purchases/new'), '/inventory');
    expect(navHome('/purchase-returns'), '/inventory');
    expect(navHome('/orders/abc'), '/dealers');
    expect(navHome('/products'), '/products');
  });

  testWidgets('Inventory opens Purchases, Fix stock and Categories; Purchases opens Purchase returns', (tester) async {
    await pumpApp(tester, size: const ScreenSpec('wide', 1600, 1100), location: '/inventory', motion: MotionLevel.off, followSystemMotion: false);
    GoRouter router() => GoRouter.of(tester.element(find.byType(Scaffold).first));
    String at() => router().routerDelegate.currentConfiguration.uri.path;
    expect(find.text('Inventory'), findsWidgets);
    for (final (key, path) in [('inv-fix-stock', '/adjustments'), ('inv-categories', '/categories'), ('inv-purchases', '/purchases')]) {
      router().go('/inventory');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(at(), path, reason: key);
    }
    await tester.tap(find.byKey(const ValueKey('purchases-returns')));
    await tester.pumpAndSettle();
    expect(at(), '/purchase-returns');
  });
}
