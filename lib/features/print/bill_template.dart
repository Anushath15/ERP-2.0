import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../core/number_words.dart';
import '../../fake/models.dart';
import '../../fake/shop_profile.dart';
import '../../strings.dart';
import '../billing/cart.dart';

/// WHAT the A4 / A5 bill and estimate print, in the shop's own template (Senthil enterprises bill templet.docx): the shop block, who
/// and when, the items (Sl.No, Goods, MRP, HSN Code, Qty, Disc %, Rate, GST%, Total), the totals, the GST summary by rate, the amount
/// in words, the bank details and the signature. No drawing here: the on-screen paper and the PDF both draw this, so they agree.
///
/// An ESTIMATE has the same table and totals but NO shop details at all (no shop block, no bank details, no signature).
class TemplateRow {
  const TemplateRow({required this.sl, required this.goods, required this.mrp, required this.hsn, required this.qty, required this.disc, required this.rate, required this.gst, required this.total});
  final String sl, goods, mrp, hsn, qty, disc, rate, gst, total;
  List<String> get cells => [sl, goods, mrp, hsn, qty, disc, rate, gst, total];
}

class TemplateGstRow {
  const TemplateGstRow({required this.salesAmt, required this.pct, required this.cgst, required this.sgst, required this.igst, required this.net});
  final String salesAmt, pct, cgst, sgst, igst, net;
}

class BillTemplate {
  const BillTemplate({
    required this.estimate,
    required this.shopLeft,
    required this.shopRight,
    required this.to,
    required this.toLines,
    required this.metaLines,
    required this.status,
    required this.title,
    required this.heading,
    required this.showGst,
    required this.head,
    required this.rows,
    required this.totalQty,
    required this.totalAmount,
    required this.discountLabel,
    required this.discountValue,
    required this.beforeRound,
    required this.roundOff,
    required this.net,
    required this.gstHead,
    required this.gstRows,
    required this.words,
    required this.bankLines,
    required this.forShop,
    required this.signatory,
    required this.note,
    required this.totalLabel,
    required this.roundLabel,
    required this.netLabel,
    required this.amountLabel,
    required this.pctLabel,
    required this.toLabel,
    required this.paidLabel,
    required this.paidValue,
    required this.balanceLabel,
    required this.balanceValue,
  });

  final bool estimate;

  /// Left of the shop block: the shop name (first line), the address lines, the e-mail. Right: GST number and phone. Both empty for an estimate.
  final List<String> shopLeft, shopRight;
  final String to;

  /// Under the customer's name: phone, and the GST number when the customer has one.
  final List<String> toLines;
  final List<String> metaLines; // "Bill No   738", "Date   14-10-2026"
  final String status; // CREDIT BILL / PART PAID / PAID (a bill only)

  /// The heading in the middle of the first row: ESTIMATE on an estimate (underlined), nothing on a bill.
  final String title;

  /// TAX INVOICE, centred and underlined above the shop block of a bill (nothing on an estimate).
  final String heading;

  /// The GST summary by rate: on a bill only (an estimate does not carry it).
  final bool showGst;
  final List<String> head; // the nine column heads
  final List<TemplateRow> rows;
  final String totalQty, totalAmount;

  /// The whole-bill discount ("Discount (5%)"), empty when there is none.
  final String discountLabel, discountValue;
  final String beforeRound, roundOff, net;
  final List<String> gstHead; // Sales Amt, CGST, SGST, IGST, Net Amt
  final List<TemplateGstRow> gstRows;
  final String words;
  final List<String> bankLines;
  final String forShop, signatory;
  final String note;

  /// The words of the totals block, the GST summary and the "To" line.
  final String totalLabel, roundLabel, netLabel, amountLabel, pctLabel, toLabel;

  /// A bill only: the money received (with how it was paid) and what is left to pay (added to the customer's credit). Empty when not shown.
  final String paidLabel, paidValue, balanceLabel, balanceValue;

  bool get showShop => shopLeft.isNotEmpty;

  /// The columns of the items table that are printed (an estimate has no GST% column).
  List<int> get cols => estimate ? const [0, 1, 2, 3, 4, 5, 6, 8] : const [0, 1, 2, 3, 4, 5, 6, 7, 8];

