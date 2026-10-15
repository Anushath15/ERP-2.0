import 'package:erp2/data/context.dart';
import 'package:erp2/domain/stock_value.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  test('the stock value is computed from the database by the one shared calculation, and the chosen rule is a single setting', () async {
    final d = memoryShop();
    await d.catalog.saveProduct(sampleProduct('Pipe', id: 'a', price: 12000, cost: 8500, stock: 10000), create: true);
    await d.catalog.saveProduct(sampleProduct('No cost', id: 'b', price: 5000, cost: 0, stock: 3000), create: true);
    await d.catalog.saveProduct(sampleProduct('Negative', id: 'c', price: 5000, cost: 1000, stock: -2000), create: true);
    await d.db.exec("UPDATE products SET avg_cost_paise = 9000 WHERE id = 'a'");
    final v = await d.reports.stockValuation();
    expect(v.isChosen, isFalse);
    expect(v.shown, ValuationRule.average);
    expect(v.total(ValuationRule.selling), 120000);
    expect(v.total(ValuationRule.buying), 85000);
    expect(v.total(ValuationRule.average), 90000);
    expect(v.unpricedProducts, 1);
    expect(v.negatives.single.id, 'c');
    await d.settings.put('valuation.rule', 'buying');
    final w = await d.reports.stockValuation();
    expect(w.chosen, ValuationRule.buying);
    expect(w.shownTotal, 85000);
  });
}
