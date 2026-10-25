import 'package:erp2/domain/bill_math.dart';
import 'package:flutter_test/flutter_test.dart';

// What these tests prove: GST on a bill matches what a person gets with a calculator, for the cases a hardware shop meets every day (rates 5/12/18/28 %,
// prices with or without GST, a discount, mixed rates on one bill, a bill discount), and that CGST + SGST is always exactly the GST.
void main() {
  test('price WITH GST: Rs 1000 at 18 % -> taxable 847.46, GST 152.54 (76.27 + 76.27), total 1000', () {
    final c = calcBillIn([const CalcLineIn(rate: 100000, qtyMilli: 1000, gstBp: 1800)], inclusive: true, roundOff: false);
    expect((c.taxable, c.tax, c.cgst, c.sgst, c.grandTotal), (84746, 15254, 7627, 7627, 100000));
  });

  test('price WITHOUT GST: Rs 1000 at 18 % -> taxable 1000, GST 180 (90 + 90), total 1180', () {
    final c = calcBillIn([const CalcLineIn(rate: 100000, qtyMilli: 1000, gstBp: 1800)], inclusive: false, roundOff: false);
    expect((c.taxable, c.tax, c.cgst, c.sgst, c.grandTotal), (100000, 18000, 9000, 9000, 118000));
  });

  test('quantity 2.5 of a Rs 120 item at 12 % without GST: 300 + 36 = 336', () {
    final c = calcBillIn([const CalcLineIn(rate: 12000, qtyMilli: 2500, gstBp: 1200)], inclusive: false, roundOff: false);
    expect((c.taxable, c.tax, c.grandTotal), (30000, 3600, 33600));
  });

  test('a 10 % item discount comes off before the GST: Rs 500 less 10 % = 450, +18 % = 531', () {
    final c = calcBillIn([const CalcLineIn(rate: 50000, qtyMilli: 1000, gstBp: 1800, discountBp: 1000)], inclusive: false, roundOff: false);
    expect((c.discount, c.taxable, c.tax, c.grandTotal), (5000, 45000, 8100, 53100));
  });

  test('mixed rates on one bill: the GST of each rate is added, nothing is mixed up', () {
    // 5 % item Rs 200 + 18 % item Rs 300 + 28 % item Rs 100, prices without GST: GST 10 + 54 + 28 = 92
    final c = calcBillIn(const [
      CalcLineIn(rate: 20000, qtyMilli: 1000, gstBp: 500),
      CalcLineIn(rate: 30000, qtyMilli: 1000, gstBp: 1800),
      CalcLineIn(rate: 10000, qtyMilli: 1000, gstBp: 2800),
    ], inclusive: false, roundOff: false);
    expect((c.taxable, c.tax, c.cgst + c.sgst, c.grandTotal), (60000, 9200, 9200, 69200));
    expect(c.lines.map((l) => l.tax), [1000, 5400, 2800]);
  });

  test('a discount on the whole bill lowers the GST too: Rs 1180 with GST, Rs 118 off -> Rs 1062 (taxable 900, GST 162)', () {
    final c = calcBillIn([const CalcLineIn(rate: 118000, qtyMilli: 1000, gstBp: 1800)], inclusive: true, roundOff: false, extraDiscountPaise: 11800);
    expect((c.taxable, c.tax, c.grandTotal), (90000, 16200, 106200));
  });

  test('round-off: Rs 1000.40 pays Rs 1000 (-0.40); Rs 1000.50 pays Rs 1001 (+0.50)', () {
    final a = calcBillIn([const CalcLineIn(rate: 100040, qtyMilli: 1000, gstBp: 0)]);
    expect((a.grandTotal, a.roundOff), (100000, -40));
    final b = calcBillIn([const CalcLineIn(rate: 100050, qtyMilli: 1000, gstBp: 0)]);
    expect((b.grandTotal, b.roundOff), (100100, 50));
  });

  test('an odd paisa of GST goes to SGST, so CGST + SGST is always the GST', () {
    final c = calcBillIn([const CalcLineIn(rate: 101, qtyMilli: 1000, gstBp: 1800)], inclusive: false, roundOff: false); // GST 18.18 paise -> 18
    expect(c.cgst + c.sgst, c.tax);
    final d = calcBillIn([const CalcLineIn(rate: 1000, qtyMilli: 1000, gstBp: 500)], inclusive: false, roundOff: false); // 50 paise GST
    expect((d.cgst, d.sgst), (25, 25));
  });

  test('the other state: all of the GST is IGST, no CGST or SGST', () {
    final c = calcBillIn([const CalcLineIn(rate: 100000, qtyMilli: 1000, gstBp: 1800)], inclusive: false, interState: true, roundOff: false);
    expect((c.igst, c.cgst, c.sgst), (18000, 0, 0));
  });
}
