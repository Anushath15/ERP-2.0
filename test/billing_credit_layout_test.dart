import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/store.dart';
import 'helpers.dart';

/// The pinned footer now also holds Amount received, the Balance / Change line and the payment mode. All of it must stay put,
/// fully inside the window, whatever the number of lines and whatever the payment situation (paid in full, part paid with a
/// customer, part paid as walk-in, overpaid), at every window size and at 100% and 200% text.
double pos(Rect r, String k) => (k == 'total' || k == 'balanceLine') ? r.center.dy : r.top;

void main() {
  final sizes = [desktop1920, desktop1366, desktop1280, tabletLandscape, tabletPortrait, phone390, phone360];
  for (final size in sizes) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('credit rows pinned: ${size.name}, text ${(scale * 100).round()}%', (tester) async {
        final c = await pumpApp(tester, size: size, location: '/bill', textScale: scale);
        final products = c.read(productsProvider);
        final cart = c.read(cartProvider(DocMode.invoice).notifier);
        final isPhone = size.w / scale < 700;
        final customers = c.read(customersProvider);

        Future<Map<String, Rect>> measure(int lines, String scenario) async {
          cart.clear();
          for (var i = 0; i < lines; i++) {
            cart.add(products[i * 3]);
          }
          switch (scenario) {
            case 'full':
              break;
            case 'part-named':
              cart.setCustomer(customers.first);
              cart.setReceived(10000);
            case 'part-walkin':
              cart.setReceived(10000);
            case 'over-named':
              cart.setCustomer(customers.first);
              cart.setReceived(100000000);
            case 'nothing':
              cart.setReceived(0);
          }
          await tester.pumpAndSettle();
          if (isPhone) {
            await tester.tap(find.textContaining('Bill ('));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull, reason: '$scenario with $lines lines: no layout overflow');
          return {
            'total': tester.getRect(find.byKey(const ValueKey('grandTotal'))),
            'received': tester.getRect(find.byKey(const ValueKey('receivedField'))),
            'balanceLine': tester.getRect(find.byKey(const ValueKey('balanceLine'))),
            'save': tester.getRect(find.text('Save bill')),
            'print': tester.getRect(find.text('Save and print')),
          };
        }

        final base = await measure(1, 'full');
        for (final scenario in ['full', 'part-named', 'part-walkin', 'over-named', 'nothing']) {
          for (final lines in [1, 10, 100]) {
            final m = await measure(lines, scenario);
            for (final k in base.keys) {
              expect(pos(m[k]!, k), closeTo(pos(base[k]!, k), 0.6), reason: '$k moved ($scenario, $lines lines)');
              expect(m[k]!.bottom, lessThanOrEqualTo(size.h), reason: '$k must stay inside the window ($scenario, $lines lines)');
              expect(m[k]!.top, greaterThanOrEqualTo(0), reason: '$k must stay inside the window');
              expect(m[k]!.height, greaterThan(4), reason: '$k visible');
            }
          }
        }
        final lowest = ['save', 'print'].map((k) => base[k]!.bottom).reduce(math.max);
        expect(size.h - lowest, lessThan(48), reason: 'no blank gap under the buttons');
      });
    }
  }

  testWidgets('Ctrl+Shift+L fills the bill with 100 lines (preview helper for the owner)', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/bill');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(c.read(cartProvider(DocMode.invoice)).lines.length, 100);
    expect(tester.takeException(), isNull);
  });
}
