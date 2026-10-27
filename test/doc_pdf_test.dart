import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/domain_lite/bill_calc.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/features/print/doc_pdf.dart';
import 'package:erp2/features/print/print_layout.dart';
import 'package:erp2/features/print/print_preview.dart' show samplePrintDoc;
import 'package:erp2/fake/models.dart';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/fake/store.dart' show PaperSize, PrintTextSize;
import 'package:erp2/strings.dart';

// The real PDFs of a bill and an estimate: page size, one page, no big blank space, and the font sizes of each "Print text size".
// (The pictures of these PDFs are made by tool/pdf_check.py when PyMuPDF is installed; they are written to build/test_pdfs/.)
const l = Strings();
final now = DateTime(2026, 10, 13, 17, 30);
final products = seedProducts();

/// The text of every PDF page's content, decompressed, as one string (for reading font sizes).
String contentOf(Uint8List pdf) {
  final raw = latin1.decode(pdf);
  final out = StringBuffer();
  for (final m in RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream').allMatches(raw)) {
    final bytes = latin1.encode(m.group(1)!);
    try {
      out.writeln(latin1.decode(ZLibCodec().decode(bytes)));
    } catch (_) {
      // not a compressed stream (a font or an image): skip
    }
  }
  return out.toString();
}

/// The distinct font sizes (points) used on the page: "/F1 9.5 Tf".
Set<double> fontSizes(Uint8List pdf) => {for (final m in RegExp(r'/F\d+\s+([0-9.]+)\s+Tf').allMatches(contentOf(pdf))) double.parse(m.group(1)!)};

List<double> mediaBox(Uint8List pdf) {
  final m = RegExp(r'/MediaBox\s*\[\s*([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s*\]').firstMatch(latin1.decode(pdf))!;
  return [for (var i = 1; i <= 4; i++) double.parse(m.group(i)!)];
}

int pages(Uint8List pdf) => RegExp(r'/Type\s*/Page(?![a-z])').allMatches(latin1.decode(pdf)).length;

PrintDoc estimate() => samplePrintDoc(products, now, mode: DocMode.estimation);
PrintDoc invoice() => samplePrintDoc(products, now);

PrintDoc bigInvoice(int lines, {DocMode mode = DocMode.invoice}) {
  final ls = [for (var i = 0; i < lines; i++) CartLine(product: products[(i * 13) % products.length], qtyMilli: 1000 * (1 + i % 4))];
  return PrintDoc(mode: mode, number: 'A-020002', date: now, customer: 'Murugan Electricals', lines: ls, calc: calcBill(ls), pay: PayMode.cash);
}

