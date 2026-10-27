import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/money.dart';

/// The sticker sizes the shop can print.
enum LabelSize { roll50x25, roll38x25, sheetA4 }

/// How one label is laid out: size in points (1 pt = 1/72 inch = 0.353 mm), the text sizes and the height of the bars.
class LabelSpec {
  const LabelSpec({required this.width, required this.height, required this.margin, required this.name, required this.price, required this.code, required this.bars, required this.quiet});
  final double width, height, margin, name, price, code, bars, quiet;

  static const mm = 72 / 25.4;

  static LabelSpec of(LabelSize s) => switch (s) {
        LabelSize.roll50x25 => const LabelSpec(width: 50 * mm, height: 25 * mm, margin: 3, name: 7, price: 9, code: 7, bars: 24, quiet: 9),
        LabelSize.roll38x25 => const LabelSpec(width: 38 * mm, height: 25 * mm, margin: 2.5, name: 7, price: 9, code: 7, bars: 24, quiet: 7),
        // the common 3 x 7 sticker sheet: 63.5 x 38.1 mm each
        LabelSize.sheetA4 => const LabelSpec(width: 63.5 * mm, height: 38.1 * mm, margin: 5, name: 8.5, price: 11, code: 7, bars: 44, quiet: 14),
      };

  /// A4 sheet: 3 columns and 7 rows; the sheet starts 15.1 mm from the top and 7.2 mm from the left.
  static const sheetColumns = 3, sheetRows = 7;
  static const sheetLeft = 7.2 * mm, sheetTop = 15.1 * mm, sheetGap = 2.5 * mm;
}

/// One product on the label sheet: [copies] stickers of it.
class LabelItem {
  const LabelItem({required this.name, required this.priceText, required this.barcode, required this.copies});
  final String name, priceText, barcode;
  final int copies;
}

/// All labels as one PDF. Roll sizes: one page per sticker, exactly the sticker's size (the printer's driver feeds one sticker per page).
/// A4 sheet: 21 stickers on a page, in the positions of the sticker sheet.
Future<Uint8List> buildLabelsPdf({required List<LabelItem> items, required LabelSize size, String title = 'Barcode labels'}) async {
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf')); // every word on a sticker is bold
  final spec = LabelSpec.of(size);
  final all = [for (final i in items) for (var c = 0; c < i.copies; c++) i];

  pw.Widget label(LabelItem i) => pw.Container(
        width: spec.width,
        height: spec.height,
        padding: pw.EdgeInsets.all(spec.margin),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(i.name, maxLines: 2, overflow: pw.TextOverflow.clip, style: pw.TextStyle(font: bold, fontSize: spec.name, lineSpacing: 0.5)),
          // the blank space at both ends of the bars (the "quiet zone") is what lets a scanner find where the barcode starts
          pw.Padding(
            padding: pw.EdgeInsets.symmetric(horizontal: spec.quiet),
            child: pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: i.barcode, height: spec.bars, drawText: true, textStyle: pw.TextStyle(font: bold, fontSize: spec.code)),
          ),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(i.priceText, style: pw.TextStyle(font: bold, fontSize: spec.price))),
        ]),
      );

  final doc = pw.Document(title: title, creator: 'ASK ERP 2.0', producer: 'ASK ERP 2.0');
  if (size == LabelSize.sheetA4) {
    const perPage = LabelSpec.sheetColumns * LabelSpec.sheetRows;
    for (var start = 0; start < all.length; start += perPage) {
      final page = all.sublist(start, start + perPage > all.length ? all.length : start + perPage);
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(left: LabelSpec.sheetLeft, top: LabelSpec.sheetTop),
        build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          for (var r = 0; r < LabelSpec.sheetRows; r++)
            if (r * LabelSpec.sheetColumns < page.length)
              pw.Row(children: [
                for (var c = 0; c < LabelSpec.sheetColumns; c++) ...[
                  if (c > 0) pw.SizedBox(width: LabelSpec.sheetGap),
                  r * LabelSpec.sheetColumns + c < page.length ? label(page[r * LabelSpec.sheetColumns + c]) : pw.SizedBox(width: spec.width, height: spec.height),
                ],
              ]),
        ]),
      ));
    }
    if (all.isEmpty) doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.SizedBox()));
  } else {
    for (final i in all) {
      doc.addPage(pw.Page(pageFormat: PdfPageFormat(spec.width, spec.height), margin: pw.EdgeInsets.zero, build: (_) => label(i)));
    }
    if (all.isEmpty) doc.addPage(pw.Page(pageFormat: PdfPageFormat(spec.width, spec.height), build: (_) => pw.SizedBox()));
  }
  return doc.save();
}

/// The price as printed on a sticker (with GST, the way a customer pays).
String labelPrice(int pricePaise, {required bool pricesIncludeGst, required int gstBp}) {
  final withGst = pricesIncludeGst ? pricePaise : divRound(pricePaise * (10000 + gstBp), 10000);
  return '₹ ${formatPaise(withGst)}';
}
