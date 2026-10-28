import 'package:erp2/core/lan/lan_controller.dart';
import 'package:erp2/core/phone_words.dart';
import 'package:erp2/core/touch_device.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/design/tokens.dart';
import 'package:erp2/design/widgets.dart' show StatCard;
import 'package:erp2/features/billing/bill_panel.dart' show BillFooter;
import 'package:erp2/shell.dart' show TopBar, tabIconColor;
import 'package:erp2/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'lan_link_test.dart' show FakeWifi;
import 'helpers.dart';

// What these tests prove (the second round of phone fixes; every one is switched on only for a real phone or tablet by `touchDeviceProvider`, and each has
// a check that a computer window still looks as it did):
//  5 the selected tab icon can be seen on its pill, in light and dark;
//  6 a tablet or a phone turned sideways keeps out of the status bar, and shows no keyboard hints;
//  7 with big text the Bill footer takes less room and the card button keeps a readable name;
//  8 summary cards sit two to a row on a phone;
//  9 the phone says "phone", never "computer", Windows or F2;
// 10 the counter link shows its key, and a problem is scrolled into view.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

final onPhone = touchDeviceProvider.overrideWithValue(true);

void main() {
  test('the selected tab icon colour stands out from its pill for every accent, in light, dark and high contrast', () {
    for (final b in Brightness.values) {
      for (final a in Accent.values) {
        for (final hc in [false, true]) {
          final c = AppColors.build(b, accent: a, highContrast: hc);
          final icon = tabIconColor(c.primary, c.rowSelected, c.text);
          expect(contrast(icon, c.rowSelected), greaterThanOrEqualTo(3), reason: '$b $a highContrast=$hc');
        }
      }
    }
  });

  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    testWidgets('phone tab bar ($theme): the selected icon is visible on its pill; a computer window keeps the default', (tester) async {
      await pumpApp(tester, size: phone390, location: '/', theme: theme, motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [onPhone]);
      final ctx = tester.element(find.byType(NavigationBar));
      final data = NavigationBarTheme.of(ctx);
      final pill = ctx.c.rowSelected;
      expect(contrast(data.iconTheme!.resolve({WidgetState.selected})!.color!, pill), greaterThanOrEqualTo(3));
      expect(contrast(data.iconTheme!.resolve({})!.color!, ctx.c.surface), greaterThanOrEqualTo(3), reason: 'the other tabs can be read too');
    });
  }

  testWidgets('a computer window (narrow, no touch) keeps the Material default for the tab icons', (tester) async {
    await pumpApp(tester, size: phone390, location: '/', motion: MotionLevel.off, followSystemMotion: false);
    expect(NavigationBarTheme.of(tester.element(find.byType(NavigationBar))).iconTheme, isNull);
  });

  testWidgets('a tablet or a phone turned sideways stays out of the status bar; a computer does not move', (tester) async {
    await pumpApp(tester, size: tabletLandscape, location: '/', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [onPhone]);
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 20);
    tester.view.viewPadding = const FakeViewPadding(top: 40, bottom: 20);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(TopBar)).dy, greaterThanOrEqualTo(40));
  });

  testWidgets('a computer window has no inset to keep out of: the top bar stays at the top', (tester) async {
    await pumpApp(tester, size: tabletLandscape, location: '/', motion: MotionLevel.off, followSystemMotion: false);
    expect(tester.getTopLeft(find.byType(TopBar)).dy, 0);
  });

  testWidgets('the dashboard buttons show their keys on a computer and not on a touch device', (tester) async {
    await pumpApp(tester, size: tabletLandscape, location: '/', motion: MotionLevel.off, followSystemMotion: false);
    expect(find.textContaining('(F2)'), findsOneWidget);
    await pumpApp(tester, size: tabletLandscape, location: '/', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [onPhone]);
    expect(find.textContaining('(F2)'), findsNothing);
    expect(find.textContaining('Ctrl+Shift+N'), findsNothing);
    expect(find.text('New bill'), findsWidgets);
  });

  testWidgets('with big text the Bill footer is smaller on a phone, the print button becomes an icon and the card button keeps a readable name', (tester) async {
    await pumpApp(tester, size: phone390, location: '/bill', textScale: 2.0, motion: MotionLevel.off, followSystemMotion: false);
    final computerHeight = tester.getSize(find.byType(BillFooter)).height;
    expect(find.text('Card or other'), findsOneWidget);
    expect(find.byKey(const ValueKey('savePrintIcon')), findsNothing);
    await pumpApp(tester, size: phone390, location: '/bill', textScale: 2.0, motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [onPhone]);
    final phoneHeight = tester.getSize(find.byType(BillFooter)).height;
    expect(phoneHeight, lessThan(computerHeight * 0.9), reason: 'phone $phoneHeight vs $computerHeight');
    expect(find.byKey(const ValueKey('savePrintIcon')), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Card or other'), findsNothing);
  });

  testWidgets('at normal text the Bill footer on a phone is the same as before except the card name', (tester) async {
    await pumpApp(tester, size: phone390, location: '/bill', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [onPhone]);
    expect(find.byKey(const ValueKey('savePrintIcon')), findsNothing, reason: 'both buttons keep their words when the text is not big');
    expect(find.text('Save and print'), findsOneWidget);
  });

  testWidgets('summary cards: two to a row on a phone, one per line in a narrow computer window', (tester) async {
    await pumpApp(tester, size: phone390, location: '/credit', motion: MotionLevel.off, followSystemMotion: false);
    expect(tester.getTopLeft(find.byType(StatCard).at(0)).dy, isNot(tester.getTopLeft(find.byType(StatCard).at(1)).dy));
    await pumpApp(tester, size: phone390, location: '/credit', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [onPhone]);
    final a = tester.getTopLeft(find.byType(StatCard).at(0)), b = tester.getTopLeft(find.byType(StatCard).at(1));
    expect(a.dy, b.dy, reason: 'side by side');
    expect(b.dx, greaterThan(a.dx));
    final c = tester.getTopLeft(find.byType(StatCard).at(2));
    expect(c.dy, greaterThan(a.dy));
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });

  test('phoneWords rewrites the desktop wording and leaves the rest alone', () {
    expect(phoneWords('Match my computer'), 'Match my phone');
    expect(phoneWords("This computer's address"), 'The address of this phone');
    expect(phoneWords('The letter of THIS computer'), 'The letter of THIS phone');
    expect(phoneWords('Press F2 or tap New bill.'), 'Tap New bill.');
    expect(phoneWords('Make writing bigger if it is hard to read. Keys: Ctrl and + or -, and Ctrl 0 to reset.'), 'Make writing bigger if it is hard to read.');
    expect(phoneWords('If Windows asks to allow the program on the network, choose Allow (private network).'), isNot(contains('Windows')));
    expect(phoneWords('Changed on another computer'), 'Changed on another device');
    expect(phoneWords('Bills and payments'), 'Bills and payments');
  });

  test('the phone words of the texts seen on the phone have no computer, Windows or key left', () {
    const p = PhoneStrings();
    final texts = [
      p.themeSystem, p.wizSeriesLabel, p.wizSeriesHelp, p.wizSeriesPick, p.wizSeriesMine('B'), p.wizSeriesTaken('B'), p.lanAddress, p.lanFirewall, p.lanErrSelf, p.lanStartFailed,
      p.backupListTitle, p.restoreFromList, p.freeDisk, p.aboutPrivacyText, p.shopProfileSubtitle, p.lockOffStatus, p.helpStep1, p.setTextSizeHelp, p.setPaperHelp, p.syncBacklogHelp,
      p.attentionHelp, p.faq1a, p.syncOnHelp, p.syncNewData, p.conflictTitle, p.featHelp, p.animFollowSystemHelp, p.animSystemReducing, p.errIo,
    ];
    for (final t in texts) {
      expect(t, isNot(matches(RegExp(r'computer|Windows|\bF\d\b|Ctrl', caseSensitive: false))), reason: t);
    }
    expect(p.wizNumberingHelp, contains('phone or computer'), reason: 'the shop has both kinds of device');
    expect(const Strings().themeSystem, 'Match my computer', reason: 'a computer keeps its words');
  });

  testWidgets('on a phone Settings and About say phone, and Help and About have no keyboard shortcuts', (tester) async {
    await pumpApp(tester, size: const ScreenSpec('tall', 390, 3200), location: '/settings', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [onPhone]);
    expect(find.text('Match my phone'), findsOneWidget);
    expect(find.text('Match my computer'), findsNothing);
    await pumpApp(tester, size: const ScreenSpec('tall', 390, 3200), location: '/about', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [onPhone]);
    expect(find.byKey(const ValueKey('shortcuts-open')), findsNothing);
    expect(find.textContaining('on your computer'), findsNothing);
    await pumpApp(tester, size: const ScreenSpec('tall', 390, 3200), location: '/help', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [onPhone]);
    expect(find.text('Tap New bill.'), findsOneWidget);
    expect(find.text('F2'), findsNothing);
    await pumpApp(tester, size: const ScreenSpec('tall', 390, 3200), location: '/about', motion: MotionLevel.off, followSystemMotion: false);
    expect(find.byKey(const ValueKey('shortcuts-open')), findsOneWidget, reason: 'a computer keeps them');
  });

  testWidgets('counter link on a phone: the key is shown after switching on, and a failed link scrolls its message into view', (tester) async {
    final wifi = FakeWifi();
    final c = await pumpApp(tester, size: phone390, location: '/settings', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [onPhone, lanTransportProvider.overrideWithValue(wifi.at('10.0.0.1'))]);
    final sw = find.byKey(const ValueKey('lanSwitch'));
    await tester.scrollUntilVisible(sw, 400, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(sw);
    await tester.pumpAndSettle();
    await tester.tap(sw);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(c.read(lanProvider).on, isTrue);
    final shown = tester.widget<TextField>(find.byKey(const ValueKey('lanKey'))).controller!.text;
    expect(shown, isNotEmpty);
    expect(shown, c.read(lanProvider).key, reason: 'the owner can read and copy the key');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('lanHost')), 300, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const ValueKey('lanHost')), '10.0.0.99');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('lanLinkBtn')), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(const ValueKey('lanLinkBtn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lanLinkBtn')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lanError')), findsOneWidget);
    final r = tester.getRect(find.byKey(const ValueKey('lanError')));
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(844), reason: 'in view');
  });
}
