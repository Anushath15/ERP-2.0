import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/features/dashboard/dashboard_screen.dart';
import 'package:erp2/features/sales/sales_screens.dart';
import 'package:erp2/shell.dart';
import 'helpers.dart';

/// Switching pages must never look like a slide show: in NO frame may the old page and the new page both be in the picture,
/// the new page must have its content in its very first frame, and the sidebar and header must stay put.
void main() {
  GoRouter routerOf(WidgetTester t) => GoRouter.of(t.element(find.byType(Scaffold).first));

  for (final level in MotionLevel.values) {
    testWidgets('${level.name}: frame by frame, the old page is gone at once and the new page has content in its first frame', (tester) async {
      await pumpApp(tester, size: desktop1366, location: '/', motion: level, followSystemMotion: false);
      await tester.pump(const Duration(seconds: 1));
      final shellBefore = tester.element(find.byType(AppShell));
      final sidebarRect = tester.getRect(find.byType(AppShell));

      routerOf(tester).go('/sales');
      final bothSeen = <int>[];
      var firstFrameHasContent = false;
      for (var ms = 0; ms <= 400; ms += 8) {
        await tester.pump(ms == 0 ? Duration.zero : const Duration(milliseconds: 8));
        final old = find.byType(DashboardScreen).evaluate().isNotEmpty;
        final fresh = find.byType(SalesRegisterScreen).evaluate().isNotEmpty;
        if (old && fresh) bothSeen.add(ms);
        if (ms == 0) firstFrameHasContent = fresh && find.text('Sales register').evaluate().isNotEmpty && !old;
      }
      expect(bothSeen, isEmpty, reason: '${level.name}: old and new page were both present at ms $bothSeen');
      expect(firstFrameHasContent, isTrue, reason: '${level.name}: the new page shows its content (title) in its first frame and the old page is not there');
      expect(tester.element(find.byType(AppShell)), same(shellBefore), reason: 'the shell (sidebar, header) is not rebuilt as a new element');
      expect(tester.getRect(find.byType(AppShell)), sidebarRect);
    });
  }

  for (final level in [MotionLevel.gentle, MotionLevel.full]) {
    testWidgets('${level.name}: the new page may fade in only a little (100 ms, never from nothing) and is finished by 150 ms', (tester) async {
      await pumpApp(tester, size: desktop1366, location: '/', motion: level, followSystemMotion: false);
      await tester.pump(const Duration(seconds: 1));
      routerOf(tester).go('/sales');
      await tester.pump();
      double opacity() => tester.widgetList<FadeTransition>(find.ancestor(of: find.byType(SalesRegisterScreen), matching: find.byType(FadeTransition))).map((f) => f.opacity.value).fold<double>(1, (a, b) => a * b);
      expect(opacity(), greaterThanOrEqualTo(0.5), reason: 'first frame is already clearly visible');
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacity(), 1.0);
    });
  }

  testWidgets('off: no animation runs at all', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/', motion: MotionLevel.off, followSystemMotion: false);
    routerOf(tester).go('/sales');
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
