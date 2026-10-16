/// Bill maths (integer paise only), the rules written in docs/data-model.md. Pure Dart.
library;

import '../core/money.dart';

/// One line as the maths sees it.
class CalcLineIn {
  const CalcLineIn({required this.rate, required this.qtyMilli, required this.gstBp, this.discountBp = 0});
  final int rate, qtyMilli, gstBp, discountBp;
}

class LineCalc {
  const LineCalc({required this.gross, required this.discount, required this.taxable, required this.tax, required this.total});
  final int gross, discount, taxable, tax, total;
}

class BillCalc {
  const BillCalc({required this.lines, required this.taxable, required this.cgst, required this.sgst, required this.igst, required this.discount, required this.roundOff, required this.grandTotal, required this.itemCount});
  final List<LineCalc> lines;
  final int taxable, cgst, sgst, igst, discount, roundOff, grandTotal, itemCount;
  int get tax => cgst + sgst + igst;
}

LineCalc calcLineIn(CalcLineIn l, {required bool inclusive}) {
  final gross = lineAmount(l.rate, l.qtyMilli);
  final disc = divRound(gross * l.discountBp, 10000);
  final net = gross - disc;
  final rate = l.gstBp;
  if (inclusive) {
    final taxable = divRound(net * 10000, 10000 + rate);
    return LineCalc(gross: gross, discount: disc, taxable: taxable, tax: net - taxable, total: net);
  }
  final tax = divRound(net * rate, 10000);
  return LineCalc(gross: gross, discount: disc, taxable: net, tax: tax, total: net + tax);
}

/// [roundOff] true: the grand total is rounded to the nearest rupee (default). false: the exact total to the paisa.
BillCalc calcBillIn(List<CalcLineIn> lines, {bool inclusive = true, bool interState = false, bool roundOff = true}) {
  var taxable = 0, cgst = 0, sgst = 0, igst = 0, disc = 0, sum = 0;
  final out = <LineCalc>[];
  for (final l in lines) {
    final c = calcLineIn(l, inclusive: inclusive);
    out.add(c);
    taxable += c.taxable;
    disc += c.discount;
    sum += c.total;
    if (interState) {
      igst += c.tax;
    } else {
      final half = divRound(c.tax, 2);
      cgst += half;
      sgst += c.tax - half; // the two halves always add up to the tax exactly
    }
  }
  final grand = roundOff ? ((sum + 50) ~/ 100) * 100 : sum;
  return BillCalc(lines: out, taxable: taxable, cgst: cgst, sgst: sgst, igst: igst, discount: disc, roundOff: grand - sum, grandTotal: grand, itemCount: lines.length);
}
