import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: a part of the program can be switched off on one computer and on again; the choice is remembered; the hidden part really is not
// shown; an unknown name in the saved settings is ignored (an old or damaged file never switches off something else).
void main() {
  test('everything is on by default; the switches are saved and read back; unknown names are ignored', () {
    const s = AppSettings();
    expect(AppFeature.values.every(s.featureOn), isTrue);
    final off = s.copyWith(featuresOff: {AppFeature.excelFill.name});
    expect(off.featureOn(AppFeature.excelFill), isFalse);
    expect(off.featureOn(AppFeature.counterLink), isTrue);
    final back = AppSettings.fromJson(off.toJson());
    expect(back.featuresOff, {'excelFill'});
    expect(AppSettings.fromJson({'featuresOff': ['nonsense', 'brandSwitch', 5]}).featuresOff, {'brandSwitch'});
    expect(AppSettings.fromJson({'featuresOff': 'oops'}).featuresOff, isEmpty);
  });

  testWidgets('switch Excel off in Settings > Features: the Excel button leaves the Products page; on again: it is back', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 3000), location: '/settings', motion: MotionLevel.off, followSystemMotion: false);
    await tester.ensureVisible(find.byKey(const ValueKey('feature-excelFill')));
    await tester.tap(find.byKey(const ValueKey('feature-excelFill')));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).featureOn(AppFeature.excelFill), isFalse);
    c.read(settingsProvider.notifier).set((x) => x.copyWith());
    // the products page
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/products');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('productsExcel')), findsNothing);
    router.go('/settings');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('feature-excelFill')));
    await tester.tap(find.byKey(const ValueKey('feature-excelFill')));
    await tester.pumpAndSettle();
    router.go('/products');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('productsExcel')), findsOneWidget);
  });

  testWidgets('switch the counter link off: its card leaves Settings', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 3000), location: '/settings', motion: MotionLevel.off, followSystemMotion: false);
    expect(find.byKey(const ValueKey('lanSwitch')), findsOneWidget);
    c.read(settingsProvider.notifier).set((x) => x.copyWith(featuresOff: {AppFeature.counterLink.name}));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lanSwitch')), findsNothing);
  });
}
