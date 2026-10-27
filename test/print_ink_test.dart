import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:erp2/core/logo_image.dart';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/domain/credit/account.dart';
import 'package:erp2/domain/credit/dues.dart';
import 'package:erp2/domain/credit/ledger.dart';
import 'package:erp2/domain/export/export_table.dart';
import 'package:erp2/domain/models.dart';
import 'package:erp2/domain/orders.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/fake/store.dart' show PaperSize, PrintTextSize;
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/features/credit/receipt_pdf.dart';
import 'package:erp2/features/credit/statement_pdf.dart';
import 'package:erp2/features/export/export_pdf.dart';
import 'package:erp2/features/labels/label_pdf.dart';
import 'package:erp2/features/print/bill_template.dart';
import 'package:erp2/features/print/doc_pdf.dart';
import 'package:erp2/features/print/print_preview.dart' show samplePrintDoc;
import 'package:erp2/features/print/test_page_pdf.dart';
import 'package:erp2/features/purchases/order_pdf.dart';
import 'package:erp2/strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// What these tests prove: every printout of the program is printer-safe. On the shop's inkjet the bill's grey heading rows came out
// solid BLACK over their words: the pdf package writes a see-through colour as a solid one, so "black at 8%" was stored as black. Now
//  * no filled box wider than 30 pt and taller than 8 pt (a heading row, a band, a figure box) is darker than light grey, in any
//    printout: bills in all three designs and sizes, estimates, roll slips, receipts, the statement, reports, the order, stickers and
//    the test page (small dark squares and thin bars are the QR codes and barcodes);
//  * the bill's tint is a solid colour for every design and every colour the shop can pick;
//  * a logo with see-through parts goes into the PDF as a solid picture on white (no see-through layer the printer could print black);
//  * nothing on a bill is smaller than 7 pt.
const l = Strings();
final now = DateTime(2026, 10, 27, 19);

/// The streams of a PDF that are page content (decompressed).
List<String> contents(Uint8List pdf) {
  final raw = latin1.decode(pdf);
  final out = <String>[];
  for (final m in RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream').allMatches(raw)) {
    try {
      out.add(latin1.decode(ZLibCodec().decode(latin1.encode(m.group(1)!))));
    } catch (_) {}
  }
  return out;
}

/// Filled rectangles bigger than [w] x [h] points with their fill colour (0..1 per channel), as the pdf package writes them:
/// "r g b rg" then "x y w h re" ... "f".
List<(double, double, List<double>)> bigFills(Uint8List pdf, {double w = 30, double h = 8}) {
  final out = <(double, double, List<double>)>[];
  // fill colour; a rectangle; a fill (f, f*, F, B, b); a path ended without filling (n: a clipping outline, S/s: a stroked line)
  final op = RegExp(r'([-0-9.]+) ([-0-9.]+) ([-0-9.]+) rg|([-0-9.]+) ([-0-9.]+) ([-0-9.]+) ([-0-9.]+) re|(?<![A-Za-z*])([fFBb])\*?(?![A-Za-z])|(?<![A-Za-z*])([nSs])(?![A-Za-z])');
  for (final c in contents(pdf)) {
    var fill = <double>[0, 0, 0];
    final rects = <(double, double)>[];
    for (final m in op.allMatches(c)) {
      if (m.group(1) != null) {
        fill = [double.parse(m.group(1)!), double.parse(m.group(2)!), double.parse(m.group(3)!)];
      } else if (m.group(4) != null) {
        rects.add((double.parse(m.group(6)!).abs(), double.parse(m.group(7)!).abs()));
      } else if (m.group(9) != null) {
        rects.clear();
      } else {
        for (final r in rects) {
          if (r.$1 > w && r.$2 > h) out.add((r.$1, r.$2, fill));
        }
        rects.clear();
      }
    }
  }
  return out;
}

void expectLightFills(Uint8List pdf, String what) {
  for (final f in bigFills(pdf)) {
    expect(f.$3.every((x) => x >= 0.85), isTrue, reason: '$what: a ${f.$1.round()} x ${f.$2.round()} pt box filled with ${f.$3} is too dark to print');
  }
}

Set<double> fontSizes(Uint8List pdf) => {for (final c in contents(pdf)) for (final m in RegExp(r'/F\d+\s+([0-9.]+)\s+Tf').allMatches(c)) double.parse(m.group(1)!)};

