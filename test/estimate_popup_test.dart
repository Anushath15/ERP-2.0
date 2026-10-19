import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// Saved estimates: the popup of an estimate (Print, Edit, Make a copy, Make into bill, Delete) closes itself properly (it used to take the
// whole page with it: a black screen after "Make a copy", the popup left on top of the print page), and Back from the print page returns
// to the same estimate's popup.
void main() {
  Future<ProviderContainer> app(WidgetTester t, {String loc = '/estimates'}) =>
      pumpApp(t, size: const ScreenSpec('desk', 1600, 1000), location: loc, motion: MotionLevel.off, followSystemMotion: false);

  Future<String> firstNumber(WidgetTester t, ProviderContainer c) async => (await t.runAsync(() => c.read(appDataProvider).estimations.list()))!.first.number;

  testWidgets('Make a copy: the popup closes, a new estimate appears, the page stays, no error', (tester) async {
    final c = await app(tester);
    final before = (await tester.runAsync(() => c.read(appDataProvider).estimations.list()))!;
    expect(before, isNotEmpty);
    await tester.tap(find.text(before.first.number).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make a copy'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final after = (await tester.runAsync(() => c.read(appDataProvider).estimations.list()))!;
    expect(after.length, before.length + 1);
    expect(find.text('All estimates'), findsWidgets, reason: 'the page is still there, not a blank screen');
    expect(find.text('Make a copy'), findsNothing, reason: 'the popup is closed');
    expect(find.text(after.first.number), findsWidgets, reason: 'the copy is in the list');
  });

  testWidgets('Print: the popup is closed on the print page; Back returns to Saved estimates with the same popup open again', (tester) async {
    final c = await app(tester);
    final number = await firstNumber(tester, c);
    await tester.tap(find.text(number).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('printBack')), findsOneWidget, reason: 'on the print page');
    expect(find.text('Make a copy'), findsNothing, reason: 'no popup on top of the print page');
    await tester.tap(find.byKey(const ValueKey('printBack')));
    await tester.pumpAndSettle();
    expect(find.text('All estimates'), findsWidgets);
    expect(find.text('Make a copy'), findsOneWidget, reason: 'the estimate popup is open again');
    expect(find.text(number), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing the popup with X leaves the page in place', (tester) async {
    final c = await app(tester);
    final number = await firstNumber(tester, c);
    await tester.tap(find.text(number).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Make a copy'), findsNothing);
    expect(find.text('All estimates'), findsWidgets);
    expect(find.text(number), findsWidgets);
  });

  testWidgets('Edit from the popup opens the estimate for editing and keeps the app up', (tester) async {
    final c = await app(tester);
    final number = await firstNumber(tester, c);
    await tester.tap(find.text(number).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Make a copy'), findsNothing);
  });

  testWidgets('a bill printed again from the Sales register: Back returns to the register with that bill\'s popup', (tester) async {
    final c = await app(tester, loc: '/sales');
    final row = (await tester.runAsync(() async => (await c.read(appDataProvider).bills.page(limit: 1)).first))!;
    await tester.tap(find.text(row.number).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print again'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    expect(find.text('Print again'), findsNothing, reason: 'no popup on the print page');
    await tester.tap(find.byKey(const ValueKey('printBack')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    expect(find.text('Print again'), findsOneWidget, reason: 'the bill popup is open again');
  });
}
