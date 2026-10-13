import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../domain/credit/dues.dart';
import '../../fake/models.dart';
import '../../strings.dart';
import 'credit_dialogs.dart' show ledgerKindLabel;

/// Makes the statement as an A4 PDF (pure Dart, no plugin). Uses the Inter font from the app so the rupee sign prints.
Future<Uint8List> buildStatementPdf({
  required Statement statement,
  required Customer customer,
  required String shopName,
  required String shopPhone,
  required DateTime today,
  required Strings l,
  bool dealer = false,
}) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Variable.ttf'));
  final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  pw.TextStyle s({bool b = false, double size = 9.5}) => pw.TextStyle(font: b ? boldFont : regular, fontSize: size);
  pw.Widget cell(String t, double w, {bool b = false, bool right = true}) => pw.SizedBox(width: w, child: pw.Text(t, textAlign: right ? pw.TextAlign.right : pw.TextAlign.left, style: s(b: b)));
  String m(int v) => v == 0 ? '' : formatPaise(v);

  final doc = pw.Document(title: '${l.statementTitle} ${customer.name}', author: shopName, creator: 'ASK ERP 2.0', producer: 'ASK ERP 2.0');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (ctx) => [
      pw.Text(shopName.toUpperCase(), style: s(b: true, size: 16)),
      pw.Text('Ph: $shopPhone', style: s()),
      pw.Divider(),
      pw.Center(child: pw.Text(l.statementTitle.toUpperCase(), style: s(b: true, size: 13))),
      pw.SizedBox(height: 8),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(customer.name, style: s(b: true)), pw.Text(customer.phone, style: s()), pw.Text(customer.city, style: s())]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('${formatDate(statement.from.year <= 2000 ? DateTime(2000) : statement.from)} - ${formatDate(statement.to)}', style: s()),
          pw.Text('${l.rcDate}: ${formatDate(today)}', style: s()),
        ]),
      ]),
      pw.Divider(),
      pw.Row(children: [pw.Expanded(child: pw.Text(l.stOpening, style: s(b: true))), cell(formatPaise(statement.openingPaise), 80, b: true)]),
      pw.SizedBox(height: 4),
      pw.Row(children: [cell(l.colDate, 60, b: true, right: false), pw.Expanded(child: pw.Text(l.colType, style: s(b: true))), cell(l.colCharged, 70, b: true), cell(l.rcReceived, 70, b: true), cell(l.colRunning, 70, b: true)]),
      pw.Divider(thickness: 0.5),
      for (final ln in statement.lines)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            cell(formatDate(ln.at), 60, right: false),
            pw.Expanded(child: pw.Text('${ledgerKindLabel(l, ln.kind, dealer: dealer)}${ln.billNo == null ? '' : ' ${ln.billNo}'}${ln.note.isEmpty ? '' : ' (${ln.note})'}', style: s())),
            cell(m(ln.chargePaise), 70),
            cell(m(ln.creditPaise), 70),
            cell(formatPaise(ln.runningPaise), 70),
          ]),
        ),
      pw.Divider(),
      pw.Row(children: [pw.Expanded(child: pw.Text(l.stCharges, style: s())), cell(formatPaise(statement.totalCharges), 80)]),
      pw.Row(children: [pw.Expanded(child: pw.Text(l.stCredits, style: s())), cell(formatPaise(statement.totalCredits), 80)]),
      pw.Row(children: [pw.Expanded(child: pw.Text(statement.closingPaise < 0 ? l.custAdvance : l.stClosing, style: s(b: true, size: 12))), cell('₹ ${formatPaise(statement.closingPaise.abs())}', 110, b: true)]),
      pw.SizedBox(height: 14),
      pw.Center(child: pw.Text(l.statementHint, style: s(size: 8))),
    ],
  ));
  return doc.save();
}
