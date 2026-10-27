/// The look every PDF of the program shares (reports, statements, orders, GST returns): the shop's logo, name and details at the top, a title and date on the
/// right, figure boxes, a light grey table header with black words, ruled rows, a heavier totals row, and a foot with "Page x of y".
///
/// PRINTING RULES (every printout follows them; the shop's inkjet printed the old dark header as a black bar):
///  * words are black or dark grey (#333 / #444), never light grey; nothing smaller than 7.5 pt;
///  * a filled area is only a LIGHT solid grey (#E6E6E6 or lighter) with black words on it: never a dark fill, never white words,
///    never a see-through colour (the pdf package writes a colour's see-through part as solid colour);
///  * lines are at least 0.5 pt and grey #8C8C8C or darker; greys are neutral (R = G = B) so the printer uses black ink only;
///  * no rounded corners on boxes (some drivers turn the clipped corners into grey blocks).
library;

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/date_fmt.dart';
import '../../core/logo_image.dart';
import '../../fake/shop_profile.dart';

const pdfInk = PdfColors.black;
const pdfSoft = PdfColor.fromInt(0xFF444444);
const pdfHead = PdfColor.fromInt(0xFFE6E6E6);
const pdfBand = PdfColor.fromInt(0xFFF2F2F2);
const pdfLine = PdfColor.fromInt(0xFF8C8C8C);
const pdfFrame = PdfColor.fromInt(0xFF555555);
const pdfTotal = PdfColor.fromInt(0xFFEDEDED);

class PdfKit {
  PdfKit._(this.font, this.bold, this.logo, this.name, this.details, this.upiId);
  final pw.Font font, bold;
  final Uint8List? logo;
  final String name;

  /// Address, then phone and GSTIN, one line each (empty ones left out).
  final List<String> details;
  final String upiId;

  /// Loads the fonts and the shop's logo. A shop without a logo gets none (the program's own logo is a dark square that printed as a
  /// heavy dark block).
  static Future<PdfKit> load({ShopProfile? shop, String shopName = ''}) async {
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final logo = shop == null ? null : pdfLogoBytes(shop.logoPng);
    final name = shop != null && shop.name.trim().isNotEmpty ? shop.name.trim() : shopName;
    final details = <String>[
      if (shop != null && shop.address.trim().isNotEmpty) shop.address.trim(),
      [if (shop != null && shop.phone.trim().isNotEmpty) 'Phone: ${shop.phone.trim()}', if (shop != null && shop.gstin.trim().isNotEmpty) 'GSTIN: ${shop.gstin.trim()}'].join('    '),
    ].where((x) => x.isNotEmpty).toList();
    return PdfKit._(font, bold, logo, name, details, shop?.upiId.trim() ?? '');
  }

  pw.TextStyle st({bool b = false, double size = 8, PdfColor? color}) => pw.TextStyle(font: b ? bold : font, fontSize: size, color: color);

  pw.Widget logoBox(double h) => logo == null ? pw.SizedBox(width: 0) : pw.Padding(padding: const pw.EdgeInsets.only(right: 10), child: pw.Image(pw.MemoryImage(logo!), height: h));

  /// The top of the first page: logo, shop name and details on the left, [title] with [lines] under it on the right.
  pw.Widget header(String title, List<String> lines) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: pdfInk, width: 1.2))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          logoBox(46),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(name.isEmpty ? 'ASK ERP 2.0' : name, style: st(b: true, size: 16, color: pdfInk)),
              for (final d in details) pw.Padding(padding: const pw.EdgeInsets.only(top: 1.5), child: pw.Text(d, style: st(size: 8.5, color: const PdfColor.fromInt(0xFF333333)))),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(title, style: st(b: true, size: 15, color: pdfInk)),
            pw.SizedBox(height: 2),
            for (final x in lines) pw.Text(x, style: st(size: 8.5, color: pdfSoft)),
          ]),
        ]),
      );

  /// The small header of the pages after the first.
  pw.Widget pageHeader(pw.Context c, String title, DateTime now) => c.pageNumber == 1
      ? pw.SizedBox()
      : pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Row(children: [logoBox(18), pw.Text(name, style: st(b: true, size: 10, color: pdfInk))]),
            pw.Text('$title  -  ${formatDate(now)}  ${formatTime(now)}', style: st(size: 8.5, color: pdfSoft)),
          ]),
        );

  pw.Widget footer(pw.Context c, String title) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: pdfLine, width: 0.5))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('${name.isEmpty ? '' : '$name  -  '}$title', style: st(size: 8, color: pdfSoft)),
          pw.Text('Made with ASK ERP 2.0', style: st(size: 8, color: pdfSoft)),
          pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: st(size: 8, color: pdfSoft)),
        ]),
      );

  /// A figure box: a small label over a bold value.
  pw.Widget figure(String label, String value, {PdfColor? valueColor}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: pdfFrame, width: 0.75)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisSize: pw.MainAxisSize.min, children: [
          pw.Text(label, style: st(size: 8, color: pdfSoft)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: st(b: true, size: 12, color: valueColor ?? pdfInk)),
        ]),
      );

  pw.Widget figures(List<(String, String)> items) => pw.Wrap(spacing: 8, runSpacing: 8, children: [for (final f in items) figure(f.$1, f.$2)]);

  pw.Widget cell(String s, {bool right = false, bool b = false, PdfColor? color, double size = 8}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 2.6),
        child: pw.Text(s, textAlign: right ? pw.TextAlign.right : pw.TextAlign.left, style: st(b: b, color: color, size: size)),
      );

  /// A table: a light grey header row with black words (repeats on every page), ruled rows, an optional heavier totals row. [widths] are
  /// the flex weights of the columns.
  pw.Widget table({required List<String> headers, required List<List<String>> rows, required List<bool> right, required List<double> widths, List<String>? totals, double size = 8, bool serial = true}) {
    final cols = headers.length;
    final out = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: pdfHead, border: pw.Border(top: pw.BorderSide(color: pdfInk, width: 0.8), bottom: pw.BorderSide(color: pdfInk, width: 0.8))),
        children: [if (serial) cell('S.No', b: true, size: size), for (var c = 0; c < cols; c++) cell(headers[c], b: true, right: right[c], size: size)],
      ),
      for (var i = 0; i < rows.length; i++)
        pw.TableRow(
          children: [if (serial) cell('${i + 1}', right: true, color: pdfSoft, size: size), for (var c = 0; c < cols; c++) cell(c < rows[i].length ? rows[i][c] : '', right: right[c], size: size)],
        ),
      if (totals != null)
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: pdfTotal, border: pw.Border(top: pw.BorderSide(color: pdfInk, width: 1), bottom: pw.BorderSide(color: pdfInk, width: 1))),
          children: [if (serial) cell('', size: size), for (var c = 0; c < cols; c++) cell(c < totals.length ? totals[c] : '', right: right[c], b: true, size: size)],
        ),
    ];
    return pw.Table(
      border: const pw.TableBorder(left: pw.BorderSide(color: pdfFrame, width: 0.75), right: pw.BorderSide(color: pdfFrame, width: 0.75), bottom: pw.BorderSide(color: pdfFrame, width: 0.75), horizontalInside: pw.BorderSide(color: pdfLine, width: 0.5), verticalInside: pw.BorderSide(color: pdfLine, width: 0.5)),
      columnWidths: {
        if (serial) 0: const pw.FixedColumnWidth(34),
        for (var c = 0; c < cols; c++) c + (serial ? 1 : 0): pw.FlexColumnWidth(widths[c]),
      },
      children: out,
    );
  }
}
