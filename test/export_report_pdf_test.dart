import 'dart:io';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/export_repo.dart';
import 'package:erp2/domain/export/export_table.dart';
import 'package:erp2/domain/stock_value.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/features/export/export_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'data/helpers.dart';

// What these tests prove: every report becomes a real PDF with the shop's name and details, a numbered table and the figures a reader needs; the product report
// carries the number of products and the worth of the stock, and those figures equal the Inventory page's own calculation; the totals equal the rows.
// With the environment variable ASK_PDF_DIR set, the PDFs are also written there to be looked at.
void main() {
  const shop = ShopProfile(name: 'Senthil Enterprises', address: 'College Road, Kanniyakumari - 629702', phone: '9342363155', gstin: '33ARKPK1357K1ZO');

  test('every report is a valid PDF', () async {
    final d = memoryShop();
    addTearDown(d.close);
    await d.catalog.saveProduct(sampleProduct('Wood screw', price: 1500, cost: 1000, stock: 14000, id: 'p1', gst: 1800), create: true);
    await d.catalog.saveProduct(sampleProduct('Hinge', price: 4500, cost: 3000, stock: 0, id: 'p2', gst: 1800), create: true);
    await d.catalog.saveCustomer(sampleCustomer('Murugan', id: 'c1', limit: 1000000), create: true);
    BillLineInput line(int q) => BillLineInput(productId: 'p1', name: 'Wood screw', unit: 'pcs', qtyMilli: q, ratePaise: 1500, gstBp: 1800);
    await d.bills.saveBill(SaveBillInput(idemKey: 'k1', at: DateTime(2026, 10, 14, 10), lines: [line(2000)]));
    await d.bills.saveBill(SaveBillInput(idemKey: 'k2', at: DateTime(2026, 10, 15, 10), lines: [line(4000)], customerId: 'c1', customerName: 'Murugan', receivedPaise: 2000));
    final dir = Platform.environment['ASK_PDF_DIR'];
    for (final k in ExportKind.values) {
      final t = await buildExport(d, k);
      if (t.rows.isEmpty) continue;
      final bytes = await encodePdf(t, shopName: shop.name, now: DateTime(2026, 10, 25, 18, 30), shop: shop);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: k.name);
      expect(bytes.length, greaterThan(2000), reason: k.name);
      if (dir != null) {
        Directory(dir).createSync(recursive: true);
        File('$dir/${k.name}.pdf').writeAsBytesSync(bytes);
      }
    }
  });

  test('the product report: product count, stock worth, and the table total agree with the Inventory calculation', () async {
    final d = memoryShop();
    addTearDown(d.close);
    await d.catalog.saveProduct(sampleProduct('Wood screw', price: 1500, cost: 1000, stock: 14000, id: 'p1', gst: 1800), create: true); // worth 140.00
    await d.catalog.saveProduct(sampleProduct('Hinge', price: 4500, cost: 3000, stock: 2500, id: 'p2', gst: 1800), create: true); // 2.5 x 30.00 = 75.00
    await d.catalog.saveProduct(sampleProduct('Out', price: 900, cost: 600, stock: 0, id: 'p3', gst: 1800), create: true);
    final t = await buildExport(d, ExportKind.products);
    final facts = {for (final s in t.summary) s.$1: s.$2};
    expect(facts['Total products'], '3');
    expect(facts['In stock'], '2');
    expect(facts['Out of stock'], '1');
    final v = await d.reports.stockValuation();
    final shown = v.total(v.shown);
    expect(shown, 14000 * 1000 ~/ 1000 + 7500, reason: 'worth by the rule: 140.00 + 75.00 in paise');
    expect(facts['Total stock worth'], 'Rs. 215.00'.replaceFirst('Rs. ', '₹'));
    expect(((t.totalsRow!.last) as Rupees).paise, shown, reason: 'the table total is the Inventory total');
    final col = t.headers.indexOf('Stock worth');
    expect(t.rows.fold<int>(0, (s, r) => s + (r[col] as Rupees).paise), shown, reason: 'the rows add up to the total');
    expect(v.shown, ValuationRule.average);
  });

  test('sales report totals leave out cancelled bills; the GST register totals add up', () async {
    final d = memoryShop();
    addTearDown(d.close);
    await d.catalog.saveProduct(sampleProduct('Wood screw', price: 1500, cost: 1000, stock: 140000, id: 'p1', gst: 1800), create: true);
    BillLineInput line(int q) => BillLineInput(productId: 'p1', name: 'Wood screw', unit: 'pcs', qtyMilli: q, ratePaise: 1500, gstBp: 1800);
    await d.bills.saveBill(SaveBillInput(idemKey: 'a', at: DateTime(2026, 10, 14, 10), lines: [line(2000)]));
    final b = await d.bills.saveBill(SaveBillInput(idemKey: 'b', at: DateTime(2026, 10, 15, 10), lines: [line(4000)]));
    await d.bills.cancelBill(b.id, reason: 'test');
    final s = await buildExport(d, ExportKind.sales);
    expect(s.rows.length, 2, reason: 'a cancelled bill is still listed');
    final liveTotal = s.rows.where((r) => r[8] != 'Cancelled').fold<int>(0, (a, r) => a + (r[4] as Rupees).paise);
    expect((s.totalsRow![4] as Rupees).paise, liveTotal);
    final g = await buildExport(d, ExportKind.gst);
    final cols = [3, 4, 5, 6, 7, 8, 9];
    for (final c in cols) {
      expect((g.totalsRow![c] as Rupees).paise, g.rows.fold<int>(0, (a, r) => a + (r[c] as Rupees).paise), reason: g.headers[c]);
    }
  });
}
