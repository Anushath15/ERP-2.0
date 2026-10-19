import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/fake/credit_store.dart' show seedCredit;
import 'package:erp2/demo/seed.dart';
import 'helpers.dart';

/// Every screen must still lay out cleanly (no RenderFlex overflow or other layout error) at text sizes 80% to 200%,
/// at desktop, tablet and phone widths, in both themes. All failures of a configuration are listed together.
final _credit = seedCredit(seedCustomers(), fixedNow);
final _dealerId = seedDealers().firstWhere((d) => d.i('balance') > 0).id;
final _dueId = _credit.entries.firstWhere((e) => e.value.balance > 0 && e.value.bills.length > 1).key;

final routes = <String>[
  '/signin', '/forgot', '/wizard', '/', '/bill', '/estimate', '/estimates', '/sales', '/sales-returns', '/products', '/labels', '/categories',
  '/inventory', '/purchases', '/purchase-returns', '/adjustments', '/customers', '/dealers', '/credit', '/staff', '/expenses', '/closing', '/reports',
  '/export', '/import', '/warranty', '/notifications', '/settings', '/health', '/fix', '/backups', '/restore', '/help', '/about', '/more', '/preview/a4', '/preview/80',
  '/preview/58', '/preview/estimate', '/preview/payment', '/customers/$_dueId', '/customers/$_dueId/statement',
  '/shop', '/dealers/$_dealerId', '/preview/a5',
];

const scales = [0.8, 1.0, 1.25, 1.5, 2.0];

Future<List<String>> check(WidgetTester tester, ScreenSpec size, double scale, ThemeMode theme) async {
  final failures = <String>[];
  for (final r in routes) {
    await pumpApp(tester, size: size, location: r, textScale: scale, theme: theme);
    final err = tester.takeException();
    if (err != null) failures.add('$r: ${err.toString().split('\n').first}');
  }
  return failures;
}

void main() {
  final sizes = [desktop1920, desktop1280, tabletPortrait, phone360];
  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets('all screens at ${size.name}, text ${(scale * 100).round()}%, dark', timeout: const Timeout(Duration(minutes: 10)), (tester) async {
        final failures = await check(tester, size, scale, ThemeMode.dark);
        expect(failures, isEmpty, reason: 'layout errors at ${size.name}, text ${(scale * 100).round()}%');
      });
    }
  }
  for (final size in [desktop1366, tabletLandscape, phone390]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('all screens at ${size.name}, text ${(scale * 100).round()}%, light', timeout: const Timeout(Duration(minutes: 10)), (tester) async {
        final failures = await check(tester, size, scale, ThemeMode.light);
        expect(failures, isEmpty, reason: 'layout errors at ${size.name}, text ${(scale * 100).round()}%, light');
      });
    }
  }
}
