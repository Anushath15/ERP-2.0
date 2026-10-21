import 'dart:convert';
import 'package:erp2/core/printer_service.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/features/print/print_preview.dart' show samplePrintDoc;
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: the Print button builds the real PDF and hands it to the printer service (the chosen printer, or the default one),
// says what happened in plain words, and the printer choice and a test page work from Settings.
// What they do NOT prove: that a physical printer prints (needs the real printer; the Test print button on Settings is for that).
class _AutoOn extends AutoPrintNotifier {
  @override
  bool build() => true;
}

class _Doc extends PrintDocNotifier {
  @override
  PrintDoc? build() => samplePrintDoc(seedProducts(), DateTime(2026, 10, 20, 12));
}

void main() {
  Future<(ProviderContainer, FakePrinter)> printPage(WidgetTester t, {FakePrinter? printer}) async {
    final fake = printer ?? FakePrinter();
    final c = await pumpApp(t, size: desktop1366, location: '/print', motion: MotionLevel.off, followSystemMotion: false, printer: fake);
    return (c, fake);
  }

  testWidgets('Print sends the bill PDF to the default printer and says where it went', (tester) async {
    final (_, fake) = await printPage(tester);
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(fake.jobs, hasLength(1));
    expect(fake.jobs.single.printer, 'HP LaserJet A4');
    expect(latin1.decode(fake.jobs.single.bytes.sublist(0, 5)), '%PDF-');
    expect(find.text('Sent to HP LaserJet A4'), findsOneWidget);
  });

  testWidgets('the printer chosen in Settings is the one used', (tester) async {
    final (c, fake) = await printPage(tester);
    c.read(settingsProvider.notifier).set((s) => s.copyWith(printerName: 'Epson Receipt'));
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(fake.jobs.single.printer, 'Epson Receipt');
    expect(find.text('Sent to Epson Receipt'), findsOneWidget);
  });

  testWidgets('no printer connected: a plain message, nothing sent', (tester) async {
    final (_, fake) = await printPage(tester, printer: FakePrinter(list: const []));
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(fake.jobs, isEmpty);
    expect(find.textContaining('No printer found'), findsOneWidget);
  });

  testWidgets('the printer failed: a plain message', (tester) async {
    final (_, fake) = await printPage(tester, printer: FakePrinter(status: PrintStatus.failed));
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(fake.jobs, isEmpty);
    expect(find.textContaining('Could not print'), findsOneWidget);
  });

  testWidgets('Settings: pick the printer once (saved on this computer) and print a test page', (tester) async {
    final fake = FakePrinter();
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 2400), location: '/settings', motion: MotionLevel.off, followSystemMotion: false, printer: fake);
    await tester.ensureVisible(find.byKey(const ValueKey('printerPicker')));
    await tester.tap(find.byKey(const ValueKey('printerPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Epson Receipt').last);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).printerName, 'Epson Receipt');
    await tester.ensureVisible(find.byKey(const ValueKey('printTest')));
    await tester.tap(find.byKey(const ValueKey('printTest')));
    await tester.pumpAndSettle();
    expect(fake.jobs.single.printer, 'Epson Receipt');
    expect(fake.jobs.single.name, 'Printer test page');
  });

  test('the saved printer name is cleaned when settings are read back', () {
    expect(AppSettings.fromJson({'printerName': 'HP LaserJet'}).printerName, 'HP LaserJet');
    expect(AppSettings.fromJson({'printerName': 42}).printerName, '');
    expect(AppSettings.fromJson({'printerName': 'A${'x' * 300}'}).printerName.length, 120);
    expect(AppSettings.fromJson({'printerName': 'Bad\u0000Name'}).printerName, isNot(contains('\u0000')));
    expect(AppSettings.fromJson(const AppSettings(printerName: 'Epson').toJson()).printerName, 'Epson');
  });

  testWidgets('Save and print: the Print page sends the document to the printer by itself, once; Print again sends it again', (tester) async {
    final fake = FakePrinter();
    await pumpApp(tester, size: desktop1366, location: '/print', motion: MotionLevel.off, followSystemMotion: false, printer: fake, extraOverrides: [autoPrintProvider.overrideWith(_AutoOn.new), printDocProvider.overrideWith(_Doc.new)]);
    await tester.pumpAndSettle();
    expect(fake.jobs, hasLength(1), reason: 'printed at once, without pressing Print');
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(fake.jobs, hasLength(2), reason: 'a second print only when asked');
  });

  testWidgets('with "print straight after Save and print" switched off the page waits for the Print button', (tester) async {
    final fake = FakePrinter();
    final c = await pumpApp(tester, size: desktop1366, location: '/', motion: MotionLevel.off, followSystemMotion: false, printer: fake);
    c.read(settingsProvider.notifier).set((x) => x.copyWith(printAfterSave: false));
    // the same thing Save and print does: the document, the flag, then the page
    c.read(printDocProvider.notifier).set(samplePrintDoc(seedProducts(), DateTime(2026, 10, 20, 12)));
    c.read(autoPrintProvider.notifier).set(true);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/print');
    await tester.pumpAndSettle();
    expect(fake.jobs, isEmpty);
  });

  testWidgets('"Use the Windows print window" is passed to the printer service; the default is the direct way', (tester) async {
    final (c, fake) = await printPage(tester);
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(fake.lastViaDialog, isFalse);
    c.read(settingsProvider.notifier).set((s) => s.copyWith(printViaDialog: true));
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(fake.lastViaDialog, isTrue);
  });

  testWidgets('both print switches are on the Settings page and are remembered', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 2600), location: '/settings', motion: MotionLevel.off, followSystemMotion: false);
    expect(c.read(settingsProvider).printViaDialog, isFalse);
    expect(c.read(settingsProvider).printAfterSave, isTrue);
    await tester.ensureVisible(find.byKey(const ValueKey('printViaDialog')));
    await tester.tap(find.byKey(const ValueKey('printViaDialog')));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).printViaDialog, isTrue);
    expect(AppSettings.fromJson(c.read(settingsProvider).toJson()).printViaDialog, isTrue);
  });
}
