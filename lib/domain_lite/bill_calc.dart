/// Bill maths for the cart (see lib/domain/bill_math.dart for the rules and the plain-line version the database uses).
library;

import '../core/money.dart';
import '../domain/bill_math.dart';
import '../domain/models.dart';

export '../domain/bill_math.dart' show LineCalc, BillCalc;

CalcLineIn _in(CartLine l) => CalcLineIn(rate: l.rate, qtyMilli: l.qtyMilli, gstBp: l.product.gstBp, discountBp: l.discountBp);

LineCalc calcLine(CartLine l, {required bool inclusive}) => calcLineIn(_in(l), inclusive: inclusive);

BillCalc calcBill(List<CartLine> lines, {bool inclusive = true, bool interState = false, bool roundOff = true, int extraDiscountPaise = 0, int extraDiscountBp = 0}) =>
    calcBillIn([for (final l in lines) _in(l)], inclusive: inclusive, interState: interState, roundOff: roundOff, extraDiscountPaise: extraDiscountPaise, extraDiscountBp: extraDiscountBp);

/// What the shop makes on this bill: the value before tax (after every discount) minus what the goods cost. Only for the owner's eyes:
/// it is never printed or put on a bill.
int billProfit(List<CartLine> lines, BillCalc calc) {
  var profit = 0;
  for (var i = 0; i < lines.length && i < calc.lines.length; i++) {
    profit += calc.lines[i].taxable - lineAmount(lines[i].product.costPaise, lines[i].qtyMilli);
  }
  return profit;
}