void main() {
  final products = seedProducts();

  test('the bill tint is solid for every design and every colour the shop can pick; the classic one is light grey', () {
    for (final d in ['classic', 'modern', 'compact']) {
      for (final a in [0xFF1F4E79, 0xFF0B6E4F, 0xFF8E2C48, 0xFF5B3A8C, 0xFFB45309, 0xFF334155, 0x401F4E79]) {
        final look = BillLook.of(ShopProfile.sample.copyWith(billDesign: d, billAccent: a));
        expect(look.tint >>> 24, 0xFF, reason: '$d ${a.toRadixString(16)}');
        expect(look.accent >>> 24, 0xFF);
        expect([(look.tint >> 16) & 0xFF, (look.tint >> 8) & 0xFF, look.tint & 0xFF].every((v) => v >= 0xD8), isTrue, reason: 'light enough for black words');
      }
    }
    expect(BillLook.of(ShopProfile.sample).tint, 0xFFE8E8E8);
  });

  test('every printout: no dark filled box (heading rows, bands and boxes are light grey with black words)', () async {
    const shop = ShopProfile.sample;
    final inv = samplePrintDoc(products, now), est = samplePrintDoc(products, now, mode: DocMode.estimation);
    for (final d in ['classic', 'modern', 'compact']) {
      for (final p in [PaperSize.a4, PaperSize.a5]) {
        for (final s in PrintTextSize.values) {
          expectLightFills(await buildDocPdf(doc: inv, paper: p, shop: shop.copyWith(billDesign: d), size: s, l: l), 'bill $d ${p.name} ${s.name}');
        }
      }
    }
    expectLightFills(await buildDocPdf(doc: est, paper: PaperSize.a4, shop: shop, size: PrintTextSize.small, l: l), 'estimate');
    for (final p in [PaperSize.mm80, PaperSize.mm58]) {
      expectLightFills(await buildDocPdf(doc: inv, paper: p, shop: shop, size: PrintTextSize.small, l: l), 'roll ${p.name}');
    }
    final r = PaymentReceipt(number: 'RCP-1', customerId: 'c1', customerName: 'Murugan', amountPaise: 150000, mode: 'upi', at: now, note: '', allocations: const [Allocation('A-1', 150000)], advancePaise: 0, balanceAfter: 0);
    for (final p in PaperSize.values) {
      expectLightFills(await buildPaymentReceiptPdf(receipt: r, shopName: shop.name, shopPhone: shop.phone, paper: p, l: l), 'receipt ${p.name}');
    }
    final st = buildStatement(entries: [
      LedgerEntry(id: 'e1', customerId: 'c1', kind: LedgerKind.opening, amountPaise: 120000, at: now.subtract(const Duration(days: 40))),
      LedgerEntry(id: 'e2', customerId: 'c1', kind: LedgerKind.billCredit, amountPaise: 761900, at: now.subtract(const Duration(days: 10)), billNo: 'A-1'),
    ], from: now.subtract(const Duration(days: 60)), to: now);
    expectLightFills(await buildStatementPdf(statement: st, customer: const Customer(id: 'c1', name: 'Murugan', phone: '9', city: 'X', balancePaise: 0), shopName: shop.name, shopPhone: shop.phone, today: now, l: l, shop: shop), 'statement');
    final table = ExportTable(name: 'Products', headers: const ['Name', 'Stock', 'Worth'], rows: [for (var i = 0; i < 40; i++) ['Item $i', '$i', '${i * 10}.00']]);
    expectLightFills(await encodePdf(table, shopName: shop.name, now: now, shop: shop), 'report');
    expectLightFills(await buildOrderPdf(order: OrderDoc(id: 'o', number: 'PO-1', date: now, dealerId: 'd', dealerName: 'Kumar', status: OrderStatus.open, note: '', lines: [for (final p in products.take(3)) OrderLine(productId: p.id, name: p.name, unit: p.unit, qtyMilli: 1000)]), dealerPhone: '9', shop: shop, now: now), 'order');
    for (final s in LabelSize.values) {
      expectLightFills(await buildLabelsPdf(items: const [LabelItem(name: 'BULB', priceText: 'Rs. 10.00', barcode: 'SE000665', copies: 2)], size: s), 'labels ${s.name}');
    }
    expectLightFills(await buildTestPagePdf(shopName: shop.name, now: now, printerName: 'HP', l: l), 'test page');
  });

  test('a logo with see-through parts goes into every PDF as a solid picture (no see-through layer)', () async {
    final pic = img.Image(width: 40, height: 40, numChannels: 4);
    img.fill(pic, color: img.ColorRgba8(0, 0, 0, 0)); // see-through
    img.fillRect(pic, x1: 10, y1: 10, x2: 30, y2: 30, color: img.ColorRgba8(200, 30, 30, 255));
    final shop = ShopProfile.sample.copyWith(logoPng: base64Encode(img.encodePng(pic)));
    final jpeg = pdfLogoBytes(shop.logoPng)!;
    expect(jpeg.sublist(0, 2), [0xFF, 0xD8], reason: 'a JPEG: it can never carry a see-through layer');
    final back = img.decodeJpg(jpeg)!;
    expect(back.getPixel(2, 2).r, greaterThan(240), reason: 'the see-through corner is white, not black');
    final bill = await buildDocPdf(doc: samplePrintDoc(products, now), paper: PaperSize.a4, shop: shop, size: PrintTextSize.small, l: l);
    expect(latin1.decode(bill).contains('/SMask'), isFalse);
    final report = await encodePdf(const ExportTable(name: 'X', headers: ['A'], rows: [['1']]), shopName: shop.name, now: now, shop: shop);
    expect(latin1.decode(report).contains('/SMask'), isFalse);
    // the logo picker itself lays a see-through logo on white before it is saved
    final saved = base64Decode(prepareLogo(img.encodePng(pic))!);
    expect(img.decodePng(saved)!.getPixel(0, 0).r, 255);
  });

  test('nothing on a bill is smaller than 7 pt on A4 and 6.5 pt on A5, in any design or print text size', () async {
    final inv = samplePrintDoc(products, now);
    for (final d in ['classic', 'modern', 'compact']) {
      for (final p in [PaperSize.a4, PaperSize.a5]) {
        for (final s in PrintTextSize.values) {
          final sizes = fontSizes(await buildDocPdf(doc: inv, paper: p, shop: ShopProfile.sample.copyWith(billDesign: d), size: s, l: l));
          expect(sizes.reduce((a, b) => a < b ? a : b), greaterThanOrEqualTo(p == PaperSize.a5 ? 6.5 : 7), reason: '$d ${p.name} ${s.name}: $sizes');
        }
      }
    }
  });
}
