import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

/// Every screen must still lay out cleanly (no RenderFlex overflow or other layout error) at text sizes 80% to 200%,
/// at desktop, tablet and phone widths, in both themes.
const routes = <String>[
  '/signin', '/forgot', '/wizard', '/', '/bill', '/estimate', '/estimates', '/sales', '/sales-returns', '/delivery', '/products', '/categories',
  '/inventory', '/purchases', '/purchase-returns', '/adjustments', '/customers', '/dealers', '/credit', '/staff', '/expenses', '/closing', '/reports',
  '/export', '/import', '/warranty', '/projects', '/notifications', '/settings', '/health', '/help', '/about', '/more', '/preview/a4', '/preview/80',
  '/preview/58', '/preview/estimate',
];

const scales = [0.8, 1.0, 1.25, 1.5, 2.0];

void main() {
  final sizes = [desktop1920, desktop1280, tabletPortrait, phone360];
  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets('all screens at ${size.name}, text ${(scale * 100).round()}%, dark', timeout: const Timeout(Duration(minutes: 10)), (tester) async {
        for (final r in routes) {
          await pumpApp(tester, size: size, location: r, textScale: scale);
          final err = tester.takeException();
          expect(err, isNull, reason: '$r at ${size.name} ${(scale * 100).round()}%: $err');
        }
      });
    }
  }
  for (final size in [desktop1366, tabletLandscape, phone390]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('all screens at ${size.name}, text ${(scale * 100).round()}%, light', timeout: const Timeout(Duration(minutes: 10)), (tester) async {
        for (final r in routes) {
          await pumpApp(tester, size: size, location: r, textScale: scale, theme: ThemeMode.light);
          final err = tester.takeException();
          expect(err, isNull, reason: '$r at ${size.name} ${(scale * 100).round()}% light: $err');
        }
      });
    }
  }
}
