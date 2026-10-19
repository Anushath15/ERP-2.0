import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/app_database.dart';
import 'package:erp2/data/repo/rebuild.dart';
import 'package:erp2/data/repo/self_check.dart';
import 'package:erp2/fake/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'generated/schema.dart';
import 'helpers.dart';
import 'package:drift_dev/api/migrations_native.dart';

// What these tests prove: the product search finds a product by its name, barcode, code, brand or category (typing the first letters is
// enough), puts the best match first, never fails (it falls back to plain matching), and the search index can be checked and repaired.
// What they do NOT prove: the speed on a very big catalogue (see the speed tests).
void main() {
  late AppData d;
  setUp(() async {
    d = memoryShop();
    Product p(String id, String name, {String brand = '', String category = 'Hardware', String barcode = '', String code = ''}) =>
        sampleProduct(name, id: id).copyWith(brand: brand, category: category, barcode: barcode, code: code);
    await d.catalog.saveProduct(p('p1', '1/2" WOOD SCREW BOX', category: 'Fasteners', code: 'FAS-0045', brand: 'Anchor'), create: true);
    await d.catalog.saveProduct(p('p2', 'MCB 20A SINGLE POLE', category: 'Electricals', brand: 'Havells', barcode: '8901234567890'), create: true);
    await d.catalog.saveProduct(p('p3', 'Fasteners kit', category: 'Kits'), create: true);
    await d.catalog.saveProduct(p('p4', 'PVC PIPE 1 INCH', category: 'Plumbing', brand: 'Supreme'), create: true);
  });
  tearDown(() => d.close());

  Future<List<String>> ids(String q) async => [for (final x in await d.catalog.searchProducts(q)) x.id];

  test('by name (any part, first letters are enough), by barcode', () async {
    expect(await ids('woo scr'), ['p1']);
    expect(await ids('single pole'), ['p2']);
    expect(await ids('8901234'), ['p2']);
  });

  test('by brand, by code and by category (new)', () async {
    expect(await ids('havel'), ['p2']);
    expect(await ids('anchor'), ['p1']);
    expect(await ids('FAS-0045'), ['p1']);
    expect(await ids('fas 0045'), ['p1']);
    expect(await ids('plumb'), ['p4']);
  });

  test('the best match comes first: a hit in the name beats a hit in the category', () async {
    expect(await ids('fasteners'), ['p3', 'p1'], reason: '"Fasteners kit" has it in the name; the screw box only in its category');
  });

  test('a change to the brand or category is searchable at once; a deleted product is not found', () async {
    await d.catalog.saveProduct((await d.catalog.product('p4'))!.copyWith(brand: 'Ashirvad'), create: false);
    expect(await ids('ashirv'), ['p4']);
    expect(await ids('supreme'), isEmpty, reason: 'the old brand is gone from the index');
    await d.db.exec('UPDATE products SET deleted_at = 1 WHERE id = ?', ['p4']);
    expect(await ids('ashirv'), isEmpty);
  });

  test('odd typing never fails: quotes, symbols, SQL words, only spaces', () async {
    for (final q in ['"', "'; DROP TABLE products;--", '* ( ) -', 'NEAR/3 x', 'a OR b', '   ']) {
      await d.catalog.searchProducts(q);
    }
    expect((await d.catalog.searchProducts('   ')).length, 4, reason: 'nothing typed: the first products');
    expect(await d.catalog.productCount(), 4);
  });

  test('if the search index is unusable, the search still works (plain matching) and finds the same products', () async {
    await d.db.exec('DROP TABLE product_fts_data');
    expect(await ids('havel'), ['p2'], reason: 'brand');
    expect(await ids('woo scr'), ['p1'], reason: 'name words, each only the start');
    expect(await ids('FAS-0045'), ['p1'], reason: 'code');
    expect(await ids('50%_'), isEmpty, reason: 'a percent or underscore is just a character, not "match anything"');
  });

  test('the self-check notices a product missing from the search index, and Rebuild totals repairs it', () async {
    expect(await selfCheck(d.db), isEmpty);
    await d.db.exec("INSERT INTO product_fts(product_fts) VALUES('delete-all')");
    final problems = await selfCheck(d.db);
    expect(problems.map((x) => x.what), contains('A product that the search cannot find (its search entry is missing)'));
    expect(await ids('havel'), isEmpty);
    await rebuildSummaries(d.db);
    expect(await selfCheck(d.db), isEmpty);
    expect(await ids('havel'), ['p2']);
  });

  test('an older database (version 7) upgrades: existing products become searchable by brand, code and category', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.schemaAt(7);
    final raw = connection.rawDatabase;
    raw.execute("INSERT INTO products(id, name, category, unit, price_paise, cost_paise, gst_bp, hsn, barcode, min_stock_milli, code, brand, mrp_paise, active, created_at, updated_at, device_id, version, hlc) VALUES ('o1','OLD ITEM','Paints','pcs',100,50,1800,'','',0,'PNT-0001','Asian',0,1,1,1,'x',1,'')");
    final db = AppDatabase(connection.newConnection(), native: false);
    await verifier.migrateAndValidate(db, 8);
    final data = AppData(DataContext(db: db, deviceId: 'dev-test', clock: () => DateTime(2026, 10, 14, 15, 30)));
    expect([for (final x in await data.catalog.searchProducts('asian')) x.id], ['o1']);
    expect([for (final x in await data.catalog.searchProducts('PNT-0001')) x.id], ['o1']);
    expect([for (final x in await data.catalog.searchProducts('paints')) x.id], ['o1']);
    expect(await selfCheck(db), isEmpty);
    await db.close();
  });
}
