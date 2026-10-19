import 'package:erp2/design/motion_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// Top bar: the status chip and the icons sit in the right corner; the profile icon goes straight to the Shop profile (no menu);
// the Shop profile page has the Settings and Sign out buttons.
void main() {
  Future<dynamic> app(WidgetTester t, {String loc = '/estimates', ScreenSpec size = const ScreenSpec('desk', 1600, 900)}) =>
      pumpApp(t, size: size, location: loc, motion: MotionLevel.off, followSystemMotion: false);

  testWidgets('the icons are at the right edge of the screen, in this order: status, smaller, larger, theme, profile', (tester) async {
    await app(tester);
    final profile = tester.getTopRight(find.byKey(const ValueKey('topbar-profile')));
    expect(profile.dx, greaterThan(1600 - 40), reason: 'the profile icon is in the right corner');
    final xs = [for (final i in [Icons.text_decrease, Icons.text_increase, Icons.light_mode_outlined]) tester.getCenter(find.byIcon(i)).dx];
    expect(xs[0] < xs[1] && xs[1] < xs[2], isTrue);
    expect(xs[2], lessThan(profile.dx));
    expect(xs[0], greaterThan(1600 - 320), reason: 'all icons are grouped on the right, not in the middle');
  });

  testWidgets('the profile icon opens the Shop profile directly: no menu with Settings or Sign out', (tester) async {
    await app(tester);
    await tester.tap(find.byKey(const ValueKey('topbar-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Shop details'), findsWidgets, reason: 'on the Shop profile page');
    expect(find.byType(PopupMenuItem<String>), findsNothing);
  });

  testWidgets('the Shop profile page has Settings and Sign out', (tester) async {
    await app(tester, loc: '/shop');
    expect(find.byKey(const ValueKey('shop-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-signout')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shop-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop-settings')), findsNothing, reason: 'left the Shop profile for the Settings page');
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('Sign out on the Shop profile goes to the sign-in page', (tester) async {
    await app(tester, loc: '/shop');
    await tester.tap(find.byKey(const ValueKey('shop-signout')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget, reason: 'it asks first');
    expect(find.byKey(const ValueKey('shop-signout')), findsOneWidget, reason: 'nothing happened yet');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop-signout')), findsNothing);
    expect(find.byType(TextField), findsWidgets, reason: 'the sign-in form');
  });

  testWidgets('on a phone there is no top bar (bottom menu instead) and nothing overflows', (tester) async {
    await app(tester, size: const ScreenSpec('phone', 360, 740));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('topbar-profile')), findsNothing);
  });
}
