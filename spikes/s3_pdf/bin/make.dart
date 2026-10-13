// Spike S3: build A4, 80 mm and 58 mm invoice PDFs from SYNTHETIC data (pure Dart).
import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

String rupees(int paise) {
  final neg = paise < 0;
  final p = paise.abs();
  final r = p ~/ 100, f = p % 100;
  var s = r.toString();
  // Indian grouping: last 3 digits, then groups of 2
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last3';
  }
  return '${neg ? '-' : ''}$s.${f.toString().padLeft(2, '0')}';
}

class Line {
  Line(this.name, this.qty, this.unit, this.ratePaise, this.gst);
  final String name;
  final double qty;
  final String unit;
  final int ratePaise;
  final int gst;
  int get amount => (ratePaise * qty).round();
}

Future<void> main(List<String> args) async {
  final fontDir = args.isNotEmpty ? args[0] : 'D:/dev/fonts_dl';
  final base = pw.Font.ttf(ByteData.view(File('$fontDir/NotoSans.ttf').readAsBytesSync().buffer));
  final bold = pw.Font.ttf(ByteData.view(File('$fontDir/NotoSansBold.ttf').readAsBytesSync().buffer));
  final theme = pw.ThemeData.withFont(base: base, bold: bold);

  final lines = [
    Line('Havells FR wire 1.5 sq mm 90 m red', 2, 'coil', 185000, 18),
    Line('Anchor Roma 6A switch white', 12, 'pcs', 4500, 18),
    Line('Astral CPVC elbow 3/4 inch', 25.5, 'pcs', 3250, 18),
    Line('Fevicol SH 1 kg', 1, 'pcs', 21000, 18),
    for (var i = 0; i < 20; i++) Line('Demo item number ${i + 1} with a rather long product name that must wrap fully, never an ellipsis', 1, 'pcs', 1000 + i * 137, 18),
  ];
  var total = lines.fold<int>(0, (s, l) => s + l.amount);

  final sw = Stopwatch()..start();
  // ---- A4 ----
  final a4 = pw.Document(theme: theme);
  a4.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    header: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('DEMO ENTERPRISES', style: pw.TextStyle(font: bold, fontSize: 18)),
        pw.Text('TAX INVOICE', style: pw.TextStyle(font: bold, fontSize: 14)),
      ]),
      pw.Text('12 Sample Street, Sample Town, Sample State   GSTIN: 33AAAAA0000A1Z5 (demo)'),
      pw.Divider(),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Bill No: A-000123'),
        pw.Text('Date: 13/10/2026'),
      ]),
      pw.SizedBox(height: 6),
    ]),
    build: (c) => [
      pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(font: bold, fontSize: 10),
        cellStyle: const pw.TextStyle(fontSize: 10),
        columnWidths: {0: const pw.FlexColumnWidth(5), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1.4), 3: const pw.FlexColumnWidth(1.6)},
        cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
        headers: ['Item', 'Qty', 'Rate', 'Amount'],
        data: [for (final l in lines) [l.name, '${l.qty} ${l.unit}', rupees(l.ratePaise), rupees(l.amount)]],
      ),
      pw.SizedBox(height: 10),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Grand total  Rs. ${rupees(total)}', style: pw.TextStyle(font: bold, fontSize: 14))),
    ],
    footer: (c) => pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
  ));
  final a4bytes = await a4.save();
  File('out/a4_invoice.pdf').writeAsBytesSync(a4bytes);
  print('A4 invoice (${lines.length} lines): ${sw.elapsedMilliseconds} ms, ${a4bytes.length} bytes');

  Future<void> receipt(String name, double mm, double font) async {
    sw.reset();
    final fmt = PdfPageFormat(mm * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm);
    final d = pw.Document(theme: theme);
    d.addPage(pw.Page(
      pageFormat: fmt,
      build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Center(child: pw.Text('DEMO ENTERPRISES', style: pw.TextStyle(font: bold, fontSize: font + 3))),
        pw.Center(child: pw.Text('Bill A-000123   13/10/2026', style: pw.TextStyle(fontSize: font))),
        pw.Divider(),
        for (final l in lines.take(8)) ...[
          pw.Text(l.name, style: pw.TextStyle(fontSize: font)),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('${l.qty} x ${rupees(l.ratePaise)}', style: pw.TextStyle(fontSize: font)),
            pw.Text(rupees(l.amount), style: pw.TextStyle(fontSize: font)),
          ]),
        ],
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TOTAL', style: pw.TextStyle(font: bold, fontSize: font + 2)),
          pw.Text(rupees(lines.take(8).fold<int>(0, (s, l) => s + l.amount)), style: pw.TextStyle(font: bold, fontSize: font + 2)),
        ]),
        pw.SizedBox(height: 6),
        pw.Center(child: pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: 'A-000123', width: (mm - 8) * PdfPageFormat.mm, height: 30, drawText: true)),
        pw.Center(child: pw.Text('Thank you! (demo data)', style: pw.TextStyle(fontSize: font))),
      ]),
    ));
    final bytes = await d.save();
    File('out/$name.pdf').writeAsBytesSync(bytes);
    print('$name: ${sw.elapsedMilliseconds} ms, ${bytes.length} bytes');
  }

  await receipt('receipt_80mm', 80, 9);
  await receipt('receipt_58mm', 58, 8);
}
