import 'package:erp2/domain/stock_value.dart';
import 'package:flutter_test/flutter_test.dart';

StockLine line(String id, {int stock = 10000, int sell = 12000, int buy = 8500, int avg = 9000, bool active = true}) => StockLine(id: id, name: 'P$id', active: active, stockMilli: stock, sellPaise: sell, buyPaise: buy, avgPaise: avg);

void main() {
  test('the worked example: 10 in stock, sells 120, bought 85, average 90 gives 1200 / 850 / 900', () {
    final v = StockValuation.compute([line('a')]);
    expect(v.total(ValuationRule.selling), 120000);
    expect(v.total(ValuationRule.buying), 85000);
    expect(v.total(ValuationRule.average), 90000);
  });

  test('until the shop chooses, average cost is shown and marked not chosen; a chosen rule is the shown one', () {
    final lines = [line('a')];
    final v = StockValuation.compute(lines);
    expect(v.isChosen, isFalse);
    expect(v.shown, ValuationRule.average);
    expect(v.shownTotal, 90000);
    final c = StockValuation.compute(lines, chosen: ValuationRule.selling);
    expect(c.isChosen, isTrue);
    expect(c.shownTotal, 120000);
  });

  test('average cost where known, else the latest buying price; a product with only an average still counts under every rule', () {
    final v = StockValuation.compute([line('a', avg: 0), line('b', buy: 0)]);
    expect(v.total(ValuationRule.average), 85000 + 90000);
    expect(v.total(ValuationRule.buying), 85000 + 90000, reason: 'no buying price for b: its average is used so all rules cover the same products');
    expect(v.activeProducts, 2);
  });

  test('cost not set is on its own line: never at the selling price, never as 0 inside a total', () {
    final v = StockValuation.compute([line('a'), line('x', buy: 0, avg: 0, stock: 5500)]);
    expect(v.unpricedProducts, 1);
    expect(v.unpricedQtyMilli, 5500);
    expect(v.total(ValuationRule.average), 90000);
    expect(v.total(ValuationRule.selling), 120000, reason: 'x is not valued at its selling price either');
    expect(v.activeProducts, 1);
  });

  test('inactive products with stock are included, on a separate line', () {
    final v = StockValuation.compute([line('a'), line('i', active: false, stock: 2000)]);
    expect(v.inactiveProducts, 1);
    expect(v.activeValue[ValuationRule.average], 90000);
    expect(v.inactiveValue[ValuationRule.average], 18000);
    expect(v.total(ValuationRule.average), 108000);
  });

  test('negative stock counts as 0 and is listed as an error; zero stock is ignored', () {
    final v = StockValuation.compute([line('a'), line('n', stock: -3000), line('z', stock: 0)]);
    expect(v.negatives.single.stockMilli, -3000);
    expect(v.total(ValuationRule.average), 90000);
    expect(v.unpricedProducts, 0);
  });

  test('quantities in fractions: 2.5 m at ₹40.40 is ₹101.00', () {
    final v = StockValuation.compute([line('m', stock: 2500, buy: 4040, avg: 0, sell: 5000)]);
    expect(v.total(ValuationRule.buying), 10100);
  });

  test('setting text', () {
    expect(ruleFromSetting('selling'), ValuationRule.selling);
    expect(ruleFromSetting('nonsense'), isNull);
    expect(ruleFromSetting(null), isNull);
  });
}
