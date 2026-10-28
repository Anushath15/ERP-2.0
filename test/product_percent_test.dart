import 'package:erp2/design/motion_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: in the product form the prices come in the order of the work (MRP, buying price, selling price); each price can also be set as a
// percent of the MRP (MRP 100 and 50% gives 50), typing the price gives the percent back, and changing the MRP keeps the percent and moves the price.
void main() {
  Finder box(String label) => find.ancestor(of: find.text(label), matching: find.byType(TextFormField)).first;
  String text(WidgetTester t, String label) => t.widget<TextFormField>(box(label)).controller!.text;
  Future<void> type(WidgetTester t, String label, String v) async {
    await t.ensureVisible(box(label));
    await t.enterText(box(label), v);
    await t.pump();
  }

  testWidgets('order MRP, buying price, selling price; percent fields fill the prices both ways', (tester) async {
    await pumpApp(tester, size: const ScreenSpec('tall', 1366, 1800), location: '/products?add=1', motion: MotionLevel.off, followSystemMotion: false);
    final y = [for (final l in ['MRP (printed price, GST included)', 'Buying price', 'Buying discount % from MRP', 'Selling price', 'Selling discount % from MRP']) tester.getTopLeft(box(l)).dy];
    expect(y, orderedEquals([...y]..sort()), reason: 'top to bottom: MRP, buying price, buying %, selling price, selling %');
    expect(y.toSet(), hasLength(5));

    await type(tester, 'MRP (printed price, GST included)', '100');
    await type(tester, 'Buying discount % from MRP', '50');
    expect(text(tester, 'Buying price'), '50.00');
    await type(tester, 'Selling discount % from MRP', '25');
    expect(text(tester, 'Selling price'), '75.00');

    await type(tester, 'Buying price', '60');
    expect(text(tester, 'Buying discount % from MRP'), '40');
    await type(tester, 'MRP (printed price, GST included)', '200');
    expect(text(tester, 'Buying price'), '120.00', reason: 'the percent stays, the price follows the MRP');
    expect(text(tester, 'Selling price'), '150.00');
  });
}
