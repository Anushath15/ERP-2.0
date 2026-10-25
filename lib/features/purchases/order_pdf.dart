import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../domain/orders.dart';
import '../../fake/shop_profile.dart';
import '../export/pdf_kit.dart';

/// An order to a dealer as an A4 PDF: the shop's details, who it is for, a numbered list of items with quantities and a note. No rates are printed.
Future<Uint8List> buildOrderPdf({required OrderDoc order, required String dealerPhone, required ShopProfile shop, required DateTime now}) async {
  final kit = await PdfKit.load(shop: shop, shopName: shop.name);
  final title = 'Order ${order.number}';
  final doc = pw.Document(title: title, author: kit.name, creator: 'ASK ERP 2.0', producer: 'ASK ERP 2.0');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
    header: (c) => kit.pageHeader(c, title, now),
    footer: (c) => kit.footer(c, title),
    build: (_) => [
      kit.header('PURCHASE ORDER', ['No: ${order.number}', 'Date: ${formatDate(order.date)}']),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: pdfLine, width: 0.6), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('To', style: kit.st(size: 8, color: pdfSoft)),
          pw.Text(order.dealerName, style: kit.st(b: true, size: 12, color: pdfInk)),
          if (dealerPhone.trim().isNotEmpty) pw.Text('Phone: ${dealerPhone.trim()}', style: kit.st(size: 9, color: pdfSoft)),
        ]),
      ),
      pw.SizedBox(height: 10),
      kit.figures([('Items', '${order.lines.length}')]),
      pw.SizedBox(height: 12),
      kit.table(
        headers: const ['Item', 'Quantity', 'Unit'],
        right: const [false, true, false],
        widths: const [60, 14, 10],
        size: 9.5,
        rows: [for (final l in order.lines) [l.name, formatQty(l.qtyMilli), l.unit]],
      ),
      if (order.note.trim().isNotEmpty) ...[
        pw.SizedBox(height: 12),
        pw.Text('Note', style: kit.st(b: true, size: 9, color: pdfInk)),
        pw.Text(order.note.trim(), style: kit.st(size: 9.5, color: pdfInk)),
      ],
      pw.SizedBox(height: 14),
      pw.Text('Please confirm the rates and when you can deliver.', style: kit.st(size: 8.5, color: pdfSoft)),
    ],
  ));
  return doc.save();
}
