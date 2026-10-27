import 'package:archive/archive.dart';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/audit_repo.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/return_repo.dart';
import 'package:erp2/domain/export/export_table.dart';
import 'package:erp2/features/export/export_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove (figures worked by hand): the auditor pack lists EVERY bill of the period (cancelled ones marked and never counted),
// the totals equal the sum of the bills to the paisa, GST by rate is sales less credit notes, the HSN summary and credit notes agree, a bill
// outside the period is not in it, a missing bill number is reported, and the Excel (a sheet for each part) and the PDF are real files.
void main() {
  late AppData d;
  final oct = DateTime(2026, 10, 10, 11);
  setUp(() async {
    d = memoryShop();
    await d.catalog.saveProduct(sampleProduct('PVC PIPE', price: 100000, cost: 70000, stock: 1000000, id: 'p18', gst: 1800), create: true);
    await d.catalog.saveProduct(sampleProduct('SEEDS', price: 20000, cost: 10000, stock: 1000000, id: 'p0', gst: 0), create: true);
    await d.db.exec("UPDATE products SET hsn = '39172390' WHERE id = 'p18'");
    await d.catalog.saveCustomer(sampleCustomer('Registered Co', id: 'c1', limit: 100000000), create: true);
    await d.db.exec("UPDATE customers SET gstin = '33AAACS1234B1Z5' WHERE id = 'c1'");
  });
  tearDown(() => d.close());
  BillLineInput line(String p, int qty, int rate, int gst) => BillLineInput(productId: p, name: p, unit: 'pcs', qtyMilli: qty, ratePaise: rate, gstBp: gst);

  Future<AuditPack> pack(DateTime from, DateTime to) => d.audit.pack(from, to, label: 'Test period', shopName: 'Senthil', shopGstin: '33ARKPK1357K1ZO');
  ExportTable table(AuditPack p, String name) => p.tables.firstWhere((t) => t.name == name);
  String cell(Object? v) => plainCell(v);
  Map<String, String> summaryOf(AuditPack p) => {for (final r in table(p, 'Summary').rows) r[0].toString(): cell(r[1])};

  test('every bill is listed; totals equal the bills; cancelled marked and not counted; other months left out', () async {
    // Rs 1000 incl. 18% GST: taxable 847.46, CGST 76.27, SGST 76.27
    await d.bills.saveBill(SaveBillInput(idemKey: 'a', at: oct, customerId: 'c1', customerName: 'Registered Co', roundOff: false, lines: [line('p18', 1000, 100000, 1800)]));
    await d.bills.saveBill(SaveBillInput(idemKey: 'b', at: oct.add(const Duration(days: 1)), roundOff: false, lines: [line('p0', 2000, 20000, 0)]));
    final gone = await d.bills.saveBill(SaveBillInput(idemKey: 'c', at: oct.add(const Duration(days: 2)), roundOff: false, lines: [line('p18', 5000, 100000, 1800)]));
    await d.bills.cancelBill(gone.id, reason: 'wrong customer');
    await d.bills.saveBill(SaveBillInput(idemKey: 'z', at: DateTime(2026, 11, 3, 10), roundOff: false, lines: [line('p0', 1000, 20000, 0)]));

    final p = await pack(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
    final reg = table(p, 'Sales register');
    expect(reg.rows.length, 3, reason: 'the November bill is not in October');
    expect(cell(reg.rows[0][3]), '33AAACS1234B1Z5');
    expect(cell(reg.rows[1][2]), 'Walk-in customer');
    expect(cell(reg.rows[2][15]), 'Cancelled');
    final totals = reg.totalsRow!;
    expect([cell(totals[5]), cell(totals[6]), cell(totals[7]), cell(totals[8]), cell(totals[11])], ['1247.46', '76.27', '76.27', '0.00', '1400.00'], reason: 'the cancelled bill adds nothing: taxable 847.46 + 400.00');
    expect(reg.totalsRow![4], 2, reason: 'items of the two counted bills');
    final cancelled = table(p, 'Cancelled bills');
    expect(cancelled.rows.single[0], gone.number);
    expect(cell(cancelled.rows.single[6]), 'wrong customer');
    final s = summaryOf(p);
    expect(s['Bills (not cancelled)'], '2');
    expect(s['Cancelled bills (listed, not counted)'], '1');
    expect(s['Total of bills'], '1400.00');
  });

  test('items, GST by rate (sales less credit notes), HSN and credit notes agree', () async {
    final a = await d.bills.saveBill(SaveBillInput(idemKey: 'a', at: oct, customerId: 'c1', customerName: 'Registered Co', roundOff: false, lines: [line('p18', 2000, 100000, 1800), line('p0', 1000, 20000, 0)]));
    final ln = (await d.db.rows('SELECT id FROM bill_lines WHERE bill_id = ? AND product_id = ?', [a.id, 'p18'])).single.read<String>('id');
    await d.returns.saveReturn(SaveReturnInput(idemKey: 'r', billId: a.id, at: oct.add(const Duration(days: 3)), lines: {ln: 1000}, reason: 'wrong size'));
    final p = await pack(DateTime(2026, 10, 1), DateTime(2026, 11, 1));

    final items = table(p, 'Bill items');
    expect(items.rows.length, 2);
    expect(items.rows.map((r) => r[4].toString()).toSet(), {'39172390', '8302'}, reason: 'the HSN of each product (8302 is the default of a product with none set)');
    // sales: 2 x 1000 incl. GST -> taxable 1694.92, tax 305.08 (CGST 152.54, SGST 152.54); the return takes back one pipe: taxable 847.46, tax 152.54
    final r18 = table(p, 'GST by rate').rows.firstWhere((r) => r[0] == '18');
    expect([for (final i in [1, 2, 3, 5, 6, 7]) cell(r18[i])], ['1694.92', '152.54', '152.54', '847.46', '152.54', '847.46']);
    final h = table(p, 'HSN summary').rows.firstWhere((r) => r[0] == '39172390');
    expect([cell(h[2]), cell(h[3]), cell(h[5]), cell(h[6])], ['1', '1000.00', '847.46', '152.54'], reason: 'sold 2, returned 1');
    final note = table(p, 'Credit notes').rows.single;
    expect(note[2], a.number);
    expect(cell(note[5]), '847.46');
    expect(cell(note[10]), '1000.00');
    final s = summaryOf(p);
    expect(s['Net taxable value after credit notes'], '1047.46', reason: '1694.92 + 200.00 (0% seeds) sold, less 847.46 returned');
    expect(s['Credit notes (sales returns)'], '1');
  });

  test('a missing bill number is reported; a clean run says none', () async {
    for (var i = 0; i < 3; i++) {
      await d.bills.saveBill(SaveBillInput(idemKey: 'k$i', at: oct.add(Duration(hours: i)), roundOff: false, lines: [line('p0', 1000, 20000, 0)]));
    }
    var p = await pack(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
    expect(table(p, 'Bill number check').rows.single[4], 0);
    expect(table(p, 'Bill number check').rows.single[5], 'none');
    await d.db.exec('DELETE FROM bill_lines WHERE bill_id = (SELECT id FROM bills ORDER BY seq LIMIT 1 OFFSET 1)');
    await d.db.exec('DELETE FROM bills WHERE id = (SELECT id FROM bills ORDER BY seq LIMIT 1 OFFSET 1)');
    p = await pack(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
    final row = table(p, 'Bill number check').rows.single;
    expect(row[4], 1);
    expect(row[3], 2);
  });

  test('an empty period still gives every table; the files are real (Excel with a sheet for each part, PDF)', () async {
    await d.bills.saveBill(SaveBillInput(idemKey: 'a', at: oct, roundOff: false, lines: [line('p0', 1000, 20000, 0)]));
    for (final range in [(DateTime(2025, 4, 1), DateTime(2026, 4, 1)), (DateTime(2026, 10, 1), DateTime(2026, 11, 1))]) {
      final p = await pack(range.$1, range.$2);
      expect(p.tables.map((t) => t.name), ['Summary', 'Sales register', 'Bill items', 'GST by rate', 'HSN summary', 'Credit notes', 'Cancelled bills', 'Purchases', 'Bill number check']);
      final xlsx = encodeXlsxBook(p.tables);
      final names = ZipDecoder().decodeBytes(xlsx).files.map((f) => f.name).toSet();
      expect(names.where((n) => n.startsWith('xl/worksheets/sheet')).length, 9);
      final pdf = await encodePdfBook(p.tables, title: 'Auditor pack', shopName: 'Senthil', now: DateTime(2026, 10, 27), sectionTitles: true, headerLines: p.headerLines);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    }
  });
}
