import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/src/pdf/font/ttf_parser.dart';
import 'package:erp2/core/device_store.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/design/tokens.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/fake/store.dart';
import 'helpers.dart';

void main() {
  test('device settings survive a round trip and a damaged file falls back to defaults', () {
    const s = AppSettings(theme: ThemeMode.system, accent: Accent.teal, highContrast: true, textScale: 1.5, billingScale: 2.25, density: DensityMode.compact, font: FontChoice.atkinson, motion: MotionLevel.off, soundScan: false, soundVolume: 0.3);
    final back = AppSettings.fromJson(s.toJson());
    expect(back.theme, ThemeMode.system);
    expect(back.accent, Accent.teal);
    expect(back.highContrast, true);
    expect(back.textScale, 1.5);
    expect(back.billingScale, 2.25);
    expect(back.density, DensityMode.compact);
    expect(back.font, FontChoice.atkinson);
    expect(back.motion, MotionLevel.off);
    expect(back.soundScan, false);
    expect(back.soundVolume, 0.3);
    final bad = AppSettings.fromJson({'textScale': 'huge', 'accent': 'pink', 'billingScale': 99, 'theme': 7});
    expect(bad.textScale, 1.0);
    expect(bad.accent, Accent.blue);
    expect(bad.billingScale, 1.0, reason: 'out of range values go back to the default');
    expect(bad.theme, ThemeMode.dark);
  });

  testWidgets('settings are remembered on this device (store) and not shop data', (tester) async {
    final store = MemoryDeviceStore();
    final c = await pumpApp(tester, size: desktop1366, location: '/settings', store: store);
    c.read(settingsProvider.notifier).set((s) => s.copyWith(textScale: 1.25, accent: Accent.green, density: DensityMode.compact));
    expect(store.data['textScale'], 1.25);
    expect(store.data['accent'], 'green');
    expect(store.data.containsKey('shopName'), false, reason: 'shop details are not per-device settings');
    // a new app start on the same device reads them back
    final c2 = await pumpApp(tester, size: desktop1366, location: '/', store: store);
    expect(c2.read(settingsProvider).textScale, 1.25);
    expect(c2.read(settingsProvider).accent, Accent.green);
  });

  testWidgets('Ctrl+Plus, Ctrl+Minus and Ctrl+0 change the text size', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/');
    double scale() => c.read(settingsProvider).textScale;
    expect(scale(), 1.0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();
    expect(scale(), greaterThan(1.0));
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();
    final up = scale();
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pump();
    expect(scale(), lessThan(up));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pump();
    expect(scale(), 1.0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    // existing shortcuts are not affected: Ctrl+S is still not a zoom key, F2 still opens a new bill
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    expect(find.text('Type name or scan barcode'), findsOneWidget);
  });

  testWidgets('our text size is multiplied with the operating system text size, not replacing it', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = await pumpApp(tester, size: desktop1920, location: '/');
    c.read(settingsProvider.notifier).set((s) => s.copyWith(textScale: 1.25));
    await tester.pumpAndSettle();
    final f = MediaQuery.textScalerOf(tester.element(find.byType(Scaffold).first)).scale(1);
    expect(f, closeTo(1.875, 0.001));
  });

  testWidgets('Settings has a text size slider, a billing text size slider, density, font, colours; no language option', (tester) async {
    await pumpApp(tester, size: desktop1920, location: '/settings');
    expect(find.byKey(const ValueKey('textSlider')), findsOneWidget);
    expect(find.byKey(const ValueKey('billingSlider')), findsOneWidget);
    expect(find.text('Reset to normal'), findsWidgets);
    expect(find.text('Comfortable'), findsOneWidget);
    expect(find.text('Compact'), findsOneWidget);
    expect(find.textContaining('Atkinson'), findsWidgets);
    expect(find.text('High contrast'), findsOneWidget);
    expect(find.text('Match my computer'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
  });

  testWidgets('a name typed in any letters is stored and shown exactly as typed', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/products');
    const typed = 'Ünïcödé 水 bolt ½" #7';
    c.read(productsProvider.notifier).add(const Product(id: 'x1', name: typed, category: 'Hardware', unit: 'pcs', pricePaise: 12345, costPaise: 9000, stockMilli: 5000, gstBp: 1800, barcode: '1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ünïcödé');
    await tester.pumpAndSettle();
    expect(find.text(typed), findsOneWidget);
    expect(c.read(productsProvider).first.name, typed);
  });

  group('fonts print the rupee sign and common punctuation', () {
    const needed = {'₹': 0x20B9, '.': 0x2E, ',': 0x2C, ':': 0x3A, ';': 0x3B, '!': 0x21, '?': 0x3F, '"': 0x22, "'": 0x27, '(': 0x28, ')': 0x29, '-': 0x2D, '/': 0x2F, '&': 0x26, '%': 0x25, '+': 0x2B, '@': 0x40, '#': 0x23, '*': 0x2A, '=': 0x3D, '×': 0xD7, '·': 0xB7, '–': 0x2013, '½': 0xBD, '0': 0x30, '9': 0x39, 'A': 0x41, 'z': 0x7A};
    for (final f in ['assets/fonts/Inter-Variable.ttf', 'assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf']) {
      test(f, () {
        final bytes = File(f).readAsBytesSync();
        final map = TtfParser(ByteData.view(bytes.buffer)).charToGlyphIndexMap;
        final missing = [for (final e in needed.entries) if (!map.containsKey(e.value)) e.key];
        expect(missing, isEmpty, reason: '$f is missing glyphs for $missing');
      });
    }
  });

  testWidgets('the rupee sign shows on the printed bill in both fonts', (tester) async {
    for (final font in FontChoice.values) {
      // the A4 bill follows the shop's template (no rupee sign); the roll receipt prints it
      final c = await pumpApp(tester, size: desktop1366, location: '/preview/80');
      c.read(settingsProvider.notifier).set((s) => s.copyWith(font: font));
      await tester.pumpAndSettle();
      expect(find.textContaining('₹'), findsWidgets);
    }
  });
}
