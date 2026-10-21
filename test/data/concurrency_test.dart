import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: when many bills are saved at the same moment (several screens, a sync, a counter link) nothing is lost or doubled: every bill has
// its own gapless number, the stock is exactly what was sold, the customer balance is exactly what was left unpaid, and the same bill sent twice at once is saved once.
void main() {
  Product prod() => sampleProduct('BOLT', id: 'p1', stock: 1000000, price: 10000);
  BillLineInput line(Product p, int qty) => BillLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: qty, ratePaise: p.pricePaise, gstBp: p.gstBp, discountBp: 0);

  test('60 different bills saved all at once: numbers 1..60 with no gap or repeat, stock and balance exactly right', () async {
    final d = memoryShop();
    addTearDown(d.close);
    final p = prod();
    await d.catalog.saveProduct(p, create: true);
    await d.catalog.saveCustomer(sampleCustomer('Murugan', id: 'c1', limit: 100000000), create: true);
    final saves = <Future<SavedBill>>[];
    for (var i = 0; i < 60; i++) {
      final onCredit = i % 3 == 0;
      saves.add(d.bills.saveBill(SaveBillInput(
        idemKey: 'k$i',
        at: DateTime(2026, 10, 21, 10, i % 60),
        lines: [line(p, 1000 * (1 + i % 4))],
        customerId: onCredit ? 'c1' : null,
        customerName: onCredit ? 'Murugan' : '',
        receivedPaise: onCredit ? 0 : null,
      )));
    }
    final done = await Future.wait(saves);
    final numbers = done.map((s) => s.number).toSet();
    expect(numbers.length, 60, reason: 'every bill has its own number');
    final seqs = (await d.db.rows('SELECT seq FROM bills ORDER BY seq')).map((r) => r.read<int>('seq')).toList();
    expect(seqs, List.generate(60, (i) => i + 1), reason: 'gapless');
    var sold = 0;
    for (var i = 0; i < 60; i++) {
      sold += 1000 * (1 + i % 4);
    }
    expect((await d.catalog.product('p1'))!.stockMilli, 1000000 - sold, reason: 'stock is exactly what was sold');
    final creditTotal = done.where((s) => s.balancePaise > 0).fold<int>(0, (a, s) => a + s.balancePaise);
    expect(await d.ledger.balanceOf('c1'), creditTotal, reason: 'the customer owes exactly the unpaid part of the credit bills');
    final bad = await d.db.rows('SELECT p.id FROM products p LEFT JOIN stock_cache s ON s.product_id = p.id WHERE COALESCE(s.qty_milli,0) <> COALESCE((SELECT SUM(qty_milli) FROM stock_movements m WHERE m.product_id = p.id),0)');
    expect(bad, isEmpty);
  });

  test('the same bill sent 10 times at once (a double click, a retry) is saved once', () async {
    final d = memoryShop();
    addTearDown(d.close);
    final p = prod();
    await d.catalog.saveProduct(p, create: true);
    final results = await Future.wait([
      for (var i = 0; i < 10; i++) d.bills.saveBill(SaveBillInput(idemKey: 'same', at: DateTime(2026, 10, 21, 10), lines: [line(p, 2000)])),
    ]);
    expect(results.map((r) => r.id).toSet().length, 1);
    expect(await d.db.scalarInt('SELECT COUNT(*) FROM bills'), 1);
    expect((await d.catalog.product('p1'))!.stockMilli, 1000000 - 2000, reason: 'the stock was taken once');
  });
}
