import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/store.dart';
import 'helpers.dart';

/// The billing page must keep Grand Total, payment mode, Save, Save and Print and Preview PINNED
/// (same place, inside the window) however many lines the bill has, with no blank gap at the bottom.
void main() {
  final sizes = [desktop1920, desktop1366, desktop1280, tabletLandscape, tabletPortrait, phone390, phone360];
  for (final size in sizes) {
    for (final mode in [DocMode.invoice, DocMode.estimation]) {
      testWidgets('${mode.name} pinned footer at ${size.name} with 1, 10 and 100 lines', (tester) async {
        final c = await pumpApp(tester, size: size, location: mode == DocMode.invoice ? '/bill' : '/estimate');
        final products = c.read(productsProvider);
        final cart = c.read(cartProvider(mode).notifier);
        final isPhone = size.w < 700;

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
          final r = <String, Rect>{
            'total': tester.getRect(find.byKey(const ValueKey('grandTotal'))),
            'save': tester.getRect(find.text(mode == DocMode.invoice ? 'Save bill' : 'Save estimate')),
            'print': tester.getRect(find.text('Save and print')),
            'preview': tester.getRect(find.text('Preview')),
          };
          return r;
        }

        final one = await measure(1);
        final ten = await measure(10);
        final hundred = await measure(100);
        for (final k in one.keys) {
          expect(ten[k]!.top, closeTo(one[k]!.top, 0.5), reason: '$k top moved between 1 and 10 lines');
          expect(hundred[k]!.top, closeTo(one[k]!.top, 0.5), reason: '$k top moved between 1 and 100 lines');
          expect(hundred[k]!.bottom, lessThanOrEqualTo(size.h), reason: '$k must stay inside the window');
        }
        // no blank gap: the buttons sit within 40px of the bottom edge of the page (phone: above the bottom bar if any)
        expect(size.h - hundred['save']!.bottom, lessThan(40), reason: 'no blank gap under the buttons');
        // the list of lines scrolls by itself; the page does not
        expect(find.byType(Scrollbar), findsWidgets);
      });
    }
  }

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
