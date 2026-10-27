import 'dart:typed_data';
import 'package:erp2/core/printer_service.dart';
import 'package:erp2/core/raw_print.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/features/billing/cart.dart' show printDocProvider;
import 'package:erp2/features/print/print_preview.dart' show samplePrintDoc;
import 'package:erp2/demo/seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// What these tests prove: a bill never goes to a printer that makes no paper (OneNote, Print to PDF, XPS, Fax) unless the person
// picked it by name, even when Windows has made one of them the default (this laptop's default was OneNote, so every Print opened
// OneNote); with no paper printer at all the program says so instead. "Print as a picture" is remembered and handed to the printer.
const oneNote = PrinterInfo(name: 'OneNote (Desktop)', isDefault: true, driver: 'Send to Microsoft OneNote 16 Driver');
const pdf = PrinterInfo(name: 'Microsoft Print to PDF', isDefault: false, driver: 'Microsoft Print To PDF');
const hp = PrinterInfo(name: 'HP Smart Tank 580-590 series', isDefault: false, driver: 'Microsoft IPP Class Driver');
const epson = PrinterInfo(name: 'EPSON L3250 Series', isDefault: false, driver: 'EPSON L3250 Series');

class _Raw implements RawPrinter {
  final to = <String>[];
  @override
  Future<bool> toWindowsPrinter(String printerName, Uint8List bytes, {required String jobName}) async {
    to.add(printerName);
    return true;
  }

  @override
  Future<bool> toNetwork(String host, int port, Uint8List bytes) async => true;
}

