import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../fake/models.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart' show PaperSize, PrintTextSize;
import '../../strings.dart';
import '../../domain/upi.dart';
import '../billing/cart.dart';

/// WHAT is printed, with no drawing: one description used by the on-screen paper and by the PDF, so they can never differ.
/// An estimate shows only what the shop switched on (Shop profile > Show on estimate); a tax invoice is not affected by those switches.

class PrintText {
  const PrintText(this.text, {this.bold = false, this.id});
  final String text;
  final bool bold;

  /// Names a line for tests and for the on-screen paper (for example the date).
  final String? id;
}

class PrintItem {
  const PrintItem({required this.number, required this.name, required this.qty, required this.rate, required this.amount, required this.qtyTimesRate});
  final String number, name, qty, rate, amount, qtyTimesRate;
}

class TotalLine {
  const TotalLine(this.label, this.value, {this.bold = false, this.big = false, this.id});
  final String label, value;
  final bool bold, big;
  final String? id;
}

class PrintLayout {
  const PrintLayout({
    required this.estimate,
    required this.header,
    required this.title,
    required this.metaLeft,
    required this.metaRight,
    required this.tableHead,
    required this.items,
    required this.totals,
    required this.note,
    required this.paidInFull,
    required this.grandTotalPaise,
    this.upiData = '',
    this.upiLabel = '',
  });

  final bool estimate;

  /// The shop block at the top: the first line is the shop name. Empty when nothing of it is to be printed.
  final List<PrintText> header;
  final String title;
  final List<PrintText> metaLeft, metaRight;
  final List<String> tableHead; // number, item, quantity, rate, amount
  final List<PrintItem> items;
  final List<TotalLine> totals;
  final String note;

  /// Bills only: print "Paid in full" under the totals.
  final bool paidInFull;
  final int grandTotalPaise;

  /// A UPI payment link (for the QR code) and its caption: a bill that still has money due only.
  final String upiData, upiLabel;

  List<String> get allText => [
        for (final h in header) h.text,
        title,
        for (final m in metaLeft) m.text,
        for (final m in metaRight) m.text,
        ...tableHead,
        for (final i in items) ...[i.number, i.name, i.qty, i.rate, i.amount],
        for (final t in totals) ...[t.label, t.value],
        if (paidInFull) 'Paid in full',
        note,
      ];
}

String _pay(Strings l, PayMode m) => switch (m) { PayMode.cash => l.payCash, PayMode.upi => l.payUpi, PayMode.card => l.payCard, PayMode.credit => l.payCredit };

