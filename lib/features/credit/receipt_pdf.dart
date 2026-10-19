import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../domain/credit/account.dart';
import '../../fake/store.dart' show PaperSize;
import '../../strings.dart';
import '../print/print_layout.dart';

/// The payment receipt (money received from a customer) as a PDF, the same lines as the receipt on the screen.
///  * Roll paper (80 mm, 58 mm): a slip exactly as long as its lines.
///  * A4 / A5: an A5 page with the slip at the top, centred (so a small receipt does not print huge on a big sheet).
Future<Uint8List> buildPaymentReceiptPdf({
  required PaymentReceipt receipt,
  required String shopName,
  required String shopPhone,
  required PaperSize paper,
  required Strings l,
}) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Variable.ttf'));
  final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  final roll = isRoll(paper);
  final slipWidth = roll ? paperWidthPt(paper) - 2 * paperMarginPt(paper) : 250.0;
  pw.TextStyle s({bool b = false, double size = 9.5}) => pw.TextStyle(font: b ? boldFont : regular, fontSize: size, lineSpacing: 1.5);
  String mode(String m) => switch (m) { 'upi' => l.payUpi, 'card' => l.payCard, _ => l.payCash };
  pw.Widget line() => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Divider(height: 1, thickness: 0.6));
  pw.Widget two(String a, String b, {bool bold = false, double size = 9.5}) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(a, style: s(b: bold, size: size)), pw.Text(b, style: s(b: bold, size: size))]);

  final r = receipt;
  final slip = pw.SizedBox(
    width: slipWidth,
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Center(child: pw.Text(shopName.toUpperCase(), style: s(b: true, size: 12))),
      if (shopPhone.trim().isNotEmpty) pw.Center(child: pw.Text('Ph: ${shopPhone.trim()}', style: s())),
      line(),
      pw.Center(child: pw.Text(l.rcPaymentReceipt, style: s(b: true, size: 10.5))),
      pw.SizedBox(height: 5),
      pw.Text('${l.rcReceiptNo}: ${r.number}', style: s(b: true)),
      pw.Text('${l.rcDate}: ${formatDate(r.at)}', style: s()),
      pw.Text('${l.rcReceivedFrom}: ${r.customerName}', style: s()),
      pw.Text('${l.rcPaidBy}: ${mode(r.mode)}', style: s()),
      line(),
      two(l.rcAmount.toUpperCase(), '₹ ${formatPaise(r.amountPaise)}', bold: true, size: 11),
      if (r.allocations.isNotEmpty) ...[
        pw.SizedBox(height: 5),
        pw.Text(l.rcAppliedTo, style: s(b: true)),
        for (final a in r.allocations) two(a.billNo, formatPaise(a.paise)),
      ],
      if (r.advancePaise > 0) two(l.rcAdvance, formatPaise(r.advancePaise)),
      line(),
      two(r.balanceAfter < 0 ? l.rcAdvanceNow : l.rcBalanceNow, '₹ ${formatPaise(r.balanceAfter.abs())}', bold: true),
      pw.SizedBox(height: 8),
      pw.Center(child: pw.Text(l.rcThanks, style: s(), textAlign: pw.TextAlign.center)),
    ]),
  );

  final pdf = pw.Document(title: '${l.rcPaymentReceipt} ${r.number}', author: shopName, creator: 'ASK ERP 2.0', producer: 'ASK ERP 2.0');
  if (roll) {
    final m = paperMarginPt(paper);
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat(paperWidthPt(paper), double.infinity, marginAll: m), build: (_) => slip));
  } else {
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a5.applyMargin(left: 28, top: 28, right: 28, bottom: 28), build: (_) => pw.Align(alignment: pw.Alignment.topCenter, child: slip)));
  }
  return pdf.save();
}
