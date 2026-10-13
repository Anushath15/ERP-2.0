import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/app.dart';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/features/print/print_preview.dart' show Paper;
import 'package:erp2/fake/shop_profile.dart';
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

  testWidgets('estimate on screen: only ESTIMATE, customer, date, items, TOTAL and the note; switches bring the rest back', (tester) async {
    final c = await app(tester, '/preview/estimate');
    expect(find.text('ESTIMATE'), findsOneWidget);
    expect(find.byKey(const ValueKey('paperTotal')), findsOneWidget);
    for (final gone in ['SENTHIL ENTERPRISES', 'Estimate no', 'Before tax', 'CGST', 'SGST', 'Round off']) {
      expect(find.textContaining(gone), findsNothing, reason: gone);
    }
    c.read(shopProvider.notifier).set((s) => s.copyWith(estimate: const EstimateShows(shopName: true, number: true, taxLines: true)));
    await tester.pump();
    for (final back in ['SENTHIL ENTERPRISES', 'Estimate no', 'Before tax', 'CGST', 'SGST', 'Round off']) {
      expect(find.textContaining(back), findsWidgets, reason: back);
    }
  });

  testWidgets('a tax invoice still shows the shop block and tax lines', (tester) async {
    await app(tester, '/preview/a4');
    for (final t in ['SENTHIL ENTERPRISES', 'TAX INVOICE', 'Before tax', 'CGST', 'SGST', 'Round off']) {
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
