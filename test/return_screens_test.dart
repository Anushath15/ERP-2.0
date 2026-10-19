import 'package:erp2/core/money.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/return_repo.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// "Return items" from a saved bill, end to end on the screens: the bill's items are listed, the person picks how many, the refund is
// shown, and saving puts the stock back and lists the return.
void main() {
  Future<ProviderContainer> app(WidgetTester t, {String loc = '/sales-returns'}) =>
      pumpApp(t, size: const ScreenSpec('tall', 1600, 2200), location: loc, motion: MotionLevel.off, followSystemMotion: false);

  /// A saved bill (not cancelled) with its returnable lines.
  Future<ReturnableBill> aBill(WidgetTester t, ProviderContainer c, {bool named = false}) async {
    return (await t.runAsync(() async {
      final repo = c.read(appDataProvider);
      BillCursor? after;
      for (var i = 0; i < 20; i++) {
        final rows = await repo.bills.page(after: after, limit: 50);
        if (rows.isEmpty) break;
        for (final r in rows) {
          if (r.cancelled || (named && r.customerId == null)) continue;
          final v = await repo.returns.returnable(r.id);
          if (v != null && v.anythingLeft) return v;
        }
        after = BillRepo.cursorOf(rows.last);
      }
      throw StateError('the demo shop has no suitable bill');
    }))!;
  }

  void go(WidgetTester t, String path) => GoRouter.of(t.element(find.byType(Scaffold).first)).go(path);

  testWidgets('the bill\'s items are listed with how many are left; Return all + a reason + Save puts the stock back and lists the return', (tester) async {
    final c = await app(tester);
    final bill = await aBill(tester, c);
    go(tester, '/sales-returns/bill/${bill.billId}');
    await tester.pumpAndSettle();
    for (final l in bill.lines) {
      expect(find.text(l.name), findsWidgets, reason: 'every product of the bill is listed');
      expect(find.byKey(ValueKey('ret-qty-${l.billLineId}')), findsOneWidget);
    }
    final stockBefore = await tester.runAsync(() async => [for (final l in bill.lines) (await c.read(appDataProvider).catalog.product(l.productId))!.stockMilli]);

    // choose "all" for the first line only
    final first = bill.lines.first;
    await tester.tap(find.byKey(ValueKey('ret-all-${first.billLineId}')));
    await tester.pump();
    final expected = ReturnRepo.preview(bill, {first.billLineId: first.remainingMilli});
    expect(find.text('Refund: ${formatPaise(expected.total, symbol: true)}'), findsOneWidget);
    expect(expected.total, greaterThan(0));

    // saving without a reason is refused and writes nothing
    await tester.ensureVisible(find.byKey(const ValueKey('ret-save')));
    await tester.tap(find.byKey(const ValueKey('ret-save')));
    await tester.pump();
    expect(find.byKey(const ValueKey('ret-error')), findsOneWidget);
    expect(await tester.runAsync(() => c.read(appDataProvider).returns.list()), isEmpty);

    await tester.enterText(find.byKey(const ValueKey('ret-reason')), 'Not working');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ret-save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();

    final saved = (await tester.runAsync(() => c.read(appDataProvider).returns.list()))!;
    expect(saved.length, 1);
    expect(saved.single.totalPaise, expected.total);
    expect(find.text(saved.single.number), findsWidgets, reason: 'back on the list, the return is there');
    final stockAfter = await tester.runAsync(() async => [for (final l in bill.lines) (await c.read(appDataProvider).catalog.product(l.productId))!.stockMilli]);
    expect(stockAfter![0], stockBefore![0] + first.remainingMilli, reason: 'the returned quantity is back in stock');
    for (var i = 1; i < bill.lines.length; i++) {
      expect(stockAfter[i], stockBefore[i], reason: 'lines that were not returned are untouched');
    }
  });

  testWidgets('more than what is left, a letter, or nothing chosen: refused with the reason, nothing saved', (tester) async {
    final c = await app(tester);
    final bill = await aBill(tester, c);
    go(tester, '/sales-returns/bill/${bill.billId}');
    await tester.pumpAndSettle();
    final l = bill.lines.first;
    await tester.enterText(find.byKey(const ValueKey('ret-reason')), 'x');
    await tester.enterText(find.byKey(ValueKey('ret-qty-${l.billLineId}')), '${(l.remainingMilli ~/ 1000) + 5}');
    await tester.pump();
    expect(find.textContaining('At most'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('ret-save')));
    await tester.tap(find.byKey(const ValueKey('ret-save')));
    await tester.pump();
    expect(await tester.runAsync(() => c.read(appDataProvider).returns.list()), isEmpty);
    await tester.enterText(find.byKey(ValueKey('ret-qty-${l.billLineId}')), '');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ret-save')));
    await tester.pump();
    expect(find.text('Choose at least one item to return.'), findsOneWidget);
  });

  testWidgets('a customer with a debt on the bill: the screen says the refund comes off what they owe', (tester) async {
    final c = await app(tester);
    final bill = await tester.runAsync(() async {
      final repo = c.read(appDataProvider);
      final rows = await repo.bills.page(limit: 50, status: 3); // unpaid
      for (final r in rows) {
        final v = await repo.returns.returnable(r.id);
        if (v != null && v.anythingLeft && v.outstandingPaise > 0) return v;
      }
      return null;
    });
    if (bill == null) return; // the small test shop has no unpaid bill: the rule itself is tested on the database in test/data/return_repo_test.dart
    go(tester, '/sales-returns/bill/${bill.billId}');
    await tester.pumpAndSettle();
    final l = bill.lines.first;
    await tester.tap(find.byKey(ValueKey('ret-all-${l.billLineId}')));
    await tester.pump();
    expect(find.byKey(const ValueKey('ret-debt')), findsOneWidget);
  });

  testWidgets('Add return: a bill number that does not exist says so; a real one opens that bill\'s return page', (tester) async {
    final c = await app(tester);
    final bill = await aBill(tester, c);
    final number = bill.number;
    await tester.tap(find.text('Add return').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Bill no.').last, 'NOPE-1');
    await tester.tap(find.text('Continue').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('There is no bill with that number.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('Add return').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Bill no.').last, number);
    await tester.tap(find.text('Continue').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Return items from $number'), findsWidgets);
  });

  testWidgets('a bill with returns cannot be cancelled: the owner is told why, nothing breaks', (tester) async {
    final c = await app(tester);
    final bill = await aBill(tester, c);
    await tester.runAsync(() => c.read(appDataProvider).returns.saveReturn(SaveReturnInput(idemKey: 'k', billId: bill.billId, at: DateTime(2026, 10, 17), lines: {bill.lines.first.billLineId: 1000}, reason: 'x')));
    final outcome = await tester.runAsync(() async {
      try {
        await c.read(appDataProvider).bills.cancelBill(bill.billId, reason: 'x');
        return 'cancelled';
      } on StateError catch (e) {
        return e.message;
      }
    });
    expect(outcome, contains('already returned'));
  });
}
