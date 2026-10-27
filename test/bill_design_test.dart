import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/design/theme.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/fake/store.dart' show PaperSize, PrintTextSize;
import 'package:erp2/features/print/bill_template.dart';
import 'package:erp2/features/print/bill_template_paper.dart';
import 'package:erp2/features/print/doc_pdf.dart';
import 'package:erp2/features/print/print_preview.dart' show samplePrintDoc;
import 'package:erp2/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: the shop picks a bill design (Classic, Modern, Compact), a colour for Modern, and which of the MRP, HSN and Disc %
// columns are printed; the choice is saved with the shop and comes back; a hidden column is gone from the head and every row while every amount
// stays the same; the PDF and the on-screen paper both use the chosen look (the Modern colour band, Compact's smaller letters); and the Shop page
// changes all three.
const l = Strings();
final now = DateTime(2026, 10, 27, 11);
final products = seedProducts();

/// Every "r g b rg" fill colour in the PDF's page content.
List<List<double>> fills(Uint8List pdf) {
  final raw = latin1.decode(pdf);
  final out = <List<double>>[];
  for (final m in RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream').allMatches(raw)) {
    String text;
    try {
      text = latin1.decode(ZLibCodec().decode(latin1.encode(m.group(1)!)));
    } catch (_) {
      continue; // a font or an image
    }
    for (final f in RegExp(r'([0-9.]+) ([0-9.]+) ([0-9.]+) rg').allMatches(text)) {
      out.add([for (var i = 1; i <= 3; i++) double.parse(f.group(i)!)]);
    }
  }
  return out;
}

