import 'package:erp2/core/nav_history.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// What these tests prove: Back returns to the page the owner came from (not always the dashboard), the history forgets the way back once used, and every page
// but the dashboard has the Back button on the top bar.
void main() {
  test('the history goes forward, and Back steps over the page it leaves', () {
    final h = NavHistory();
    h.visit('/');
    expect(h.canGoBack, isFalse);
    h.visit('/products');
    h.visit('/customers');
    expect(h.previous, '/products');
    h.visit('/products'); // that was Back
    expect(h.previous, '/');
    h.visit('/products');
    expect(h.previous, '/', reason: 'the same page twice is one step');
  });

  test('the history is limited so it never grows without end', () {
    final h = NavHistory();
    for (var i = 0; i < 500; i++) {
      h.visit('/p$i');
    }
    expect(h.canGoBack, isTrue);
  });

  testWidgets('Back on the top bar returns to the page before; the dashboard has none', (tester) async {
    await pumpApp(tester, size: const ScreenSpec('wide', 1500, 1000), location: '/', motion: MotionLevel.off, followSystemMotion: false);
    expect(find.byKey(const ValueKey('topbar-back')), findsNothing);
    final r = GoRouter.of(tester.element(find.byType(Scaffold).first));
    r.go('/products');
    await tester.pumpAndSettle();
    r.go('/customers');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('topbar-back')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('topbar-back')));
    await tester.pumpAndSettle();
    expect(r.routerDelegate.currentConfiguration.uri.path, '/products');
    await tester.tap(find.byKey(const ValueKey('topbar-back')));
    await tester.pumpAndSettle();
    expect(r.routerDelegate.currentConfiguration.uri.path, '/');
    expect(find.byKey(const ValueKey('topbar-back')), findsNothing);
  });
}
