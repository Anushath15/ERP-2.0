import 'dart:convert';
import 'dart:typed_data';
import 'package:erp2/data/context.dart';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/barcode.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/features/labels/label_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'data/helpers.dart' as db;
import 'helpers.dart';

// What these tests prove: loose items get the shop's own barcode (unique, kept on the product, found by the scanner lookup), the sticker PDF has one
// sticker per copy in the right size, and the Barcode labels page prints / saves it (to the sticker printer when one is chosen).
// What they do NOT prove: how a real label printer feeds the paper, or that a real scanner reads the printed sticker (try one sticker first).
void main() {
  group('the shop barcode', () {
    test('ten digits starting with 2; Code 128 can draw only plain printable characters', () {
      expect(shopBarcode(1), '2000000001');
      expect(shopBarcode(123456), '2000123456');
      expect(canMakeCode128('2000000001'), isTrue);
      expect(canMakeCode128('FAS-0045'), isTrue);
      expect(canMakeCode128(''), isFalse);
      expect(canMakeCode128('பார்கோடு'), isFalse, reason: 'Tamil letters cannot be a Code 128 barcode');
      expect(canMakeCode128('tab\there'), isFalse);
      expect(canMakeCode128('x' * 41), isFalse);
    });
  });

  group('giving barcodes', () {
    test('each product without one gets its own; one that has a barcode keeps it; the scanner lookup and search find it; running again changes nothing', () async {
      final d = db.memoryShop();
      await d.catalog.saveProduct(db.sampleProduct('1 inch nail', id: 'n1'), create: true);
      await d.catalog.saveProduct(db.sampleProduct('PVC pipe', id: 'n2'), create: true);
      await d.catalog.saveProduct(db.sampleProduct('Bulb', id: 'b1').copyWith(barcode: '8901234567890'), create: true);
      final made = await d.catalog.assignBarcodes(['n1', 'n2', 'b1']);
      expect(made.keys.toSet(), {'n1', 'n2'});
      expect(made['n1'], '2000000001');
      expect(made['n2'], '2000000002');
      expect((await d.catalog.product('b1'))!.barcode, '8901234567890');
      expect((await d.catalog.productByBarcode('2000000001'))!.id, 'n1', reason: 'what the counter scanner types finds the product at once');
      expect([for (final p in await d.catalog.searchProducts('2000000002')) p.id], ['n2']);
      expect(await d.catalog.assignBarcodes(['n1', 'n2']), isEmpty);
      expect((await d.db.rows("SELECT * FROM outbox WHERE coll = 'products' AND doc_id = 'n1'")).isNotEmpty, isTrue, reason: 'the change goes to the cloud copy like any product edit');
      await d.close();
    });

    test('a number somebody typed by hand is never given twice', () async {
      final d = db.memoryShop();
      await d.catalog.saveProduct(db.sampleProduct('Typed', id: 't1').copyWith(barcode: '2000000001'), create: true);
      await d.catalog.saveProduct(db.sampleProduct('Loose', id: 'l1'), create: true);
      expect((await d.catalog.assignBarcodes(['l1']))['l1'], '2000000002');
      expect(await d.catalog.newBarcode(), '2000000003');
      await d.close();
    });
  });

  group('the sticker PDF', () {
    int pages(Uint8List pdf) => RegExp(r'/Type\s*/Page(?![a-z])').allMatches(latin1.decode(pdf)).length;
    List<double> box(Uint8List pdf) {
      final m = RegExp(r'/MediaBox\s*\[\s*([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s*\]').firstMatch(latin1.decode(pdf))!;
      return [for (var i = 1; i <= 4; i++) double.parse(m.group(i)!)];
    }

    const items = [LabelItem(name: '1 inch nail (1 kg)', priceText: '₹ 120.00', barcode: '2000000001', copies: 3), LabelItem(name: 'PVC pipe 1 inch', priceText: '₹ 85.00', barcode: '2000000002', copies: 2)];

    test('roll stickers: one page per sticker, exactly the sticker size', () async {
      final b = await buildLabelsPdf(items: items, size: LabelSize.roll50x25);
      expect(pages(b), 5);
      final m = box(b);
      expect((m[2] - 141.7).abs(), lessThan(0.5));
      expect((m[3] - 70.9).abs(), lessThan(0.5));
      final narrow = box(await buildLabelsPdf(items: items, size: LabelSize.roll38x25));
      expect((narrow[2] - 107.7).abs(), lessThan(0.5));
    });

    test('A4 sheet: 21 stickers on a page, the rest on the next', () async {
      const many = [LabelItem(name: 'Nail', priceText: '₹ 1.00', barcode: '2000000001', copies: 22)];
      expect(pages(await buildLabelsPdf(items: many, size: LabelSize.sheetA4)), 2);
      expect(pages(await buildLabelsPdf(items: const [LabelItem(name: 'Nail', priceText: '₹ 1.00', barcode: '2000000001', copies: 21)], size: LabelSize.sheetA4)), 1);
      final a4 = box(await buildLabelsPdf(items: many, size: LabelSize.sheetA4));
      expect((a4[2] - 595.3).abs(), lessThan(1));
    });

    test('the price on a sticker is what the customer pays (with GST)', () {
      expect(labelPrice(10000, pricesIncludeGst: true, gstBp: 1800), '₹ 100.00');
      expect(labelPrice(10000, pricesIncludeGst: false, gstBp: 1800), '₹ 118.00');
    });
  });

  group('the Barcode labels page', () {
    Future<(ProviderContainer, FakePrinter, FakeSaver)> page(WidgetTester t) async {
      final fake = FakePrinter();
      final saver = FakeSaver();
      final c = await pumpApp(t, size: const ScreenSpec('tall', 1366, 1800), location: '/labels', motion: MotionLevel.off, followSystemMotion: false, printer: fake, extraOverrides: [fileSaverProvider.overrideWithValue(saver)]);
      for (final (id, name) in [('loose1', 'LOOSE NAIL 1 INCH'), ('loose2', 'LOOSE PVC PIPE 1 INCH')]) {
        c.read(productsProvider.notifier).add(Product(id: id, name: name, category: 'Hardware', unit: 'kg', pricePaise: 12000, costPaise: 8000, stockMilli: 20000, gstBp: 1800, barcode: ''));
      }
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await t.pumpAndSettle();
      return (c, fake, saver);
    }

    Future<void> pick(WidgetTester t, Product p) async {
      await t.enterText(find.byKey(const ValueKey('labelSearch')), p.name.substring(0, 5));
      await t.pumpAndSettle();
      await t.tap(find.byKey(ValueKey('labelHit-${p.id}')));
      await t.pumpAndSettle();
    }

    Future<void> wait(WidgetTester t) async {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await t.pumpAndSettle();
    }

    testWidgets('add a product, set the number of stickers, save the PDF: the missing barcode is made and kept', (tester) async {
      final (c, _, saver) = await page(tester);
      final p = c.read(productsProvider).firstWhere((x) => x.id == 'loose1');
      await pick(tester, p);
      expect(find.byKey(ValueKey('labelRow-${p.id}')), findsOneWidget);
      expect(find.text('1 stickers'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('labelPlus-${p.id}')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('labelPlus-${p.id}')));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('3 stickers'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('labelPdf')));
      await wait(tester);
      expect(saver.saved.keys.single, 'Barcode labels.pdf');
      expect(RegExp(r'/Type\s*/Page(?![a-z])').allMatches(latin1.decode(saver.saved.values.single)).length, 3);
      final after = c.read(productsProvider).firstWhere((x) => x.id == p.id);
      expect(after.barcode, matches(RegExp(r'^2\d{9}$')), reason: 'made and kept on the product');
    });

    testWidgets('Print goes to the sticker printer when one is chosen, else to the bill printer', (tester) async {
      final (c, fake, _) = await page(tester);
      await pick(tester, c.read(productsProvider).firstWhere((x) => x.id == 'loose2'));
      await tester.tap(find.byKey(const ValueKey('labelPrint')));
      await wait(tester);
      expect(fake.jobs.single.printer, 'HP LaserJet A4', reason: 'no sticker printer chosen: the bill printer');
      c.read(settingsProvider.notifier).set((s) => s.copyWith(labelPrinterName: 'Epson Receipt'));
      await tester.tap(find.byKey(const ValueKey('labelPrint')));
      await wait(tester);
      expect(fake.jobs.last.printer, 'Epson Receipt');
    });

    testWidgets('Add all without a barcode adds them in one press; nothing chosen: Print is off', (tester) async {
      final (c, _, _) = await page(tester);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('labelPrint'))).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('labelAddMissing')));
      await tester.pumpAndSettle();
      final missing = c.read(productsProvider).where((x) => x.barcode.isEmpty).length;
      expect(find.text('$missing stickers'), findsOneWidget);
    });
  });

  testWidgets('the product form has a button that makes a barcode for a loose item', (tester) async {
    await pumpApp(tester, size: const ScreenSpec('tall', 1366, 2400), location: '/products', motion: MotionLevel.off, followSystemMotion: false);
    await tester.tap(find.text('Add product').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('makeBarcode')));
    await tester.tap(find.byKey(const ValueKey('makeBarcode')));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^2\d{9}$')), findsWidgets);
  });
}