bool hasColour(Uint8List pdf, int argb) {
  final want = [(argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF].map((v) => v / 255).toList();
  return fills(pdf).any((f) => [for (var i = 0; i < 3; i++) (f[i] - want[i]).abs() < 0.01].every((x) => x));
}

/// The smallest font size on the page ("/F1 9.5 Tf").
double smallestFont(Uint8List pdf) {
  final raw = latin1.decode(pdf);
  final sizes = <double>[];
  for (final m in RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream').allMatches(raw)) {
    try {
      final text = latin1.decode(ZLibCodec().decode(latin1.encode(m.group(1)!)));
      sizes.addAll([for (final f in RegExp(r'/F\d+\s+([0-9.]+)\s+Tf').allMatches(text)) double.parse(f.group(1)!)]);
    } catch (_) {}
  }
  return sizes.reduce((a, b) => a < b ? a : b);
}

void main() {
  const shop = ShopProfile.sample;

  test('the design, colour and hidden columns are saved with the shop; strange saved values fall back to the normal look', () {
    final p = shop.copyWith(billDesign: 'modern', billAccent: 0xFF0B6E4F, billHideCols: ['mrp', 'disc']);
    final back = ShopProfile.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect((back.billDesign, back.billAccent), ('modern', 0xFF0B6E4F));
    expect(back.billHideCols, ['mrp', 'disc']);
    final bad = ShopProfile.fromJson({'billDesign': 'fancy', 'billAccent': 'red', 'billHideCols': ['mrp', 'qty', 'total', 7]});
    expect((bad.billDesign, bad.billAccent), ('classic', 0xFF1F4E79));
    expect(bad.billHideCols, ['mrp'], reason: 'Qty and Total can never be hidden');
    final old = ShopProfile.fromJson({'name': 'Old shop'});
    expect(old.billDesign, 'classic', reason: 'a shop saved before designs existed keeps the classic bill');
    expect(old.billHideCols, isEmpty);
  });

  test('each design has its own look; Classic is the black bill book', () {
    final classic = BillLook.of(shop);
    expect((classic.design, classic.band, classic.accent, classic.fontDelta), ('classic', false, 0xFF000000, 0));
    final modern = BillLook.of(shop.copyWith(billDesign: 'modern', billAccent: 0xFF8E2C48));
    expect((modern.band, modern.accent), (true, 0xFF8E2C48));
    final compact = BillLook.of(shop.copyWith(billDesign: 'compact'));
    expect((compact.band, compact.fontDelta < 0, compact.padV < classic.padV), (false, true, true));
  });

  test('a hidden column is gone from the head and every row; the amounts stay the same', () {
    final doc = samplePrintDoc(products, now);
    final all = buildBillTemplate(doc: doc, shop: shop, l: l);
    final some = buildBillTemplate(doc: doc, shop: shop.copyWith(billHideCols: ['mrp', 'hsn', 'disc']), l: l);
    expect(all.cols, [0, 1, 2, 3, 4, 5, 6, 7, 8]);
    expect(some.cols, [0, 1, 4, 6, 7, 8]);
    expect([for (final i in some.cols) some.head[i]], isNot(contains(l.tplMrp)));
    expect([for (final i in some.cols) some.head[i]], isNot(contains(l.tplHsn)));
    expect([for (final i in some.cols) some.head[i]], isNot(contains(l.tplDisc)));
    expect([for (final r in some.rows) r.cells[8]], [for (final r in all.rows) r.cells[8]], reason: 'every line total is the same');
    expect((some.totalQty, some.totalAmount, some.net, some.words), (all.totalQty, all.totalAmount, all.net, all.words));
  });

  test('the PDF uses the chosen look: the Modern colour is printed, Classic has no colour, Compact has smaller letters', () async {
    final doc = samplePrintDoc(products, now);
    Future<Uint8List> pdf(ShopProfile s) => buildDocPdf(doc: doc, paper: PaperSize.a4, shop: s, size: PrintTextSize.small, l: l);
    final classic = await pdf(shop);
    final modern = await pdf(shop.copyWith(billDesign: 'modern', billAccent: 0xFF0B6E4F));
    final compact = await pdf(shop.copyWith(billDesign: 'compact'));
    for (final b in [classic, modern, compact]) {
      expect(latin1.decode(b.sublist(0, 5)), '%PDF-');
    }
    expect(hasColour(modern, 0xFF0B6E4F), isTrue, reason: 'the band and the column heads');
    expect(hasColour(classic, 0xFF0B6E4F), isFalse);
    expect(smallestFont(compact), lessThan(smallestFont(classic)));
  });

  testWidgets('the on-screen paper uses the same look: Modern has a thick line in the chosen colour over a WHITE shop block (no filled band: it printed as a dark block)', (tester) async {
    final doc = samplePrintDoc(products, now);
    Future<BoxDecoration?> band(ShopProfile s) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: SingleChildScrollView(child: TemplatePaper(t: buildBillTemplate(doc: doc, shop: s, l: l), paper: PaperSize.a4, shop: s, size: PrintTextSize.small))),
      ));
      return tester.widget<Container>(find.byKey(const ValueKey('paperShopBlock'))).decoration as BoxDecoration?;
    }

    final modern = (await band(shop.copyWith(billDesign: 'modern', billAccent: 0xFF5B3A8C)))!;
    expect(modern.color, isNull, reason: 'white, never filled');
    expect((modern.border! as Border).top, const BorderSide(color: Color(0xFF5B3A8C), width: 2.5));
    final classic = (await band(shop))!;
    expect(classic.color, isNull, reason: 'Classic is a plain box with a black line');
    expect(classic.border, isNotNull);
  });

  for (final d in ['classic', 'modern', 'compact']) {
    testWidgets('picture of the $d design (A4, MRP hidden on compact)', (tester) async {
      tester.view.physicalSize = const Size(900, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = shop.copyWith(billDesign: d, billHideCols: d == 'compact' ? ['mrp'] : const []);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: SingleChildScrollView(child: RepaintBoundary(key: const ValueKey('shot'), child: TemplatePaper(t: buildBillTemplate(doc: samplePrintDoc(products, now), shop: s, l: l), paper: PaperSize.a4, shop: s, size: PrintTextSize.small)))),
      ));
      await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('goldens/print/design_$d.png'));
    });
  }

  testWidgets('the Shop page changes the design, the Modern colour and the columns', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 2600), location: '/shop', motion: MotionLevel.off, followSystemMotion: false);
    expect(find.byKey(const ValueKey('bill-accent-ff0b6e4f')), findsNothing, reason: 'the colour is only for the Modern design');
    await tester.ensureVisible(find.byKey(const ValueKey('bill-design-modern')));
    await tester.tap(find.byKey(const ValueKey('bill-design-modern')));
    await tester.pumpAndSettle();
    expect(c.read(shopProvider).billDesign, 'modern');
    await tester.ensureVisible(find.byKey(const ValueKey('bill-accent-ff0b6e4f')));
    await tester.tap(find.byKey(const ValueKey('bill-accent-ff0b6e4f')));
    await tester.pumpAndSettle();
    expect(c.read(shopProvider).billAccent, 0xFF0B6E4F);
    await tester.ensureVisible(find.byKey(const ValueKey('bill-col-mrp')));
    await tester.tap(find.byKey(const ValueKey('bill-col-mrp')));
    await tester.pumpAndSettle();
    expect(c.read(shopProvider).billHideCols, ['mrp']);
    await tester.tap(find.byKey(const ValueKey('bill-col-mrp')));
    await tester.pumpAndSettle();
    expect(c.read(shopProvider).billHideCols, isEmpty, reason: 'turned back on');
    await tester.tap(find.byKey(const ValueKey('bill-design-compact')));
    await tester.pumpAndSettle();
    expect(c.read(shopProvider).billDesign, 'compact');
  });
}
