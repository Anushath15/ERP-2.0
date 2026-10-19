import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/app_database.dart';
import 'package:erp2/data/repo/product_codes.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/gst_price.dart';
import 'package:erp2/domain/models.dart';
import 'package:erp2/domain/product_code.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/fake/store.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'data/generated/schema.dart';
import 'data/helpers.dart' as dh;
import 'helpers.dart';

// Adding a product: price with or without GST, minimum stock, HSN code, brand, the program's product code, and the five fields that
// must be filled in.
void main() {
  Future<Product?> byName(AppData d, String name) async {
    final r = await d.db.rows('SELECT id FROM products WHERE name = ?', [name]);
    return r.isEmpty ? null : d.catalog.product(r.first.read<String>('id'));
  }

  group('prices with or without GST', () {
    test('selling price: kept the way the shop prices things', () {
      expect(sellingPriceToStore(enteredPaise: 10000, enteredIncludesGst: false, shopPricesIncludeGst: true, gstBp: 1800), 11800, reason: '100 without GST in a shop whose prices include GST');
      expect(sellingPriceToStore(enteredPaise: 11800, enteredIncludesGst: true, shopPricesIncludeGst: true, gstBp: 1800), 11800);
      expect(sellingPriceToStore(enteredPaise: 11800, enteredIncludesGst: true, shopPricesIncludeGst: false, gstBp: 1800), 10000);
      expect(sellingPriceToStore(enteredPaise: 10000, enteredIncludesGst: false, shopPricesIncludeGst: false, gstBp: 1800), 10000);
    });
    test('buying price: always kept without GST', () {
      expect(buyingPriceToStore(enteredPaise: 11800, enteredIncludesGst: true, gstBp: 1800), 10000);
      expect(buyingPriceToStore(enteredPaise: 10000, enteredIncludesGst: false, gstBp: 1800), 10000);
      expect(buyingPriceToStore(enteredPaise: 5000, enteredIncludesGst: true, gstBp: 0), 5000, reason: '0% GST changes nothing');
    });
    test('rounds to the nearest paisa, and a price converted there and back is within one paisa', () {
      expect(sellingPriceToStore(enteredPaise: 9999, enteredIncludesGst: false, shopPricesIncludeGst: true, gstBp: 500), 10499);
      for (final gst in [0, 500, 1200, 1800, 2800]) {
        for (final p in [1, 99, 12345, 999999]) {
          final up = sellingPriceToStore(enteredPaise: p, enteredIncludesGst: false, shopPricesIncludeGst: true, gstBp: gst);
          final back = sellingPriceToStore(enteredPaise: up, enteredIncludesGst: true, shopPricesIncludeGst: false, gstBp: gst);
          expect((back - p).abs() <= 1, isTrue, reason: 'gst $gst price $p');
        }
      }
    });
  });

  group('product codes', () {
    test('the prefix is the first three English letters of the category', () {
      expect(productCodePrefix('Electrical'), 'ELE');
      expect(productCodePrefix('wood screws'), 'WOO');
      expect(productCodePrefix('PVC & Pipes'), 'PVC');
      expect(productCodePrefix('Go'), 'GO');
      expect(productCodePrefix('12'), 'GEN');
      expect(productCodePrefix('மின்'), 'GEN');
      expect(formatProductCode('ELE', 7), 'ELE-0007');
    });

    Product make(String id, String category, {String code = ''}) =>
        Product(id: id, name: id, category: category, unit: 'pcs', pricePaise: 100, costPaise: 50, stockMilli: 0, gstBp: 1800, barcode: '', code: code);

    test('new products get ELE-0001, ELE-0002 ... per prefix; another category starts its own count; editing keeps the code', () async {
      final d = dh.memoryShop();
      await d.catalog.saveProduct(make('Bulb', 'Electrical'), create: true);
      await d.catalog.saveProduct(make('Switch', 'Electrical'), create: true);
      await d.catalog.saveProduct(make('Screw', 'Hardware'), create: true);
      await d.catalog.saveProduct(make('Wire', 'Electronics'), create: true); // the same ELE prefix: the count goes on
      expect([for (final n in ['Bulb', 'Switch', 'Screw', 'Wire']) (await d.catalog.product(n))!.code], ['ELE-0001', 'ELE-0002', 'HAR-0001', 'ELE-0003']);
      final bulb = (await d.catalog.product('Bulb'))!;
      await d.catalog.saveProduct(bulb.copyWith(name: 'LED Bulb', brand: 'Philips', category: 'Hardware'), create: false);
      final after = (await d.catalog.product('Bulb'))!;
      expect(after.code, 'ELE-0001', reason: 'a code never changes, even when the category does');
      expect(after.brand, 'Philips');
      await d.close();
    });

    test('a code already taken is passed over, never repeated', () async {
      final d = dh.memoryShop();
      await d.catalog.saveProduct(make('a', 'Electrical', code: 'ELE-0001'), create: true);
      await d.catalog.saveProduct(make('b', 'Electrical'), create: true);
      expect((await d.catalog.product('b'))!.code, 'ELE-0002');
      await d.close();
    });

    test('backfill: every product without a code gets one, oldest first, and a second run does nothing', () async {
      final d = dh.memoryShop();
      await d.db.exec("INSERT INTO products(id, name, category, unit, price_paise, active, created_at, updated_at, device_id) VALUES ('x1','One','Paints','pcs',1,1,10,10,'d'), ('x2','Two','Paints','pcs',1,1,20,20,'d')");
      expect(await backfillProductCodes(d.db), 2);
      expect((await d.catalog.product('x1'))!.code, 'PAI-0001');
      expect((await d.catalog.product('x2'))!.code, 'PAI-0002');
      expect(await backfillProductCodes(d.db), 0);
      await d.close();
    });

    test('upgrading a version 3 file: every product already there gets its code', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final old = await verifier.schemaAt(3);
      old.rawDatabase.execute("INSERT INTO products(id, name, category, unit, price_paise, active, created_at, updated_at, device_id, version, hlc, cost_paise, gst_bp, hsn, barcode, min_stock_milli, avg_cost_paise) VALUES ('a','A','Electrical','pcs',1,1,1,1,'d',1,'',0,1800,'','',0,0), ('b','B','Hardware','pcs',1,1,2,2,'d',1,'',0,1800,'','',0,0)");
      final db = AppDatabase(old.newConnection(), native: false);
      await verifier.migrateAndValidate(db, 4);
      final r = await db.customSelect('SELECT id, code, brand FROM products ORDER BY id').get();
      expect([for (final x in r) x.read<String>('code')], ['ELE-0001', 'HAR-0001']);
      expect([for (final x in r) x.read<String>('brand')], ['', '']);
      await db.close();
    });
  });

  group('minimum stock', () {
    test('low stock is judged by the product\'s own minimum', () {
      Product p(int stock, int min) => Product(id: 'p', name: 'p', category: 'c', unit: 'pcs', pricePaise: 1, costPaise: 1, stockMilli: stock, gstBp: 0, barcode: '', minStockMilli: min);
      expect(p(3000, 3000).lowStock, isTrue, reason: 'reached the minimum');
      expect(p(3001, 3000).lowStock, isFalse);
      expect(p(0, 3000).lowStock, isFalse, reason: 'zero is "out of stock", its own state');
      expect(p(0, 3000).outOfStock, isTrue);
    });
  });

  group('the Add product form', () {
    const minLabel = 'Minimum stock (warn me when stock falls to this)';
    Future<ProviderContainer> app(WidgetTester t, {bool shopInclusive = true}) async {
      final c = await pumpApp(t, size: const ScreenSpec('tall', 1400, 2600), location: '/products', motion: MotionLevel.off, followSystemMotion: false);
      c.read(shopProvider.notifier).set((x) => x.copyWith(pricesIncludeGst: shopInclusive));
      await t.pump();
      return c;
    }

    Future<void> open(WidgetTester t) async {
      await t.tap(find.text('Add product').first);
      await t.pumpAndSettle();
    }

    Finder field(String label) => find.widgetWithText(TextFormField, label).last;
    Future<void> pick(WidgetTester t, String key, String text) async {
      final f = find.descendant(of: find.byKey(ValueKey('choice-$key')), matching: find.text(text));
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pump();
    }

    testWidgets('the form has Includes/Excludes GST buttons under each price, minimum stock, HSN code and brand', (tester) async {
      await app(tester);
      await open(tester);
      for (final t in ['Product name', 'Brand name', 'Selling price', 'Buying price', 'Stock now', minLabel, 'HSN code', 'Barcode']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expect(find.byKey(const ValueKey('choice-priceMode')), findsOneWidget);
      expect(find.byKey(const ValueKey('choice-costMode')), findsOneWidget);
      expect(find.text('Includes GST'), findsNWidgets(2));
      expect(find.text('Excludes GST'), findsNWidgets(2));
      expect(find.textContaining('A product code is made for you'), findsOneWidget);
    });

    testWidgets('the five fields must be filled in: name, selling price, buying price, current stock, minimum stock', (tester) async {
      await app(tester);
      await open(tester);
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('Please fill this in'), findsNWidgets(5), reason: 'exactly the five required fields complain');
    });

    testWidgets('HSN code: 4 to 8 digits when typed', (tester) async {
      await app(tester);
      await open(tester);
      await tester.enterText(field('HSN code'), '12');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('An HSN code has 4 to 8 digits'), findsOneWidget);
    });

    testWidgets('saving: price typed WITHOUT GST in a GST-inclusive shop is stored with GST; buying price WITH GST is stored without; code, brand, minimum stock kept', (tester) async {
      final c = await app(tester);
      await open(tester);
      await tester.enterText(field('Product name'), 'LED bulb 9W');
      await tester.enterText(field('Brand name'), 'Philips');
      await tester.enterText(field('Selling price'), '100');
      await pick(tester, 'priceMode', 'Excludes GST');
      await tester.enterText(field('Buying price'), '59');
      await pick(tester, 'costMode', 'Includes GST');
      await tester.enterText(field('Stock now'), '20');
      await tester.enterText(field(minLabel), '6');
      await tester.enterText(field('HSN code'), '853950');
      await tester.pump();
      await tester.tap(find.text('Save').last);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pumpAndSettle();
      final saved = (await tester.runAsync(() => byName(c.read(appDataProvider), 'LED bulb 9W')))!;
      expect(saved, isNotNull);
      expect(saved.pricePaise, 11800, reason: '100 + 18% GST, because this shop prices include GST');
      expect(saved.costPaise, 5000, reason: '59 with GST is 50 without');
      expect(saved.stockMilli, 20000);
      expect(saved.minStockMilli, 6000);
      expect(saved.hsn, '853950');
      expect(saved.brand, 'Philips');
      expect(saved.code, matches(RegExp(r'^[A-Z]{2,3}-\d{4}$')), reason: 'the program made a code from the category');
      expect(c.read(productsProvider).first.code, saved.code, reason: 'the list already shows it');
    });

    testWidgets('a shop whose prices exclude GST: a price typed WITH GST is stored without', (tester) async {
      final c = await app(tester, shopInclusive: false);
      await open(tester);
      await tester.enterText(field('Product name'), 'Cable');
      await tester.enterText(field('Selling price'), '118');
      await pick(tester, 'priceMode', 'Includes GST');
      await tester.enterText(field('Buying price'), '80');
      await tester.enterText(field('Stock now'), '0');
      await tester.enterText(field(minLabel), '0');
      await tester.pump();
      await tester.tap(find.text('Save').last);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pumpAndSettle();
      final saved = (await tester.runAsync(() => byName(c.read(appDataProvider), 'Cable')))!;
      expect(saved.pricePaise, 10000);
      expect(saved.costPaise, 8000);
    });

    testWidgets('the sample shop\'s products all have codes and the list has a Code column', (tester) async {
      final c = await app(tester);
      expect(find.text('Code'), findsWidgets);
      expect(c.read(productsProvider).every((p) => p.code.isNotEmpty), isTrue);
    });
  });
}