void main() {
  test('printers that make no paper are known by their name or driver', () {
    for (final v in [oneNote, pdf, const PrinterInfo(name: 'OneNote (Desktop) - Protected', isDefault: false, driver: 'Microsoft Virtual Print Class Driver'), const PrinterInfo(name: 'Microsoft XPS Document Writer', isDefault: false), const PrinterInfo(name: 'Fax', isDefault: false, driver: 'Microsoft Shared Fax Driver'), const PrinterInfo(name: 'Adobe PDF', isDefault: false), const PrinterInfo(name: 'AnyDesk Printer', isDefault: false, driver: 'AnyDesk v4 Printer Driver'), const PrinterInfo(name: 'HP OfficeJet 3830 series (Fax)', isDefault: false, driver: 'HP OfficeJet 3830 series Fax'), const PrinterInfo(name: 'Brother PC-FAX v.3', isDefault: false)]) {
      expect(v.isPaper, isFalse, reason: v.name);
    }
    for (final p in [hp, epson, const PrinterInfo(name: 'HP Smart Tank 580-590 series', isDefault: false, driver: 'HP Smart Tank 580-590 series PCL-3 (V4)'), const PrinterInfo(name: 'POS-80', isDefault: false, driver: 'POS-80C'), const PrinterInfo(name: 'Brother FAX-2840', isDefault: false, driver: 'Brother FAX-2840'), const PrinterInfo(name: 'TVS RP 3160 Gold', isDefault: false)]) {
      expect(p.isPaper, isTrue, reason: p.name);
    }
  });

  test('the choice: the picked printer; else the default only when it makes paper; else the ONLY paper printer; else none', () {
    expect(choosePrinter([oneNote, pdf, hp], '')!.name, hp.name, reason: 'OneNote is the Windows default, the bill still goes to the HP');
    expect(choosePrinter([oneNote, hp, epson], ''), isNull, reason: 'two paper printers and a virtual default: no guessing, the person picks');
    expect(choosePrinter([hp, const PrinterInfo(name: 'EPSON L3250 Series', isDefault: true)], '')!.name, epson.name, reason: 'a paper default wins');
    expect(choosePrinter([oneNote, pdf, hp], 'Microsoft Print to PDF')!.name, pdf.name, reason: 'picked by name: allowed');
    expect(choosePrinter([oneNote, hp], 'EPSON L3250 Series')!.name, hp.name, reason: 'the picked printer is gone: a paper printer, not OneNote');
    expect(choosePrinter([oneNote, pdf], ''), isNull, reason: 'no paper printer connected');
    expect(choosePrinter(const [], ''), isNull);
  });

  testWidgets('Print with OneNote as the Windows default: the bill goes to the HP, OneNote is never used', (tester) async {
    final fake = FakePrinter(list: const [oneNote, pdf, hp]);
    await pumpApp(tester, size: desktop1366, location: '/preview/a4', motion: MotionLevel.off, followSystemMotion: false, printer: fake);
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(fake.jobs.single.printer, hp.name);
    expect(fake.lastAsPicture, isFalse, reason: 'off by default');
  });

  testWidgets('two paper printers and OneNote as the default: nothing is sent, the person is asked to pick the bill printer', (tester) async {
    final fake = FakePrinter(list: const [oneNote, hp, epson]);
    await pumpApp(tester, size: desktop1366, location: '/preview/a4', motion: MotionLevel.off, followSystemMotion: false, printer: fake);
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(fake.jobs, isEmpty);
    expect(find.textContaining('Choose the bill printer once in Settings'), findsOneWidget);
  });

  test('the page size is read from the PDF; pixels with see-through parts are laid on white', () {
    expect(pdfPageSize(Uint8List.fromList('%PDF-1.4 /MediaBox [0 0 595.28 841.89] '.codeUnits)), (width: 595.28, height: 841.89));
    expect(pdfPageSize(Uint8List.fromList('not a pdf'.codeUnits)), isNull);
    // a see-through pixel, a black one, half-see-through black, solid red
    final rgb = flattenOnWhite(Uint8List.fromList([255, 255, 255, 0, 0, 0, 0, 255, 0, 0, 0, 128, 255, 0, 0, 255]), 4, 1);
    expect(rgb, [255, 255, 255, 0, 0, 0, 127, 127, 127, 255, 0, 0]);
  });

  testWidgets('only OneNote and Print to PDF connected: nothing is sent and the person is told', (tester) async {
    final fake = FakePrinter(list: const [oneNote, pdf]);
    await pumpApp(tester, size: desktop1366, location: '/preview/a4', motion: MotionLevel.off, followSystemMotion: false, printer: fake);
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(fake.jobs, isEmpty);
    expect(find.textContaining('No paper printer found'), findsOneWidget);
  });

  testWidgets('Print as a picture: switched on in Settings, remembered, and handed to the printer', (tester) async {
    final fake = FakePrinter(list: const [oneNote, hp]);
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 2600), location: '/settings', motion: MotionLevel.off, followSystemMotion: false, printer: fake);
    expect(find.text('OneNote (Desktop)  (makes no paper)'), findsNothing, reason: 'the list is closed');
    await tester.ensureVisible(find.byKey(const ValueKey('printAsPicture')));
    await tester.tap(find.byKey(const ValueKey('printAsPicture')));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).printAsPicture, isTrue);
    expect(AppSettings.fromJson(c.read(settingsProvider).toJson()).printAsPicture, isTrue);
    expect(AppSettings.fromJson({'printAsPicture': 'yes'}).printAsPicture, isFalse);
    c.read(printDocProvider.notifier).set(samplePrintDoc(seedProducts(), DateTime(2026, 10, 27, 12)));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/print');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(fake.lastAsPicture, isTrue);
    expect(fake.jobs.last.printer, hp.name);
  });

  testWidgets('the printer list marks OneNote and Print to PDF as making no paper', (tester) async {
    await pumpApp(tester, size: const ScreenSpec('tall', 1366, 2600), location: '/settings', motion: MotionLevel.off, followSystemMotion: false, printer: FakePrinter(list: const [oneNote, pdf, hp]));
    await tester.ensureVisible(find.byKey(const ValueKey('printerPicker')));
    await tester.tap(find.byKey(const ValueKey('printerPicker')));
    await tester.pumpAndSettle();
    expect(find.text('OneNote (Desktop)  (makes no paper)'), findsWidgets);
    expect(find.text('Microsoft Print to PDF  (makes no paper)'), findsWidgets);
    expect(find.text(hp.name), findsWidgets);
  });

  testWidgets('thermal printer through Windows, nothing picked and OneNote as the default: no raw bytes anywhere (not OneNote, not a guess); the bill prints the normal way', (tester) async {
    final raw = _Raw();
    final fake = FakePrinter(list: const [oneNote, hp]);
    final c = await pumpApp(tester, size: desktop1366, location: '/', motion: MotionLevel.off, followSystemMotion: false, printer: fake, extraOverrides: [rawPrinterProvider.overrideWithValue(raw)]);
    c.read(settingsProvider.notifier).set((x) => x.copyWith(paper: PaperSize.mm80, thermal: ThermalLink.windows));
    c.read(printDocProvider.notifier).set(samplePrintDoc(seedProducts(), DateTime(2026, 10, 27, 12)));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/print');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(raw.to, isEmpty);
    expect(fake.jobs.single.printer, hp.name, reason: 'the PDF way, on the only paper printer');
    c.read(settingsProvider.notifier).set((x) => x.copyWith(printerName: 'POS-80C'));
    await tester.tap(find.byKey(const ValueKey('printNow')));
    await tester.pumpAndSettle();
    expect(raw.to, ['POS-80C'], reason: 'a picked receipt printer gets the bytes by its name, even when Windows does not list it as ready');
  });
}
