/// Bill maths for the cart (see lib/domain/bill_math.dart for the rules and the plain-line version the database uses).
library;

import '../domain/bill_math.dart';
import '../domain/models.dart';

export '../domain/bill_math.dart' show LineCalc, BillCalc;

CalcLineIn _in(CartLine l) => CalcLineIn(rate: l.rate, qtyMilli: l.qtyMilli, gstBp: l.product.gstBp, discountBp: l.discountBp);

LineCalc calcLine(CartLine l, {required bool inclusive}) => calcLineIn(_in(l), inclusive: inclusive);

BillCalc calcBill(List<CartLine> lines, {bool inclusive = true, bool interState = false, bool roundOff = true}) =>
    calcBillIn([for (final l in lines) _in(l)], inclusive: inclusive, interState: interState, roundOff: roundOff);
