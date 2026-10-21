import 'package:erp2/data/context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What this test proves: tidying the data file keeps every row, keeps the product search working, passes the integrity check, and reports the sizes.
void main() {
  test('tidy keeps everything: products, search, summaries; integrity check passes', () async {
    final d = memoryShop();
    addTearDown(d.close);
    for (var i = 0; i < 60; i++) {
      await d.catalog.saveProduct(sampleProduct('WOOD SCREW $i', id: 'p$i', stock: 1000), create: true);
    }
    final r = await d.db.maintain();
    expect(r.before, greaterThan(0));
    expect(r.after, greaterThan(0));
    expect(await d.db.scalarInt('SELECT COUNT(*) FROM products'), 60);
    expect((await d.catalog.searchProducts('wood screw 7')).any((p) => p.id == 'p7'), isTrue, reason: 'the search index still works');
    final ok = await d.db.rows('PRAGMA integrity_check');
    expect(ok.single.read<String>('integrity_check'), 'ok');
    expect(await d.db.scalarInt('SELECT COUNT(*) FROM stock_cache WHERE qty_milli = 1000'), 60);
  });
}
