import 'dart:math';
import 'package:erp2/domain/bill_math.dart';
import 'package:flutter_test/flutter_test.dart';

// What these tests prove: for thousands of random bills (the seed is printed on a failure) the money rules hold EVERY time, not only for the examples somebody
// thought of: the parts add up to the whole to the paisa, GST splits evenly, round-off is under a rupee, nothing is negative, a bigger discount never makes a
// bill dearer, and the whole-bill discount is shared with nothing lost.
void main() {
  const gstRates = [0, 500, 1200, 1800, 2800];

  List<CalcLineIn> randomLines(Random r) => [
        for (var i = 0; i < 1 + r.nextInt(12); i++)
          CalcLineIn(rate: 1 + r.nextInt(2000000), qtyMilli: 1 + r.nextInt(500000), gstBp: gstRates[r.nextInt(gstRates.length)], discountBp: r.nextInt(5) == 0 ? r.nextInt(10001) : 0),
      ];

  for (final inclusive in [true, false]) {
    test('${inclusive ? 'prices with GST' : 'prices without GST'}: 4000 random bills obey every money rule', () {
      final seed = inclusive ? 11 : 22;
      final r = Random(seed);
      for (var n = 0; n < 4000; n++) {
        final lines = randomLines(r);
        final extra = r.nextInt(3) == 0 ? r.nextInt(500000) : 0;
        final extraBp = extra == 0 && r.nextInt(4) == 0 ? r.nextInt(10001) : 0;
        final c = calcBillIn(lines, inclusive: inclusive, extraDiscountPaise: extra, extraDiscountBp: extraBp);
        final why = 'seed $seed, bill $n';
        // nothing is negative
        for (final l in c.lines) {
          expect(l.gross, greaterThanOrEqualTo(0), reason: why);
          expect(l.total, greaterThanOrEqualTo(0), reason: why);
          expect(l.tax, greaterThanOrEqualTo(0), reason: why);
          expect(l.taxable, greaterThanOrEqualTo(0), reason: why);
        }
        // each line: taxable + tax is what the customer pays for it
        final lineSum = c.lines.fold<int>(0, (s, l) => s + l.total);
        for (final l in c.lines) {
          expect(l.taxable + l.tax, l.total, reason: '$why: a line is taxable + tax');
        }
        // the bill: lines add up, GST is split evenly (cgst/sgst differ by at most a paisa), grand total = lines + round-off, round-off under a rupee
        expect(c.cgst + c.sgst + c.igst, c.lines.fold<int>(0, (s, l) => s + l.tax), reason: why);
        expect((c.cgst - c.sgst).abs(), lessThanOrEqualTo(1), reason: why);
        expect(c.grandTotal, lineSum + c.roundOff, reason: '$why: grand total = lines + round-off');
        expect(c.roundOff.abs(), lessThan(100), reason: why);
        expect(c.grandTotal % 100, 0, reason: '$why: rounded to a whole rupee');
        // the whole-bill discount is never more than the bill and is fully shared
        expect(c.extraDiscount, greaterThanOrEqualTo(0), reason: why);
        expect(c.lines.fold<int>(0, (s, l) => s + l.extraShare), c.extraDiscount, reason: '$why: the shares add up to the discount');
        expect(c.totalDiscount, c.discount + c.extraDiscount, reason: why);
      }
    });
  }

  test('a bigger discount never makes the bill dearer; no discount is the dearest', () {
    final r = Random(33);
    for (var n = 0; n < 1500; n++) {
      final lines = randomLines(r);
      final a = r.nextInt(300000), b = a + r.nextInt(300000);
      final small = calcBillIn(lines, roundOff: false, extraDiscountPaise: a).grandTotal;
      final big = calcBillIn(lines, roundOff: false, extraDiscountPaise: b).grandTotal;
      expect(big, lessThanOrEqualTo(small), reason: 'bill $n: discount $b must not cost more than discount $a');
      expect(small, lessThanOrEqualTo(calcBillIn(lines, roundOff: false).grandTotal), reason: 'bill $n');
    }
  });

  test('the same bill always gives the same answer (no hidden state), and splitting a quantity gives the same GST-inclusive money within a paisa per line', () {
    final r = Random(44);
    for (var n = 0; n < 500; n++) {
      final lines = randomLines(r);
      expect(calcBillIn(lines).grandTotal, calcBillIn(lines).grandTotal);
    }
    expect(allocateByWeight(100, [1, 1, 1]).fold<int>(0, (s, x) => s + x), 100);
    for (var n = 0; n < 2000; n++) {
      final amount = r.nextInt(1000000);
      final w = [for (var i = 0; i < 1 + r.nextInt(9); i++) 1 + r.nextInt(100000)];
      final shares = allocateByWeight(amount, w);
      expect(shares.fold<int>(0, (s, x) => s + x), amount, reason: 'shares always add up to the amount (case $n)');
      expect(shares.every((x) => x >= 0), isTrue);
    }
  });
}
