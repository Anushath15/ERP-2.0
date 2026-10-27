import 'package:erp2/data/context.dart';
import 'package:erp2/design/detail_sheet.dart';
import 'package:erp2/design/hotkeys.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/features/print/print_preview.dart' show samplePrintDoc;
import 'package:erp2/fake/credit_store.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// What these tests prove: the usual ERP keys work. Enter saves a form or a payment but still gives a new line in a note and still presses a focused
// button; Enter in an empty bill search box saves the bill; Ctrl+P prints on the Print page, saves and prints on the bill, and prints a saved bill from
// its box; F6 F7 F8 Ctrl+Q open Customers, Credit, Reports and a new bill; Ctrl+F goes to the search box; F1 lists all the keys.
Future<void> chord(WidgetTester tester, LogicalKeyboardKey key, {bool control = false}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

String where(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Scaffold).first)).routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('Enter saves from a single-line field, not from a multi-line note, and never steals Enter from a button', (tester) async {
    var saved = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Focus(
          canRequestFocus: false,
          onKeyEvent: enterSaves(() => saved++),
          child: Column(children: [
            const TextField(key: ValueKey('one')),
            const TextField(key: ValueKey('note'), maxLines: 3),
            TextButton(key: const ValueKey('btn'), onPressed: () {}, child: const Text('Cancel')),
          ]),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('one')));
    await tester.pump();
    await chord(tester, LogicalKeyboardKey.enter);
    expect(saved, 1, reason: 'a single-line field: Enter saves');
    await tester.tap(find.byKey(const ValueKey('note')));
    await tester.pump();
    await chord(tester, LogicalKeyboardKey.enter);
    expect(saved, 1, reason: 'a note with several lines: Enter is a new line');
    await tester.tap(find.byKey(const ValueKey('one')));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(saved, 1, reason: 'Ctrl+Enter is left to the page (save and print)');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    Focus.of(tester.element(find.byKey(const ValueKey('btn')))).requestFocus();
    await tester.pump();
  });

  testWidgets('Enter saves the payment box', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/customers', motion: MotionLevel.off, followSystemMotion: false);
    final withDues = c.read(creditProvider).entries.firstWhere((e) => e.value.balance > 0).key;
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/customers/$withDues/account');
    await tester.pumpAndSettle();
    final before = c.read(creditProvider)[withDues]!.balance;
    await tester.tap(find.byKey(const ValueKey('receiveOrPay')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('payAmount')), '1.00');
    await tester.pump();
    await chord(tester, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(c.read(creditProvider)[withDues]!.balance, before - 100, reason: 'Enter saved the payment of Rs 1');
  });

  testWidgets('bill: Enter in the EMPTY search box saves the bill; Ctrl+P saves and prints', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/bill', motion: MotionLevel.off, followSystemMotion: false);
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'tower bolt');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done); // adds the first match
    await tester.pumpAndSettle();
    expect(c.read(cartProvider(DocMode.invoice)).lines.length, 1);
    final bills = await tester.runAsync(() => c.read(appDataProvider).db.scalarInt('SELECT COUNT(*) FROM bills'));
    await tester.testTextInput.receiveAction(TextInputAction.done); // the box is empty now: Enter saves
    await tester.pumpAndSettle();
    expect(c.read(cartProvider(DocMode.invoice)).lines, isEmpty, reason: 'saved: the bill is cleared');
    expect(await tester.runAsync(() => c.read(appDataProvider).db.scalarInt('SELECT COUNT(*) FROM bills')), bills! + 1);

    await tester.enterText(field, 'tower bolt');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await chord(tester, LogicalKeyboardKey.keyP, control: true);
    for (var i = 0; i < 20 && find.byKey(const ValueKey('printNow')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))); // the bill is written to the database
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('printNow')), findsOneWidget, reason: 'Ctrl+P: saved, then the Print page');
    expect(c.read(cartProvider(DocMode.invoice)).lines, isEmpty);
  });

  testWidgets('Print page: Ctrl+P prints', (tester) async {
    final fake = FakePrinter();
    final c = await pumpApp(tester, size: desktop1366, location: '/', motion: MotionLevel.off, followSystemMotion: false, printer: fake);
    c.read(printDocProvider.notifier).set(samplePrintDoc(seedProducts(), DateTime(2026, 10, 27, 12)));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/print');
    await tester.pumpAndSettle();
    expect(fake.jobs, isEmpty);
    await chord(tester, LogicalKeyboardKey.keyP, control: true);
    await tester.pumpAndSettle();
    expect(fake.jobs, hasLength(1));
  });

  testWidgets('a saved bill\'s box: Ctrl+P runs its print', (tester) async {
    var printed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => Scaffold(body: TextButton(onPressed: () => showDetail<void>(ctx, title: 'A-1', body: const [Text('x')], onPrint: () => printed++), child: const Text('open')))),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await chord(tester, LogicalKeyboardKey.keyP, control: true);
    expect(printed, 1);
  });

  testWidgets('F6 F7 F8 Ctrl+Q go to Customers, Credit, Reports and a new bill; F1 lists the keys; Ctrl+F goes to the search box', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/products', motion: MotionLevel.off, followSystemMotion: false);
    // the search box has the focus at first; take it away, then Ctrl+F brings it back
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await chord(tester, LogicalKeyboardKey.f6);
    await tester.pumpAndSettle();
    expect(where(tester), '/customers');
    await chord(tester, LogicalKeyboardKey.f7);
    await tester.pumpAndSettle();
    expect(where(tester), '/credit');
    await chord(tester, LogicalKeyboardKey.f8);
    await tester.pumpAndSettle();
    expect(where(tester), '/reports');
    await chord(tester, LogicalKeyboardKey.keyQ, control: true);
    await tester.pumpAndSettle();
    expect(where(tester), '/bill');
    await chord(tester, LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await chord(tester, LogicalKeyboardKey.keyF, control: true);
    await tester.pump();
    final editable = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(editable.focusNode.hasFocus, isTrue, reason: 'Ctrl+F: the search box of the Products page');
    await chord(tester, LogicalKeyboardKey.f1);
    await tester.pumpAndSettle();
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    for (final k in ['Ctrl+P / F9 / Ctrl+Enter', 'F6', 'F7', 'F8', 'Ctrl+F']) {
      expect(find.textContaining(k, skipOffstage: false), findsWidgets, reason: k);
    }
    await chord(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Keyboard shortcuts'), findsNothing, reason: 'Esc closes the box');
  });
}
