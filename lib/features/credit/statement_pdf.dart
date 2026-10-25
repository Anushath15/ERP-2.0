import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../domain/credit/dues.dart';
import '../../fake/models.dart';
import '../../fake/shop_profile.dart';
import '../../strings.dart';
import '../export/pdf_kit.dart';
import 'credit_dialogs.dart' show ledgerKindLabel;

/// Makes the account statement as an A4 PDF (pure Dart, no plugin): the shop's logo and details, who the statement is for and the dates, the amounts in
/// boxes, the numbered ledger with a running balance, and a clear "Amount to pay" line (with the shop's UPI ID when it has one).
Future<Uint8List> buildStatementPdf({
  required Statement statement,
  required Customer customer,
  required String shopName,
  required String shopPhone,
  required DateTime today,
  required Strings l,
  bool dealer = false,
  ShopProfile? shop,
}) async {
  final kit = await PdfKit.load(shop: shop, shopName: shopName);
  String m(int v) => v == 0 ? '' : formatPaise(v);
  final from = statement.from.year <= 2000 ? DateTime(2000) : statement.from;
  final due = statement.closingPaise;

  final doc = pw.Document(title: '${l.statementTitle} ${customer.name}', author: kit.name.isEmpty ? shopName : kit.name, creator: 'ASK ERP 2.0', producer: 'ASK ERP 2.0');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
    header: (c) => kit.pageHeader(c, '${l.statementTitle} - ${customer.name}', today),
    footer: (c) => kit.footer(c, '${l.statementTitle} - ${customer.name}'),
    build: (ctx) => [
      kit.header(l.statementTitle.toUpperCase(), ['${formatDate(from)} - ${formatDate(statement.to)}', '${l.rcDate}: ${formatDate(today)}']),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: pdfLine, width: 0.6), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(customer.name, style: kit.st(b: true, size: 12, color: pdfInk)),
          if (customer.phone.trim().isNotEmpty) pw.Text('Phone: ${customer.phone.trim()}', style: kit.st(size: 9, color: pdfSoft)),
          if (customer.city.trim().isNotEmpty) pw.Text(customer.city.trim(), style: kit.st(size: 9, color: pdfSoft)),
        ]),
      ),
      pw.SizedBox(height: 10),
      kit.figures([
        (l.stOpening, formatPaise(statement.openingPaise, symbol: true)),
        (l.stCharges, formatPaise(statement.totalCharges, symbol: true)),
        (l.stCredits, formatPaise(statement.totalCredits, symbol: true)),
        (due < 0 ? l.custAdvance : l.stClosing, formatPaise(due.abs(), symbol: true)),
      ]),
      pw.SizedBox(height: 12),
      kit.table(
        headers: [l.colDate, l.colType, l.colCharged, l.rcReceived, l.colRunning],
        right: const [false, false, true, true, true],
        widths: const [12, 40, 14, 14, 16],
        size: 8.5,
        rows: [
          [formatDate(from), l.stOpening, '', '', formatPaise(statement.openingPaise)],
          for (final ln in statement.lines)
            [
              formatDate(ln.at),
              '${ledgerKindLabel(l, ln.kind, dealer: dealer)}${ln.billNo == null ? '' : ' ${ln.billNo}'}${ln.note.isEmpty ? '' : ' (${ln.note})'}',
              m(ln.chargePaise),
              m(ln.creditPaise),
              formatPaise(ln.runningPaise),
            ],
        ],
        totals: ['', l.stClosing, formatPaise(statement.totalCharges), formatPaise(statement.totalCredits), formatPaise(due)],
      ),
      pw.SizedBox(height: 12),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(color: pdfBand, borderRadius: pw.BorderRadius.circular(4), border: pw.Border.all(color: pdfInk, width: 0.8)),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(due < 0 ? l.custAdvance : l.stClosing, style: kit.st(b: true, size: 12, color: pdfInk)),
          pw.Text(formatPaise(due.abs(), symbol: true), style: kit.st(b: true, size: 15, color: pdfInk)),
        ]),
      ),
      if (due > 0 && kit.upiId.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 6), child: pw.Text('Pay by UPI: ${kit.upiId}', style: kit.st(b: true, size: 9.5, color: pdfInk))),
      pw.SizedBox(height: 10),
      pw.Center(child: pw.Text(l.statementHint, style: kit.st(size: 8, color: pdfSoft))),
    ],
  ));
  return doc.save();
}
