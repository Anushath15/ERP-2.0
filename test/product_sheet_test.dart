import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/domain/export/export_table.dart';
import 'package:erp2/domain/models.dart';
import 'package:erp2/domain/product_sheet/product_sheet.dart';
import 'package:erp2/domain/product_sheet/sheet_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'data/helpers.dart';

// What these tests prove: the Excel sheet the program writes can be read back exactly; a sheet saved by Excel (shared strings, gaps, formatting) is read
// right; the plan says row by row what would change, never blanks a field with an empty cell, and lists every problem; applying it changes products and
// puts counted stock right with a stock change, all or nothing.
Uint8List _zip(Map<String, String> files) {
  final a = Archive();
  for (final e in files.entries) {
    final b = utf8.encode(e.value);
    a.addFile(ArchiveFile(e.key, b.length, b));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

Product _p(String id, String name, {String code = '', String brand = '', int price = 10000, int cost = 0, int mrp = 0, int stock = 0, String cat = 'Plumbing', String unit = 'pcs', int gst = 1800}) =>
    Product(id: id, name: name, category: cat, unit: unit, pricePaise: price, costPaise: cost, stockMilli: stock, gstBp: gst, barcode: '', code: code, brand: brand, mrpPaise: mrp, hsn: '7412', minStockMilli: 0);

int _n = 0;
String _id() => 'new-${++_n}';

void main() {
  group('reading sheets', () {
    test('the sheet the program writes is read back cell for cell', () {
      final products = [_p('a', 'BALL VALVE', code: 'PLU-0001', brand: 'Plato', price: 105000, mrp: 120000, stock: 5000), _p('b', '1" ELBOW "special"', code: 'PLU-0002', stock: 1500)];
      final rows = readXlsxRows(encodeXlsx(buildProductSheet(products)));
      expect(rows.first, productSheetHeaders);
      expect(rows.length, 3);
      final valve = rows.firstWhere((r) => r.first == 'PLU-0001'), elbow = rows.firstWhere((r) => r.first == 'PLU-0002'); // sorted by category, then name
      expect(valve.sublist(0, 5), ['PLU-0001', 'BALL VALVE', 'Plumbing', 'Plato', 'pcs']);
      expect(valve[8], '1200.00', reason: 'MRP');
      expect(valve[9], '1050.00', reason: 'selling price');
      expect(elbow[1], '1" ELBOW "special"');
      expect(elbow[11], '1.5', reason: 'stock with a decimal');
      expect(elbow[8], '', reason: 'an MRP not entered is an empty cell to fill');
    });

    test('a sheet saved by Excel: shared strings, rich text, a gap in a row, a number in a text column, an escaped ampersand', () {
      final bytes = _zip({
        '[Content_Types].xml': '<Types/>',
        'xl/workbook.xml': '<workbook xmlns:r="x"><sheets><sheet name="Stock" sheetId="1" r:id="rId7"/></sheets></workbook>',
        'xl/_rels/workbook.xml.rels': '<Relationships><Relationship Id="rId7" Type="t" Target="worksheets/data.xml"/></Relationships>',
        'xl/sharedStrings.xml': '<sst><si><t>Code</t></si><si><t>Name</t></si><si><t>MRP</t></si><si><r><t>BALL </t></r><r><t>VALVE &amp; CO</t></r></si><si><t>PLU-1</t></si></sst>',
        'xl/worksheets/data.xml': '<worksheet><sheetData>'
            '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="D1" t="s"><v>2</v></c></row>'
            '<row r="2"><c r="A2" t="s"><v>4</v></c><c r="B2" t="s"><v>3</v></c><c r="D2"><v>1.05E3</v></c></row>'
            '<row r="3"/><row r="4"><c r="B4" t="inlineStr"><is><t>PLAIN</t></is></c><c r="D4" t="str"><v>77</v></c></row>'
            '</sheetData></worksheet>',
      });
      final rows = readXlsxRows(bytes);
      expect(rows[0], ['Code', 'Name', '', 'MRP']);
      expect(rows[1], ['PLU-1', 'BALL VALVE & CO', '', '1.05E3']);
      expect(rows.last, ['', 'PLAIN', '', '77']);
      expect(parseMoney('1.05E3'), 105000);
    });

    test('a file that is not an Excel file is refused in plain words', () {
      expect(() => readXlsxRows(Uint8List.fromList([1, 2, 3])), throwsA(isA<SheetReadException>()));
    });

    test('CSV: quotes, commas inside quotes, semicolons, a BOM and a Windows line break', () {
      expect(readCsvRows('${String.fromCharCode(0xFEFF)}Code,Name,MRP\r\nA1,"Valve, brass ""big""",200\r\nA2,Elbow,\r\n'), [
        ['Code', 'Name', 'MRP'],
        ['A1', 'Valve, brass "big"', '200'],
        ['A2', 'Elbow'],
      ]);
      expect(readCsvRows('Code;Name\nA1;X')[1], ['A1', 'X']);
    });

    test('numbers: rupees, quantities and GST as they are typed', () {
      expect(parseMoney('₹ 1,050.5'), 105050);
      expect(parseMoney('Rs. 99'), 9900);
      expect(parseMoney('abc'), isNull);
      expect(parseQty('2.5'), 2500);
      expect(parseGstBp('18%'), 1800);
      expect(parseGstBp('0.18'), 1800, reason: 'an Excel percent cell holds 0.18');
      expect(parseGstBp('5'), 500);
    });
  });

  group('the plan', () {
    final existing = [
      _p('a', 'BALL VALVE', code: 'PLU-0001', brand: 'Plato', price: 105000, cost: 80000, stock: 5000),
      _p('b', 'BALL VALVE', code: 'PLU-0002', brand: 'HSG', price: 48000),
      _p('c', 'ELBOW', code: 'PLU-0003', stock: 2000),
    ];
    List<List<String>> sheet(List<List<String>> body, {List<String>? head}) => [head ?? ['Code', 'Name', 'Brand', 'MRP', 'Selling price', 'Buying price', 'Stock'], ...body];

    test('MRP, buying price and counted stock for an existing product; an empty cell changes nothing', () {
      final plan = planProductSheet(sheet([['PLU-0001', '', '', '1200', '', '', '8']]), existing, newId: _id);
      expect(plan.fatal, '');
      final r = plan.rows.single;
      expect(r.status, SheetRowStatus.update);
      expect(r.product!.mrpPaise, 120000);
      expect(r.product!.pricePaise, 105000, reason: 'the empty selling price was left alone');
      expect(r.product!.costPaise, 80000, reason: 'the empty buying price was left alone');
      expect(r.stockTarget, 8000);
      expect(r.stockBefore, 5000);
      expect(r.changes, ['MRP 0.00 -> 1200.00', 'stock 5 -> 8']);
    });

    test('nothing different = unchanged; the same name in two brands needs the code or the brand', () {
      var plan = planProductSheet(sheet([['PLU-0001', 'BALL VALVE', 'Plato', '', '1050', '', '5']]), existing, newId: _id);
      expect(plan.rows.single.status, SheetRowStatus.unchanged);
      plan = planProductSheet(sheet([['', 'BALL VALVE', '', '', '999', '', '']]), existing, newId: _id);
      expect(plan.rows.single.status, SheetRowStatus.create, reason: 'no brand typed: it is not the Plato or the HSG one, so it is a new product');
      plan = planProductSheet(sheet([['', 'ball valve', 'hsg', '', '500', '', '']]), existing, newId: _id);
      expect(plan.rows.single.status, SheetRowStatus.update);
      expect(plan.rows.single.product!.id, 'b');
      expect(plan.rows.single.product!.pricePaise, 50000);
    });

    test('a new product needs a name and a selling price; its stock is an opening stock; GST defaults to 18', () {
      final plan = planProductSheet(sheet([
        ['', 'NEW ITEM', 'Surya', '150', '120', '90', '10'],
        ['', 'NO PRICE', '', '', '', '', ''],
        ['', '', '', '', '100', '', ''],
      ]), existing, newId: _id);
      final a = plan.rows[0];
      expect(a.status, SheetRowStatus.create);
      expect(a.product!.gstBp, 1800);
      expect(a.product!.stockMilli, 10000);
      expect(a.product!.brand, 'Surya');
      expect(plan.rows[1].status, SheetRowStatus.error);
      expect(plan.rows[1].problems.single, contains('Selling price'));
      expect(plan.rows[2].status, SheetRowStatus.error);
      expect(plan.errors, 2);
      expect(plan.hasWork, isTrue);
    });

    test('problems are listed and the row is skipped: an unknown code, a text where a number goes, a negative number, the same code twice', () {
      final plan = planProductSheet(sheet([
        ['XXX-9999', '', '', '100', '', '', ''],
        ['PLU-0001', '', '', 'abc', '', '', ''],
        ['PLU-0002', '', '', '', '-5', '', ''],
        ['PLU-0003', '', '', '100', '', '', ''],
        ['PLU-0003', '', '', '110', '', '', ''],
      ]), existing, newId: _id);
      expect(plan.rows.map((r) => r.status), [SheetRowStatus.error, SheetRowStatus.error, SheetRowStatus.error, SheetRowStatus.update, SheetRowStatus.error]);
      expect(plan.rows[0].problems.single, contains('not in your products'));
      expect(plan.rows[1].problems.single, contains('"abc" is not a number'));
      expect(plan.rows[2].problems.single, contains('below zero'));
      expect(plan.rows[4].problems.single, contains('earlier row'));
    });

    test('warnings: selling below the buying price, above the MRP', () {
      final plan = planProductSheet(sheet([['PLU-0001', '', '', '600', '700', '', '']]), existing, newId: _id);
      expect(plan.rows.single.warnings.length, 2);
    });

    test('headers in other words are understood; a sheet with no Code or Name column is refused', () {
      final plan = planProductSheet([
        ['Item', 'Price', 'MRP', 'Qty'],
        ['ELBOW', '25', '30', '4'],
      ], existing, newId: _id);
      final r = plan.rows.single;
      expect((r.status, r.product!.pricePaise, r.product!.mrpPaise, r.stockTarget), (SheetRowStatus.update, 2500, 3000, 4000));
      expect(planProductSheet([['Foo', 'Bar'], ['1', '2']], existing, newId: _id).fatal, isNotEmpty);
    });

    test('the untouched downloaded sheet changes nothing', () {
      final rows = readXlsxRows(encodeXlsx(buildProductSheet(existing)));
      final plan = planProductSheet(rows, existing, newId: _id);
      expect(plan.hasWork, isFalse);
      expect(plan.unchanged, 3);
      expect(plan.errors, 0);
    });
  });

  group('applying', () {
    test('details, new products and counted stock are saved; stock goes through a stock change of the difference', () async {
      final d = memoryShop();
      addTearDown(d.close);
      await d.catalog.saveProduct(sampleProduct('BALL VALVE', id: 'p1', stock: 5000, price: 10000, cost: 0), create: true);
      final all = await d.catalog.products();
      final code = all.single.code;
      final plan = planProductSheet([
        ['Code', 'Name', 'Brand', 'MRP', 'Selling price', 'Buying price', 'Stock'],
        [code, '', 'Plato', '200', '165', '120', '8'],
        ['', 'BRAND NEW', 'Surya', '100', '80', '60', '10'],
      ], all, newId: _id);
      final touched = await d.catalog.applyProductSheet(plan, at: DateTime(2026, 10, 20), source: 'Excel');
      expect(touched.length, 2);
      final p = (await d.catalog.product('p1'))!;
      expect((p.brand, p.mrpPaise, p.pricePaise, p.costPaise, p.stockMilli), ('Plato', 20000, 16500, 12000, 8000));
      final moves = await d.db.rows("SELECT qty_milli, kind, note FROM stock_movements WHERE product_id = 'p1' ORDER BY at, id");
      expect(moves.last.read<int>('qty_milli'), 3000, reason: 'counted 8, the program had 5: +3');
      expect(moves.last.read<String>('kind'), 'adjustment');
      final created = (await d.catalog.products()).firstWhere((x) => x.name == 'BRAND NEW');
      expect((created.stockMilli, created.pricePaise, created.brand), (10000, 8000, 'Surya'));
      expect(created.code, isNotEmpty);
      expect(await d.db.scalarInt("SELECT COUNT(*) FROM audit WHERE what = 'price'"), 1);
      // stock equals the movements (the program's own check)
      final bad = await d.db.rows('SELECT p.id FROM products p LEFT JOIN stock_cache s ON s.product_id = p.id WHERE COALESCE(s.qty_milli,0) <> COALESCE((SELECT SUM(qty_milli) FROM stock_movements m WHERE m.product_id = p.id),0)');
      expect(bad, isEmpty);
    });

    test('all or nothing: when one row cannot be saved the earlier rows are not kept either', () async {
      final d = memoryShop();
      addTearDown(d.close);
      await d.catalog.saveProduct(sampleProduct('ONE', id: 'p1', stock: 1000), create: true);
      final all = await d.catalog.products();
      final plan = planProductSheet([
        ['Code', 'Name', 'Selling price'],
        [all.single.code, '', '555'],
        ['', 'TWO', '10'],
      ], all, newId: _id);
      // break the second row after planning: the same id as an existing product
      plan.rows[1].product = plan.rows[1].product!.copyWith(name: 'TWO');
      const dup = Product(id: 'p1', name: 'TWO', category: 'X', unit: 'pcs', pricePaise: 1000, costPaise: 0, stockMilli: 0, gstBp: 1800, barcode: '');
      plan.rows[1].product = dup;
      await expectLater(d.catalog.applyProductSheet(plan, at: DateTime(2026, 10, 20), source: 'Excel'), throwsA(anything));
      expect((await d.catalog.product('p1'))!.pricePaise, sampleProduct('x').pricePaise, reason: 'the first row was rolled back');
    });
  });
}