PrintLayout buildPrintLayout({required PrintDoc doc, required ShopProfile shop, required Strings l}) {
  final est = doc.mode == DocMode.estimation;
  final show = shop.estimate;
  final c = doc.calc;

  // ---- shop block
  final header = <PrintText>[
    if (!est || show.shopName) PrintText(shop.name.toUpperCase(), bold: true, id: 'shopName'),
    if ((!est || show.address) && shop.address.trim().isNotEmpty) PrintText(shop.address),
    if (!est || show.gstin || show.phone)
      if (!est)
        PrintText('${l.rcGstin}: ${shop.gstin}   Ph: ${shop.phone}')
      else ...[
        if (show.gstin) PrintText('${l.rcGstin}: ${shop.gstin}'),
        if (show.phone) PrintText('Ph: ${shop.phone}'),
      ],
  ];

  // ---- who and when
  final left = <PrintText>[
    PrintText('${l.rcCustomer}: ${doc.customer}', bold: true),
    if (!est) PrintText('${l.rcPaidBy}: ${_pay(l, doc.pay)}'),
  ];
  final right = <PrintText>[
    if (!est) PrintText('${l.rcBillNo}: ${doc.number}', bold: true) else if (show.number) PrintText('${l.rcEstNo}: ${doc.number}', bold: true),
    PrintText('${l.rcDate}: ${formatDate(doc.date)}', id: 'paperDate'),
    if (doc.editedOn != null) PrintText('${l.rcEditedOn}: ${formatDate(doc.editedOn!)}', id: 'paperEdited'),
  ];

  // ---- items
  final items = [
    for (var i = 0; i < doc.lines.length; i++)
      PrintItem(
        number: '${i + 1}',
        name: doc.lines[i].product.name,
        qty: '${formatQty(doc.lines[i].qtyMilli)} ${doc.lines[i].product.unit}',
        rate: formatPaise(doc.lines[i].rate),
        amount: formatPaise(c.lines[i].total),
        qtyTimesRate: '${formatQty(doc.lines[i].qtyMilli)} x ${formatPaise(doc.lines[i].rate)}',
      ),
  ];

  // ---- totals
  String signed(int v) => '${v >= 0 ? '+' : ''}${formatPaise(v)}';
  final taxLines = <TotalLine>[
    TotalLine(l.rcTaxable, formatPaise(c.taxable)),
    TotalLine('CGST', formatPaise(c.cgst)),
    TotalLine('SGST', formatPaise(c.sgst)),
    TotalLine(l.rcRoundOff, signed(c.roundOff)),
  ];
  // the whole-bill discount is always shown (the customer sees what was taken off)
  final before = c.lines.fold<int>(0, (a, x) => a + x.total + x.extraShare);
  final discountLines = <TotalLine>[
    if (c.extraDiscount > 0) ...[
      TotalLine(l.rcAmountBefore, formatPaise(before)),
      TotalLine(doc.extraDiscountBp > 0 ? l.rcBillDiscountPct(_pct(doc.extraDiscountBp)) : l.rcBillDiscount, '-${formatPaise(c.extraDiscount)}', id: 'paperDiscount'),
    ],
  ];
  final totals = <TotalLine>[
    ...discountLines,
    if (!est || show.taxLines) ...taxLines,
    TotalLine(l.rcGrandTotal, '₹ ${formatPaise(c.grandTotal)}', bold: true, big: true, id: 'paperTotal'),
  ];
  var paidInFull = false;
  if (!est && doc.receivedPaise != null) {
    final shown = doc.receivedPaise! > c.grandTotal ? c.grandTotal : doc.receivedPaise!;
    totals.add(TotalLine(doc.pay == PayMode.credit ? l.paidNow : '${l.rcReceived} (${_pay(l, doc.pay)})', formatPaise(shown), id: 'paperReceived'));
    if (doc.balancePaise > 0) {
      totals.add(TotalLine(l.rcBalanceDue, '₹ ${formatPaise(doc.balancePaise)}', bold: true, id: 'paperBalance'));
    } else {
      paidInFull = true;
    }
    if (doc.advanceKeptPaise > 0) totals.add(TotalLine(l.rcAdvance, formatPaise(doc.advanceKeptPaise)));
    if (doc.newBalancePaise != null && doc.newBalancePaise! > 0 && doc.balancePaise > 0) totals.add(TotalLine(l.rcAccountBalance, '₹ ${formatPaise(doc.newBalancePaise!)}', id: 'paperNewBalance'));
    if (doc.changePaise > 0) totals.add(TotalLine(l.rcChange, formatPaise(doc.changePaise)));
  }

  // the QR code asks for exactly what is still due (never for a paid bill, so nobody pays twice)
  final upi = est ? null : upiPayUri(upiId: shop.upiId, payeeName: shop.name, amountPaise: doc.balancePaise, note: doc.number, openAmount: shop.qrOnEveryBill);

  return PrintLayout(
    estimate: est,
    header: header,
    title: est ? l.rcEstimate : l.rcTaxInvoice,
    metaLeft: left,
    metaRight: right,
    tableHead: ['#', l.rcItem, l.rcQty, l.rcRate, l.rcAmount],
    items: items,
    totals: totals,
    note: est ? l.rcEstimateNote : (shop.billFooter.trim().isEmpty ? l.rcThanks : shop.billFooter.trim()),
    paidInFull: paidInFull,
    grandTotalPaise: c.grandTotal,
    upiData: upi ?? '',
    upiLabel: upi == null ? '' : (doc.balancePaise > 0 ? l.upiScanToPay('₹ ${formatPaise(doc.balancePaise)}') : l.upiPayAnytime),
  );
}

// ------------------------------------------------------------------ paper and text sizes (shared by screen and PDF)

/// Paper width in points (1 pt = 1/72 inch). Roll paper: 80 mm and 58 mm rolls.
double paperWidthPt(PaperSize p) => switch (p) { PaperSize.a4 => 595.0, PaperSize.a5 => 420.0, PaperSize.mm80 => 227.0, PaperSize.mm58 => 164.0 };

/// Roll paper (thermal) has no fixed height: the page is as long as the printout.
bool isRoll(PaperSize p) => p == PaperSize.mm80 || p == PaperSize.mm58;

/// Margins around the printout in points.
double paperMarginPt(PaperSize p) => switch (p) { PaperSize.a4 => 24.0, PaperSize.a5 => 20.0, PaperSize.mm80 => 8.0, PaperSize.mm58 => 6.0 };

/// Font sizes in points for each "Print text size" choice. Small is the default: item rows about 9.5 pt, title 12 pt, total 11 pt.
class PrintMetrics {
  const PrintMetrics({required this.row, required this.title, required this.total, required this.shop});
  final double row, title, total, shop;

  static const smaller = PrintMetrics(row: 8.0, title: 10.5, total: 9.5, shop: 10.5);
  static const small = PrintMetrics(row: 9.5, title: 12.0, total: 11.0, shop: 12.0);
  static const normal = PrintMetrics(row: 11.0, title: 14.0, total: 13.0, shop: 14.0);

  static PrintMetrics of(PrintTextSize s) => switch (s) { PrintTextSize.smaller => smaller, PrintTextSize.small => small, PrintTextSize.normal => normal };
}

/// 500 -> 5, 1250 -> 12.5
String _pct(int bp) => bp % 100 == 0 ? '${bp ~/ 100}' : (bp / 100).toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
