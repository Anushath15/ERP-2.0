/// Bill maths (integer paise only), the rules written in docs/data-model.md. Pure Dart.
library;

import '../core/money.dart';

/// One line as the maths sees it.
class CalcLineIn {
  const CalcLineIn({required this.rate, required this.qtyMilli, required this.gstBp, this.discountBp = 0});
  final int rate, qtyMilli, gstBp, discountBp;
}

class LineCalc {
  const LineCalc({required this.gross, required this.discount, required this.taxable, required this.tax, required this.total, this.extraShare = 0});
  final int gross, discount, taxable, tax, total;

  /// This line's share of the whole-bill discount (already taken off [total], [taxable] and [tax]).
  final int extraShare;
}

class BillCalc {
  const BillCalc({required this.lines, required this.taxable, required this.cgst, required this.sgst, required this.igst, required this.discount, required this.roundOff, required this.grandTotal, required this.itemCount, this.extraDiscount = 0});
  final List<LineCalc> lines;
  final int taxable, cgst, sgst, igst, discount, roundOff, grandTotal, itemCount;

  /// The discount given on the whole bill (typed as an amount or a percent), on top of the item discounts in [discount].
  final int extraDiscount;

  /// All the discount the customer got.
  int get totalDiscount => discount + extraDiscount;
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

/// Shares [amount] among the weights in proportion, in whole paise, the last paisa going to the biggest remainders (so the shares
/// always add up to exactly [amount]).
List<int> allocateByWeight(int amount, List<int> weights) {
  final total = weights.fold<int>(0, (s, w) => s + w);
  if (amount <= 0 || total <= 0) return List<int>.filled(weights.length, 0);
  final shares = [for (final w in weights) amount * w ~/ total];
  var left = amount - shares.fold<int>(0, (s, x) => s + x);
  final order = List<int>.generate(weights.length, (i) => i)..sort((a, b) {
      final ra = amount * weights[a] % total, rb = amount * weights[b] % total;
      return rb != ra ? rb.compareTo(ra) : a.compareTo(b);
    });
  for (var k = 0; left > 0 && k < order.length; k++, left--) {
    shares[order[k]]++;
  }
  return shares;
}

/// [roundOff] true: the grand total is rounded to the nearest rupee (default). false: the exact total to the paisa.
/// [extraDiscountBp] (percent in basis points, used when above zero) or [extraDiscountPaise]: a discount on the WHOLE bill, taken off
/// what the customer pays; it is shared among the items in proportion, and each item's GST comes down with it. Never more than the bill.
BillCalc calcBillIn(List<CalcLineIn> lines, {bool inclusive = true, bool interState = false, bool roundOff = true, int extraDiscountPaise = 0, int extraDiscountBp = 0}) {
  var taxable = 0, cgst = 0, sgst = 0, igst = 0, disc = 0, sum = 0;
  final out = <LineCalc>[];
  final base = [for (final l in lines) calcLineIn(l, inclusive: inclusive)];
  final before = base.fold<int>(0, (s, c) => s + c.total);
  var extra = extraDiscountBp > 0 ? divRound(before * (extraDiscountBp > 10000 ? 10000 : extraDiscountBp), 10000) : extraDiscountPaise;
  if (extra < 0) extra = 0;
  if (extra > before) extra = before;
  final shares = allocateByWeight(extra, [for (final c in base) c.total]);
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    var c = base[i];
    if (shares[i] > 0) {
      final nt = c.total - shares[i];
      final tx = divRound(nt * 10000, 10000 + l.gstBp);
      c = LineCalc(gross: c.gross, discount: c.discount, taxable: tx, tax: nt - tx, total: nt, extraShare: shares[i]);
    }
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
  return BillCalc(lines: out, taxable: taxable, cgst: cgst, sgst: sgst, igst: igst, discount: disc, roundOff: grand - sum, grandTotal: grand, itemCount: lines.length, extraDiscount: extra);
}
