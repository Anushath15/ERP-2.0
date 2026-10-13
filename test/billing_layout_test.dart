import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/store.dart';
import 'helpers.dart';

/// The billing page must keep Grand Total, payment mode, Save and Save and Print PINNED
/// (same place, fully inside the window) however many lines the bill has, at every text size, with no blank gap at the bottom.
/// The Grand total text shrinks to fit a long amount, so compare its vertical centre; buttons by their top edge.
double pos(Rect r, String k) => k == 'total' ? r.center.dy : r.top;

void main() {
  final sizes = [desktop1920, desktop1366, desktop1280, tabletLandscape, tabletPortrait, phone390, phone360];
  for (final size in sizes) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final mode in [DocMode.invoice, DocMode.estimation]) {
        testWidgets('${mode.name} pinned footer at ${size.name}, text ${(scale * 100).round()}%, with 1, 10 and 100 lines', (tester) async {
          final c = await pumpApp(tester, size: size, location: mode == DocMode.invoice ? '/bill' : '/estimate', textScale: scale);
          final products = c.read(productsProvider);
          final cart = c.read(cartProvider(mode).notifier);
          final isPhone = size.w / scale < 700;
          final saveLabel = mode == DocMode.invoice ? 'Save bill' : 'Save estimate';

          Future<Map<String, Rect>> measure(int lines) async {
            cart.clear();
            for (var i = 0; i < lines; i++) {
              cart.add(products[i * 3]);
            }
            await tester.pumpAndSettle();
            if (isPhone) {
              await tester.tap(find.textContaining('Bill ('));
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull, reason: 'no layout overflow at $lines lines');
            return {
              'total': tester.getRect(find.byKey(const ValueKey('grandTotal'))),
              'save': tester.getRect(find.text(saveLabel)),
              'print': tester.getRect(find.text('Save and print')),
            };
          }

          final one = await measure(1);
          final ten = await measure(10);
          final hundred = await measure(100);
          for (final k in one.keys) {
            expect(pos(ten[k]!, k), closeTo(pos(one[k]!, k), 0.5), reason: '$k moved between 1 and 10 lines');
            expect(pos(hundred[k]!, k), closeTo(pos(one[k]!, k), 0.5), reason: '$k moved between 1 and 100 lines');
            expect(hundred[k]!.bottom, lessThanOrEqualTo(size.h), reason: '$k must stay inside the window');
            expect(hundred[k]!.top, greaterThanOrEqualTo(0), reason: '$k must stay inside the window');
            expect(hundred[k]!.height, greaterThan(5), reason: '$k must stay visible, not squeezed to nothing');
          }
          final lowest = [for (final k in ['save', 'print']) hundred[k]!.bottom].reduce(math.max);
          expect(size.h - lowest, lessThan(48), reason: 'no blank gap under the buttons');
          expect(find.byType(Scrollbar), findsWidgets);
        });
      }
    }
  }

  // The pinned footer must not move even while the Full-motion effects (slide-in, count-up, pulses) are playing.
  for (final size in [desktop1366, phone390]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Full animations: footer stays put while 100 lines are added, ${size.name}, text ${(scale * 100).round()}%', (tester) async {
        final c = await pumpApp(tester, size: size, location: '/bill', textScale: scale, motion: MotionLevel.full, followSystemMotion: false);
        final products = c.read(productsProvider);
        await tester.pump(const Duration(seconds: 1));
        final isPhone = size.w / scale < 700;
        if (isPhone) {
          await tester.tap(find.textContaining('Bill ('));
          await tester.pump(const Duration(milliseconds: 400));
        }
        final first = tester.getRect(find.text('Save bill'));
        final total0 = tester.getRect(find.byKey(const ValueKey('grandTotal'))).center.dy;
        for (var i = 0; i < 100; i++) {
          c.read(cartProvider(DocMode.invoice).notifier).add(products[i * 3]);
          await tester.pump(const Duration(milliseconds: 16)); // frames while the effects play
          expect(tester.takeException(), isNull, reason: 'line ${i + 1}');
          expect(tester.getRect(find.text('Save bill')).top, closeTo(first.top, 0.5), reason: 'Save moved while adding line ${i + 1}');
          expect(tester.getRect(find.byKey(const ValueKey('grandTotal'))).center.dy, closeTo(total0, 0.5));
        }
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }

  testWidgets('billing text size 250%: product names stay fully visible and the footer does not move', (tester) async {
    final c = await pumpApp(tester, size: desktop1920, location: '/bill');
    c.read(settingsProvider.notifier).set((s) => s.copyWith(billingScale: 2.5));
    final p = c.read(productsProvider);
    for (var i = 0; i < 5; i++) {
      c.read(cartProvider(DocMode.invoice).notifier).add(p[i * 7]);
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final total = tester.getRect(find.byKey(const ValueKey('grandTotal')));
    c.read(settingsProvider.notifier).set((s) => s.copyWith(billingScale: 1.0));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('grandTotal'))).top, closeTo(total.top, 0.5));
    final texts = tester.widgetList<Text>(find.byType(Text)).where((t) => (t.data ?? '').contains('BOLT') || (t.data ?? '').contains('BLADE'));
    for (final t in texts) {
      expect(t.overflow, isNot(TextOverflow.ellipsis));
      expect(t.maxLines, isNull);
    }
  });

  testWidgets('selling at stock 0 warns but never blocks', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/bill');
    final out = c.read(productsProvider).firstWhere((p) => p.outOfStock);
    c.read(cartProvider(DocMode.invoice).notifier).add(out);
    await tester.pumpAndSettle();
    expect(find.text('Stock is 0, selling anyway'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Save bill');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });
}
