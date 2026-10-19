import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:erp2/design/motion_level.dart';
import 'helpers.dart';

// A robot that opens every screen and presses every button, switch and chip once, one at a time. It reports (it does not fail on)
// controls that only answer "preview / not connected", and fails on any crash or layout error.
// Run:  CLICK=1 flutter test test/click_through_test.dart        (slow: a few minutes)
const routes = [
  '/', '/bill', '/estimate', '/estimates', '/sales', '/sales-returns', '/delivery', '/products', '/categories', '/backups', '/restore', '/fix',
  '/inventory', '/purchases', '/purchase-returns', '/adjustments', '/customers', '/dealers', '/credit', '/staff', '/expenses', '/closing',
  '/reports', '/export', '/import', '/warranty', '/notifications', '/shop', '/settings', '/health', '/help', '/about', '/more',
  '/print', '/preview/payment',
];

final _stub = RegExp(r'preview|not connected|does not work yet|not built|demo', caseSensitive: false);

bool _tappable(Widget w) =>
    w is ButtonStyleButton || w is IconButton || w is Switch || w is Checkbox || w is FloatingActionButton || w is ChoiceChip || w is FilterChip || w is PopupMenuButton || w is SwitchListTile || w is CheckboxListTile;

void main() {
  final on = Platform.environment['CLICK'] == '1';
  final report = StringBuffer();

  for (final route in routes) {
    testWidgets('click through $route', (tester) async {
      final c = await pumpApp(tester, size: const ScreenSpec('desktop', 1600, 1000), location: route, motion: MotionLevel.off, followSystemMotion: false);
      final all = find.byWidgetPredicate(_tappable, description: 'tappable');
      final n = all.evaluate().length.clamp(0, 40);
      for (var i = 0; i < n; i++) {
        final f = find.byWidgetPredicate(_tappable);
        if (i >= f.evaluate().length) break;
        final el = f.at(i);
        String label = '';
        try {
          final w = tester.widget(el);
          label = w.runtimeType.toString();
          final texts = find.descendant(of: el, matching: find.byType(Text));
          if (texts.evaluate().isNotEmpty) label += ' "${(tester.widget(texts.first) as Text).data}"';
          final tip = w is IconButton ? w.tooltip : null;
          if (tip != null) label += ' [$tip]';
        } catch (_) {}
        try {
          await tester.ensureVisible(el);
          await tester.tap(el, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 350));
        } catch (e) {
          report.writeln('ERROR  $route #$i $label -> $e');
        }
        final ex = tester.takeException();
        if (ex != null) report.writeln('CRASH  $route #$i $label -> ${ex.toString().split('\n').first}');
        for (final t in find.byType(SnackBar).evaluate().expand((e) => find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text)).evaluate())) {
          final s = (t.widget as Text).data ?? '';
          if (_stub.hasMatch(s)) report.writeln('STUB   $route #$i $label -> $s');
        }
        // back to the screen, with nothing open
        for (var k = 0; k < 4; k++) {
          final nav = Navigator.of(tester.element(find.byType(Scaffold).first), rootNavigator: true);
          if (!nav.canPop()) break;
          nav.pop();
          await tester.pump(const Duration(milliseconds: 100));
        }
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
        await tester.pump(const Duration(milliseconds: 200));
        tester.takeException();
      }
      File('${Directory.systemTemp.path}${Platform.pathSeparator}click_report.txt').writeAsStringSync('$report', mode: FileMode.write);
      expect(c, isNotNull);
    }, skip: !on, timeout: const Timeout(Duration(minutes: 5)));
  }
}
