import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/core/money.dart';
import 'package:erp2/domain_lite/bill_calc.dart';
import 'package:erp2/fake/models.dart';

Product p(int price, int gstBp) => Product(id: 'x', name: 'x', category: 'c', unit: 'pcs', pricePaise: price, costPaise: 0, stockMilli: 1000, gstBp: gstBp, barcode: '');

void main() {
  test('Indian digit grouping', () {
    expect(formatPaise(0), '0.00');
    expect(formatPaise(99), '0.99');
    expect(formatPaise(123456), '1,234.56');
    expect(formatPaise(123456789), '12,34,567.89');
    expect(formatPaise(-100050), '-1,000.50');
    expect(formatPaise(10000000000), '10,00,00,000.00');
  });

  test('quantities in thousandths print without trailing zeros', () {
    expect(formatQty(1000), '1');
    expect(formatQty(25500), '25.5');
    expect(formatQty(250), '0.25');
    expect(formatQty(1001), '1.001');
  });

  test('line amount rounds half up to a paisa, once', () {
    expect(lineAmount(1000, 1500), 1500); // 10.00 x 1.5
    expect(lineAmount(333, 500), 167); // 3.33 x 0.5 = 1.665 -> 1.67
    expect(lineAmount(1, 500), 1); // 0.5 paise rounds up
    expect(lineAmount(1, 499), 0);
  });

  test('inclusive GST: tax plus taxable equals the price at every slab', () {
    for (final bp in [0, 500, 1200, 1800, 2800]) {
      for (final price in [1, 99, 100, 101, 999, 12345, 999999]) {
        final c = calcLine(CartLine(product: p(price, bp), qtyMilli: 1000), inclusive: true);
        expect(c.taxable + c.tax, c.total, reason: 'bp=$bp price=$price');
        expect(c.total, price);
      }
    }
  });

  test('exclusive GST adds the tax on top', () {
    final c = calcLine(CartLine(product: p(10000, 1800), qtyMilli: 1000), inclusive: false);
    expect(c.taxable, 10000);
    expect(c.tax, 1800);
    expect(c.total, 11800);
  });

  test('CGST and SGST always add up to the tax exactly (odd paise)', () {
    for (var price = 1; price < 400; price++) {
      final b = calcBill([CartLine(product: p(price, 1800), qtyMilli: 1000)]);
      expect(b.cgst + b.sgst, b.tax);
      expect((b.cgst - b.sgst).abs() <= 1, true);
    }
  });

  test('0 percent slab has no tax; mixed cart totals and round-off are exact', () {
    final lines = [
      CartLine(product: p(12345, 0), qtyMilli: 2000),
      CartLine(product: p(9999, 2800), qtyMilli: 1500),
      CartLine(product: p(501, 1800), qtyMilli: 3000),
    ];
    final b = calcBill(lines);
    final sum = b.lines.fold<int>(0, (s, l) => s + l.total);
    expect(b.grandTotal % 100, 0);
    expect(b.grandTotal - sum, b.roundOff);
    expect(b.roundOff.abs() <= 50, true);
    expect(b.lines[0].tax, 0);
  });

  test('per-item discount reduces the taxable value', () {
    final c = calcLine(CartLine(product: p(10000, 1800), qtyMilli: 1000, discountBp: 1000), inclusive: true);
    expect(c.discount, 1000);
    expect(c.total, 9000);
  });
}