  /// Everything printed, for tests.
  List<String> get allText => [
        ...shopLeft,
        ...shopRight,
        to,
        ...toLines,
        ...metaLines,
        status,
        title,
        heading,
        ...head,
        for (final r in rows) ...r.cells,
        totalQty,
        totalAmount,
        discountLabel,
        discountValue,
        beforeRound,
        roundOff,
        net,
        if (showGst) ...gstHead,
        if (showGst) for (final g in gstRows) ...[g.salesAmt, g.pct, g.cgst, g.sgst, g.igst, g.net],
        paidLabel,
        paidValue,
        balanceLabel,
        balanceValue,
        words,
        ...bankLines,
        forShop,
        signatory,
        note,
      ];
}

String _pct(int bp) => bp % 100 == 0 ? '${bp ~/ 100}' : (bp / 100).toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

/// The unit rate WITHOUT GST with three decimals (11.441), as on the template.
String _rateEx(int ratePaise, int gstBp, bool inclusive) {
  final ex = inclusive ? ratePaise * 10000 / (10000 + gstBp) : ratePaise.toDouble();
  return (ex / 100).toStringAsFixed(3);
}

BillTemplate buildBillTemplate({required PrintDoc doc, required ShopProfile shop, required Strings l}) {
  final est = doc.mode == DocMode.estimation;
  final c = doc.calc;
  final inclusive = shop.pricesIncludeGst;
  String m(int p) => formatPaise(p);

  final rows = <TemplateRow>[];
  var qtyTotal = 0, amountTotal = 0;
  for (var i = 0; i < doc.lines.length; i++) {
    final line = doc.lines[i];
    final p = line.product;
    final lc = c.lines[i];
    final shown = lc.total + lc.extraShare; // before the whole-bill discount: that one has its own row
    qtyTotal += line.qtyMilli;
    amountTotal += shown;
    rows.add(TemplateRow(
      sl: '${i + 1}',
      goods: p.brand.trim().isEmpty ? p.name : '(${p.brand.trim()})${p.name}',
      mrp: p.mrpPaise > 0 ? m(p.mrpPaise) : '',
      hsn: p.hsn,
      qty: formatQty(line.qtyMilli),
      disc: line.discountBp > 0 ? _pct(line.discountBp) : '0',
      rate: _rateEx(line.rate, p.gstBp, inclusive),
      gst: _pct(p.gstBp),
      total: m(shown),
    ));
  }

  // the GST summary: one row for each rate, CGST and SGST half and half (as the bill maths splits them)
  final groups = <int, ({int taxable, int cgst, int sgst, int net})>{};
  for (var i = 0; i < doc.lines.length; i++) {
    final gst = doc.lines[i].product.gstBp;
    final lc = c.lines[i];
    final half = divRound(lc.tax, 2);
    final g = groups[gst] ?? (taxable: 0, cgst: 0, sgst: 0, net: 0);
    groups[gst] = (taxable: g.taxable + lc.taxable, cgst: g.cgst + half, sgst: g.sgst + (lc.tax - half), net: g.net + lc.total);
  }
  final rates = groups.keys.toList()..sort();
  final gstRows = [
    for (final r in rates)
      TemplateGstRow(salesAmt: m(groups[r]!.taxable), pct: (r / 200).toStringAsFixed(2), cgst: m(groups[r]!.cgst), sgst: m(groups[r]!.sgst), igst: '', net: m(groups[r]!.net)),
  ];

  final beforeRound = c.grandTotal - c.roundOff;
  // the bank details are free text: the account number and the IFSC code go up beside the GST number, the rest stays at the bottom
  final bankParts = [for (final b in shop.bankDetails.split(RegExp(r'[\r\n,]+'))) if (b.trim().isNotEmpty) b.trim()];
  final accountRx = RegExp(r'^(a\s*[/\\]?\s*c|acc(ount)?)\b(?!\s*name)', caseSensitive: false);
  final ifscRx = RegExp(r'ifsc', caseSensitive: false);
  final bankUp = [for (final b in bankParts) if (accountRx.hasMatch(b) || ifscRx.hasMatch(b)) b];
  final bankDown = [for (final b in bankParts) if (!(accountRx.hasMatch(b) || ifscRx.hasMatch(b))) b];
  final shopLeft = est
      ? const <String>[]
      : [
          shop.name.toUpperCase(),
          for (final a in shop.address.split(RegExp(r'[\r\n]+'))) if (a.trim().isNotEmpty) a.trim().toUpperCase(),
          if (shop.phone.trim().isNotEmpty) '${l.tplPhone}  ${shop.phone.trim()}',
          if (shop.email.trim().isNotEmpty) shop.email.trim(),
        ];
  final shopRight = est
      ? const <String>[]
      : [
          if (shop.gstin.trim().isNotEmpty) '${l.tplGstNo}  ${shop.gstin.trim()}',
          ...bankUp,
        ];
  final status = est ? '' : (doc.balancePaise > 0 ? ((doc.receivedPaise ?? 0) <= 0 ? l.tplCreditBill : l.tplPartPaid) : l.tplPaid);

  return BillTemplate(
    estimate: est,
    shopLeft: shopLeft,
    shopRight: shopRight,
    to: doc.customer,
    toLines: [
      if (doc.customerPhone.trim().isNotEmpty) '${l.tplPhone}  ${doc.customerPhone.trim()}',
      if (!est && doc.customerGstin.trim().isNotEmpty) '${l.tplGstNo}  ${doc.customerGstin.trim()}',
    ],
    metaLines: [
      '${est ? l.tplEstNo : l.tplBillNo}   ${doc.number}',
      '${l.tplDate}   ${formatDate(doc.date)}',
      if (est && doc.editedOn != null) '${l.rcEditedOn}   ${formatDate(doc.editedOn!)}',
    ],
    status: status,
    title: est ? l.tplEstimate : '',
    heading: est ? '' : l.tplTaxInvoice,
    showGst: !est,
    head: [l.tplSl, l.tplGoods, l.tplMrp, l.tplHsn, l.tplQty, l.tplDisc, l.tplRate, l.tplGst, l.tplTotal],
    rows: rows,
    totalQty: formatQty(qtyTotal),
    totalAmount: m(amountTotal),
    discountLabel: c.extraDiscount > 0 ? (doc.extraDiscountBp > 0 ? l.rcBillDiscountPct(_pct(doc.extraDiscountBp)) : l.rcBillDiscount) : '',
    discountValue: c.extraDiscount > 0 ? '-${m(c.extraDiscount)}' : '',
    beforeRound: m(beforeRound),
    roundOff: m(c.roundOff),
    net: m(c.grandTotal),
    gstHead: [l.tplSalesAmt, l.tplCgst, l.tplSgst, l.tplIgst, l.tplNetAmt],
    gstRows: gstRows,
    words: rupeesInWords(c.grandTotal),
    bankLines: est ? const [] : bankDown,
    forShop: est ? '' : l.tplFor(shop.name.toUpperCase()),
    signatory: est ? '' : l.tplSignatory,
    note: est ? '' : (shop.billFooter.trim().isEmpty ? '' : shop.billFooter.trim()),
    totalLabel: l.tplTotal,
    roundLabel: l.tplRoundOff,
    netLabel: l.tplNet,
    amountLabel: l.tplAmount,
    pctLabel: l.tplPct,
    toLabel: l.tplTo,
    paidLabel: !est && doc.receivedPaise != null ? (doc.pay == PayMode.credit ? l.paidNow : '${l.rcReceived} (${_pay(l, doc.pay)})') : '',
    paidValue: !est && doc.receivedPaise != null ? m(doc.receivedPaise! > c.grandTotal ? c.grandTotal : doc.receivedPaise!) : '',
    balanceLabel: !est && doc.receivedPaise != null && doc.balancePaise > 0 ? l.rcBalanceDue : '',
    balanceValue: !est && doc.receivedPaise != null && doc.balancePaise > 0 ? '₹ ${m(doc.balancePaise)}' : '',
  );
}

String _pay(Strings l, PayMode m) => switch (m) { PayMode.cash => l.payCash, PayMode.upi => l.payUpi, PayMode.card => l.payCard, PayMode.credit => l.payCredit };
