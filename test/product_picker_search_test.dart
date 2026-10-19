import 'package:erp2/design/theme.dart';
import 'package:erp2/features/billing/product_picker.dart';
import 'package:erp2/fake/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// What these tests prove: in the billing product list, typing finds a product by name, barcode, product code, brand or category, every word
// being any part of those. What they do NOT prove: the speed (measured separately: 2 ms for 10,000 products).
Product p(String id, String name, {String brand = '', String category = 'Hardware', String code = '', String barcode = ''}) =>
    Product(id: id, name: name, category: category, unit: 'pcs', pricePaise: 10000, costPaise: 6000, stockMilli: 5000, gstBp: 1800, barcode: barcode, code: code, brand: brand);

void main() {
  final products = [
    p('1', 'WOOD SCREW BOX', code: 'FAS-0045', brand: 'Anchor', category: 'Fasteners'),
    p('2', 'MCB 20A SINGLE POLE', brand: 'Havells', category: 'Electricals', barcode: '8901234567890'),
    p('3', 'PVC PIPE 1 INCH', brand: 'Supreme', category: 'Plumbing'),
  ];

  Future<void> type(WidgetTester t, String text) async {
    await t.enterText(find.byType(TextField), text);
    await t.pump();
  }

  testWidgets('name, barcode, code, brand and category all find the product', (t) async {
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: ProductPicker(products: products, inBill: const {}, onAdd: (_) {}, onQuickAdd: (_) {}))));
    for (final (q, found, notFound) in [
      ('wood scr', 'WOOD SCREW BOX', 'MCB 20A SINGLE POLE'),
      ('8901234', 'MCB 20A SINGLE POLE', 'WOOD SCREW BOX'),
      ('FAS-0045', 'WOOD SCREW BOX', 'PVC PIPE 1 INCH'),
      ('havel', 'MCB 20A SINGLE POLE', 'PVC PIPE 1 INCH'),
      ('plumb', 'PVC PIPE 1 INCH', 'WOOD SCREW BOX'),
    ]) {
      await type(t, q);
      expect(find.textContaining(found), findsWidgets, reason: q);
      expect(find.textContaining(notFound), findsNothing, reason: q);
    }
  });
}
