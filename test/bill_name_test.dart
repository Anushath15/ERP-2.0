import 'package:erp2/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

// What this test proves: the name printed on a bill, estimate and receipt carries the brand in front, so the customer sees the make; with no brand it is just the name.
void main() {
  const p = Product(id: 'x', name: 'SWITCH 6A', category: 'Electrical', unit: 'pcs', pricePaise: 10000, costPaise: 7000, stockMilli: 5000, gstBp: 1800, barcode: '');
  test('the bill name has the brand in brackets in front', () {
    expect(p.billName, 'SWITCH 6A');
    expect(p.copyWith(brand: 'HAVELLS').billName, '(HAVELLS)SWITCH 6A');
    expect(p.copyWith(brand: '  ').billName, 'SWITCH 6A');
  });
}
