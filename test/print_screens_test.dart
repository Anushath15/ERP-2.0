import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/app.dart';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/features/print/print_preview.dart' show Paper;
import 'package:erp2/fake/store.dart';
import 'helpers.dart';

// The Print screen (there is no Preview step any more), the estimate printout switches, Save as PDF, and the three print text sizes
// on A4, A5 and 80 mm paper: nothing may be cut off, and pictures (goldens) show how each looks.
void main() {
  settingsRoundTrip();
  Future<ProviderContainer> app(WidgetTester t, String loc, {List<Override> extra = const []}) => pumpApp(t, size: desktop1366, location: loc, motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [...extra]);

  testWidgets('the print screen has only Print and Save as PDF (no Preview)', (tester) async {
    await app(tester, '/preview/a4');
    expect(find.text('Print'), findsWidgets);
    expect(find.text('Save as PDF'), findsOneWidget);
    expect(find.text('Preview'), findsNothing);
    expect(find.text('Print preview'), findsNothing);
  });

  testWidgets('estimate on screen (the shop template): ESTIMATE, customer, date, items, GST summary, net amount and the note; NO shop details', (tester) async {
    await app(tester, '/preview/estimate');
    expect(find.text('ESTIMATE'), findsOneWidget);
    expect(find.byKey(const ValueKey('paperTotal')), findsOneWidget);
    for (final here in ['Goods', 'HSN Code', 'Net Amount', 'Rupees']) {
      expect(find.textContaining(here), findsWidgets, reason: here);
    }
    expect(find.byKey(const ValueKey('paperTitle')), findsOneWidget, reason: 'the heading in the middle of the first row');
    expect(find.text('GST%'), findsNothing, reason: 'an estimate has no GST column');
    for (final gone in ['SENTHIL ENTERPRISES', 'Sample Bank', 'TAX INVOICE', 'A/c 0000000000', 'Authorised signatory', 'GST  33', 'Phone  ', 'Sales Amt', 'CGST', 'SGST', 'IGST']) {
      expect(find.textContaining(gone), findsNothing, reason: '$gone is a shop detail or the GST summary: not on an estimate');
    }
  });

  testWidgets('a tax invoice shows the shop block, the GST summary, the amount in words, the bank details and the signature', (tester) async {
    await app(tester, '/preview/a4');
    expect(find.byKey(const ValueKey('paperHeading')), findsOneWidget, reason: 'TAX INVOICE, underlined, at the top');
    expect(find.text('TAX INVOICE'), findsOneWidget);
    expect(find.byKey(const ValueKey('paperTo0')), findsOneWidget, reason: 'the customer phone under the name');
    expect(find.text('Phone  94430 12345'), findsOneWidget);
    expect(find.text('GST  33ABCDE1234F1Z5'), findsOneWidget, reason: 'the customer GST number under the phone, when there is one');
    for (final t in ['SENTHIL ENTERPRISES', 'Goods', 'HSN Code', 'Disc %', 'Round off', 'Net Amount', 'Sales Amt', 'CGST', 'SGST', 'Rupees', 'A/c 0000000000', 'IFSC SAMP0000000', 'Phone', 'For SENTHIL ENTERPRISES', 'Authorised signatory']) {
      expect(find.textContaining(t), findsWidgets, reason: t);
    }
  });

  testWidgets('Save as PDF saves a real PDF named after the document (through a stand-in saver, nothing on disk)', (tester) async {
    final saver = FakeSaver();
    await app(tester, '/preview/estimate', extra: [fileSaverProvider.overrideWithValue(saver)]);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('printSavePdf')));
      for (var i = 0; i < 100 && saver.saved.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();
    expect(saver.saved.keys.single, 'Estimate EST-00231.pdf');
    expect(String.fromCharCodes(saver.saved.values.single.take(5)), '%PDF-');
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  for (final (route, name) in [('/preview/a4', 'a4'), ('/preview/a5', 'a5'), ('/preview/80', 'mm80'), ('/preview/58', 'mm58')]) {
    for (final size in PrintTextSize.values) {
      testWidgets('print text size ${size.name} on $name: nothing is cut off', (tester) async {
        final c = await app(tester, route);
        c.read(settingsProvider.notifier).set((s) => s.copyWith(printSize: size));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final paper = tester.getRect(find.byType(Paper));
        expect(paper.height, greaterThan(100));
        // every printed text stays inside the paper's width
        for (final t in tester.widgetList<Text>(find.descendant(of: find.byType(Paper), matching: find.byType(Text)))) {
          final r = tester.getRect(find.byWidget(t));
          expect(r.left, greaterThanOrEqualTo(paper.left - 0.5), reason: '"${t.data}" (left)');
          expect(r.right, lessThanOrEqualTo(paper.right + 0.5), reason: '"${t.data}" (right)');
        }
      });
    }
  }

  // pictures of the three sizes on the three kinds of paper
  for (final (route, name) in [('/preview/a4', 'a4'), ('/preview/a5', 'a5'), ('/preview/80', 'mm80')]) {
    for (final size in PrintTextSize.values) {
      testWidgets('golden: $name, print text ${size.name}', (tester) async {
        final c = await app(tester, route);
        c.read(settingsProvider.notifier).set((s) => s.copyWith(printSize: size));
        await tester.pump();
        await expectLater(find.byType(ErpApp), matchesGoldenFile('goldens/print/print_${name}_${size.name}.png'));
      });
    }
  }
}

// (kept at the end) the print text size is a per-device setting: saved with the device settings, default Small, damaged value falls back.
void settingsRoundTrip() {
  test('print text size is saved on this device; default is Small; a damaged value falls back to Small', () {
    expect(const AppSettings().printSize, PrintTextSize.small);
    final j = const AppSettings(printSize: PrintTextSize.normal).toJson();
    expect(AppSettings.fromJson(j).printSize, PrintTextSize.normal);
    expect(AppSettings.fromJson({...j, 'printSize': 'huge'}).printSize, PrintTextSize.small);
  });
}