void main() {
  const shop = ShopProfile.sample;
  final outDir = Directory('build/test_pdfs')..createSync(recursive: true);

  Future<Uint8List> make(PrintDoc doc, PaperSize paper, PrintTextSize size, String name) async {
    final b = await buildDocPdf(doc: doc, paper: paper, shop: shop, size: size, l: l);
    File('${outDir.path}/$name.pdf').writeAsBytesSync(b);
    return b;
  }

  group('page sizes and no blank space at the bottom', () {
    test('an estimate is a normal A4 page in the shop template, one page for a short one', () async {
      final b = await make(estimate(), PaperSize.a4, PrintTextSize.small, 'estimate_a4_small');
      final box = mediaBox(b);
      expect(box[2], closeTo(595.28, 1), reason: 'A4 width');
      expect(box[3], closeTo(841.89, 1), reason: 'A4 height');
      expect(pages(b), 1);
    });

    test('roll paper: 80 mm and 58 mm wide, as long as the content, one page', () async {
      for (final (paper, w) in [(PaperSize.mm80, 227.0), (PaperSize.mm58, 164.0)]) {
        final b = await make(invoice(), paper, PrintTextSize.small, 'invoice_${paper.name}_small');
        final box = mediaBox(b);
        expect(box[2], closeTo(w, 1.5), reason: '${paper.name} width');
        expect(box[3], lessThan(900));
        expect(pages(b), 1);
      }
    });

    test('A4 and A5 tax invoices are normal pages of that paper size', () async {
      final a4 = mediaBox(await make(invoice(), PaperSize.a4, PrintTextSize.small, 'invoice_a4_small'));
      expect(a4[2], closeTo(595.28, 1));
      expect(a4[3], closeTo(841.89, 1));
      final a5 = mediaBox(await make(invoice(), PaperSize.a5, PrintTextSize.small, 'invoice_a5_small'));
      expect(a5[2], closeTo(419.53, 1));
      expect(a5[3], closeTo(595.28, 1));
    });

    test('a short bill fits one page on A4, A5, 80 mm and 58 mm at every text size (nothing is cut off)', () async {
      for (final paper in PaperSize.values) {
        for (final size in PrintTextSize.values) {
          final b = await make(invoice(), paper, size, 'invoice_${paper.name}_${size.name}');
          expect(pages(b), 1, reason: '${paper.name} ${size.name}');
        }
      }
    });

    test('the shop rule: 41 products on one A4 sheet and 20 on one A5 sheet, bill and estimate, at the default text size', () async {
      for (final mode in [DocMode.invoice, DocMode.estimation]) {
        expect(pages(await make(bigInvoice(41, mode: mode), PaperSize.a4, PrintTextSize.small, 'a4_41_${mode.name}')), 1, reason: 'A4 ${mode.name}');
        expect(pages(await make(bigInvoice(20, mode: mode), PaperSize.a5, PrintTextSize.small, 'a5_20_${mode.name}')), 1, reason: 'A5 ${mode.name}');
      }
    });

    test('many products on one paper: 30 items fit one A4 page at the default size, 45 on two at most', () async {
      expect(pages(await make(bigInvoice(30), PaperSize.a4, PrintTextSize.small, 'thirty_a4_small')), 1);
      expect(pages(await make(bigInvoice(45), PaperSize.a4, PrintTextSize.small, 'fortyfive_a4_small')), lessThanOrEqualTo(2));
    });

    test('a long bill (60 lines) flows onto more pages on A4 and A5 instead of being cut off', () async {
      final b4 = await make(bigInvoice(60), PaperSize.a4, PrintTextSize.normal, 'long_a4_normal');
      expect(pages(b4), greaterThan(1));
      final b5 = await make(bigInvoice(60), PaperSize.a5, PrintTextSize.normal, 'long_a5_normal');
      expect(pages(b5), greaterThan(pages(b4) - 1));
    });
  });

  group('print text size', () {
    test('Small is the default: 7.5 pt text and the 13 pt shop name on an A4 bill (the shop template, small so that many items fit)', () async {
      final sizes = fontSizes(await make(invoice(), PaperSize.a4, PrintTextSize.small, 'invoice_a4_small'));
      expect(sizes, containsAll([7.5, 13.0]));
      expect(sizes.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(13.0), reason: 'nothing bigger than the shop name');
    });

    test('Smaller < Small < Normal: the row text grows with the choice', () async {
      double rows(PrintTextSize s) => PrintMetrics.of(s).row;
      expect(rows(PrintTextSize.smaller), lessThan(rows(PrintTextSize.small)));
      expect(rows(PrintTextSize.small), lessThan(rows(PrintTextSize.normal)));
      for (final size in PrintTextSize.values) {
        final used = fontSizes(await make(invoice(), PaperSize.a4, size, 'invoice_a4_${size.name}'));
        final m = PrintMetrics.of(size);
        expect(used, containsAll([(m.row - 2.0).clamp(7.0, 12.0), m.shop + 1]), reason: size.name); // never below 7 pt on A4 (printer-safe)
        expect(used.every((x) => x <= m.shop + 1.01), isTrue, reason: '${size.name}: sizes $used');
      }
    });

    test('the default is small', () {
      expect(PrintTextSize.values[1], PrintTextSize.small);
    });
  });
}
