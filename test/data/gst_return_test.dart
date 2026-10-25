import 'dart:math';
import 'package:archive/archive.dart';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/gst_return_repo.dart';
import 'package:erp2/data/repo/purchase_repo.dart';
import 'package:erp2/data/repo/purchase_return_repo.dart';
import 'package:erp2/data/repo/return_repo.dart';
import 'package:erp2/domain/export/export_table.dart';
import 'package:erp2/domain/gst_uqc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: the GST return figures (GSTR-1 parts, HSN summary, GSTR-3B) of a month agree with each other and with the saved bills, credit notes
// and purchases to the paisa; a registered customer's invoices are separated from the rest; cancelled bills are left out; credit is claimed only on purchases
// from dealers that have a GSTIN; and the files (Excel with a sheet for each part, PDF) are real.
void main() {
  const shopGstin = '33ARKPK1357K1ZO';
  const customerGstin = '33AAACS1234B1Z5';
  const otherStateGstin = '29AABCU9603R1ZX';

  test('GSTIN shape and the unit codes', () {
    expect(looksLikeGstin(shopGstin), isTrue);
    expect(looksLikeGstin(' 33aaacs1234b1z5 '), isTrue);
    expect(looksLikeGstin('33AAACS1234B1Z'), isFalse);
    expect(looksLikeGstin('NOTAGSTIN12345'), isFalse);
    expect(gstinState(shopGstin), '33');
    expect(gstinState(''), '');
    expect(gstUqc('pcs'), 'NOS');
    expect(gstUqc('Mtr'), 'MTR');
    expect(gstUqc('KG'), 'KGS');
    expect(gstUqc('litre'), 'LTR');
    expect(gstUqc('wibble'), 'OTH');
  });

  group('a month of trade', () {
    late AppData d;
    final at = DateTime(2026, 10, 10, 11);
    setUp(() async {
      d = memoryShop();
      await d.catalog.saveProduct(sampleProduct('PVC PIPE', price: 100000, cost: 70000, stock: 1000000, id: 'p18', gst: 1800), create: true);
      await d.catalog.saveProduct(sampleProduct('WIRE', price: 50000, cost: 30000, stock: 1000000, id: 'p12', gst: 1200), create: true);
      await d.catalog.saveProduct(sampleProduct('SEEDS', price: 20000, cost: 10000, stock: 1000000, id: 'p0', gst: 0), create: true);
      await d.db.exec("UPDATE products SET hsn = '39172390' WHERE id = 'p18'");
      await d.db.exec("UPDATE products SET hsn = '85444999' WHERE id = 'p12'");
      await d.catalog.saveCustomer(sampleCustomer('Registered Co', id: 'c1', limit: 100000000), create: true);
      await d.db.exec("UPDATE customers SET gstin = '$customerGstin' WHERE id = 'c1'");
      await d.catalog.saveCustomer(sampleCustomer('Plain Murugan', id: 'c2', limit: 100000000), create: true);
      await d.db.exec("INSERT INTO dealers(id, name, gstin, created_at, updated_at, device_id) VALUES ('dg','Registered Dealer','$otherStateGstin',1,1,'x'), ('dn','No GSTIN Dealer','',1,1,'x')");
    });
    tearDown(() => d.close());
    BillLineInput line(String p, int qty, int rate, int gst) => BillLineInput(productId: p, name: p, unit: 'pcs', qtyMilli: qty, ratePaise: rate, gstBp: gst);

    test('a registered customer\'s invoice: one row per rate; the other sales by rate; a credit note; a cancelled bill is out', () async {
      // Rs 1000 with GST at 18 % -> taxable 847.46, CGST 76.27, SGST 76.27 (the example worked by hand)
      final b2b = await d.bills.saveBill(SaveBillInput(idemKey: 'a', at: at, customerId: 'c1', customerName: 'Registered Co', roundOff: false, lines: [line('p18', 1000, 100000, 1800), line('p12', 2000, 50000, 1200)]));
      await d.bills.saveBill(SaveBillInput(idemKey: 'b', at: at, roundOff: false, lines: [line('p18', 1000, 100000, 1800), line('p0', 1000, 20000, 0)]));
      final gone = await d.bills.saveBill(SaveBillInput(idemKey: 'c', at: at, roundOff: false, lines: [line('p18', 5000, 100000, 1800)]));
      await d.bills.cancelBill(gone.id, reason: 'test');
      // one pipe comes back from the registered customer
      final ls = await d.db.rows('SELECT id FROM bill_lines WHERE bill_id = ? AND product_id = ?', [b2b.id, 'p18']);
      await d.returns.saveReturn(SaveReturnInput(idemKey: 'r', billId: b2b.id, at: at, lines: {ls.single.read<String>('id'): 1000}, reason: 'wrong size'));

      final m = await d.gst.month(at, shopGstin: shopGstin);
      expect(m.b2b.length, 2, reason: 'one row for each rate of the one registered invoice');
      final r18 = m.b2b.firstWhere((r) => r.rateBp == 1800);
      expect((r18.taxable, r18.cgst, r18.sgst, r18.igst), (84746, 7627, 7627, 0));
      expect(r18.gstin, customerGstin);
      expect(m.creditNotes.single.original, b2b.number);
      expect((m.creditNotes.single.taxable, m.creditNotes.single.cgst + m.creditNotes.single.sgst), (84746, 15254));
      // the other sale: 18 % pipe and a nil-rated seed
      expect(m.b2c[1800]!.taxable, 84746);
      expect(m.b2c[0]!.taxable, 20000);
      // all sales less the credit note: 18 % = 2 pipes - 1 returned = 1 pipe
      expect(m.outward[1800]!.taxable, 84746 + 84746 - 84746);
      expect(m.invoices, 3);
      expect(m.cancelled, 1);
      final hsn = m.hsn.values.firstWhere((r) => r.hsn == '39172390');
      expect(hsn.qtyMilli, 1000, reason: '2 sold, 1 back');
      expect(hsn.uqc, 'NOS');
    });

    test('input tax credit: only purchases from a dealer with a GSTIN; an inter-state dealer gives IGST; a return reduces it', () async {
      PurchaseLineInput pl(String p, int qty, int rate, int gst) => PurchaseLineInput(productId: p, name: p, unit: 'pcs', qtyMilli: qty, ratePaise: rate, gstBp: gst);
      final reg = await d.purchases.savePurchase(SavePurchaseInput(idemKey: 'p1', dealerId: 'dg', at: at, lines: [pl('p18', 10000, 50000, 1800)])); // taxable 5000.00, GST 900.00
      await d.purchases.savePurchase(SavePurchaseInput(idemKey: 'p2', dealerId: 'dn', at: at, lines: [pl('p18', 10000, 50000, 1800)])); // no GSTIN: not claimable
      final line = (await d.db.rows('SELECT id FROM purchase_lines WHERE purchase_id = ?', [reg.id])).single.read<String>('id');
      await d.purchaseReturns.saveReturn(SavePurchaseReturnInput(idemKey: 'pr', purchaseId: reg.id, at: at, lines: {line: 2000}, reason: 'damaged')); // 2 of 10 back: GST 180.00
      final m = await d.gst.month(at, shopGstin: shopGstin);
      expect(m.itc[1800]!.igst, 90000 - 18000, reason: 'the other state: all IGST, less the 2 returned');
      expect(m.itc[1800]!.cgst + m.itc[1800]!.sgst, 0);
      expect(m.noItc[1800]!.cgst + m.noItc[1800]!.sgst, 90000, reason: 'the dealer with no GSTIN: tax paid, not claimable');
      final b = gstr3bTable(m);
      final itcRow = b.rows.firstWhere((r) => r[0] == '4(A)(5)');
      expect((itcRow[3] as Rupees).paise, 72000);
    });
  });

  test('random months: GSTR-1 parts, the HSN summary and GSTR-3B all agree with the saved bills and returns, to the paisa', () async {
    for (final seed in [1, 2, 3]) {
      final r = Random(seed);
      final d = memoryShop();
      addTearDown(d.close);
      const rates = [0, 500, 1200, 1800, 2800];
      for (var i = 0; i < 8; i++) {
        await d.catalog.saveProduct(sampleProduct('P$i', price: 1000 + r.nextInt(200000), cost: 500, stock: 100000000, id: 'p$i', gst: rates[r.nextInt(rates.length)], unit: ['pcs', 'mtr', 'kg'][r.nextInt(3)]), create: true);
        if (r.nextBool()) await d.db.exec("UPDATE products SET hsn = '${7000 + r.nextInt(5)}' WHERE id = 'p$i'");
      }
      for (var i = 0; i < 3; i++) {
        await d.catalog.saveCustomer(sampleCustomer('C$i', id: 'c$i', limit: 1000000000), create: true);
        if (i == 0) await d.db.exec("UPDATE customers SET gstin = '$customerGstin' WHERE id = 'c0'");
      }
      final bills = <String>[];
      for (var n = 0; n < 60; n++) {
        final lines = <BillLineInput>[];
        for (var k = 0; k < 1 + r.nextInt(4); k++) {
          final p = (await d.catalog.product('p${r.nextInt(8)}'))!;
          lines.add(BillLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: 1 + r.nextInt(9000), ratePaise: 1 + r.nextInt(300000), gstBp: p.gstBp, discountBp: r.nextInt(5) == 0 ? r.nextInt(2500) : 0));
        }
        final cust = r.nextInt(3) == 0 ? 'c${r.nextInt(3)}' : null;
        final s = await d.bills.saveBill(SaveBillInput(idemKey: 'b$n', at: DateTime(2026, 10, 1 + r.nextInt(28), 10), lines: lines, customerId: cust, customerName: cust ?? '', pricesIncludeGst: r.nextBool(), extraDiscountPaise: r.nextInt(7) == 0 ? r.nextInt(30000) : 0));
        bills.add(s.id);
        if (r.nextInt(12) == 0) await d.bills.cancelBill(s.id, reason: 'x');
      }
      for (var n = 0; n < 15; n++) {
        final id = bills[r.nextInt(bills.length)];
        if ((await d.db.scalarInt('SELECT cancelled FROM bills WHERE id = ?', [id])) == 1) continue;
        final ls = await d.db.rows('SELECT l.id, l.qty_milli - COALESCE((SELECT SUM(x.qty_milli) FROM sales_return_lines x WHERE x.bill_line_id = l.id), 0) AS left FROM bill_lines l WHERE l.bill_id = ?', [id]);
        final pick = <String, int>{for (final l in ls) if (l.read<int>('left') > 0 && r.nextBool()) l.read<String>('id'): 1 + r.nextInt(l.read<int>('left'))};
        if (pick.isNotEmpty) await d.returns.saveReturn(SaveReturnInput(idemKey: 'r$n', billId: id, at: DateTime(2026, 10, 1 + r.nextInt(28), 15), lines: pick, reason: 't'));
      }

      final m = await d.gst.month(DateTime(2026, 10, 15), shopGstin: shopGstin);
      // truth, straight from the saved rows
      final soldTaxable = await d.db.scalarInt("SELECT COALESCE(SUM(l.taxable_paise),0) FROM bill_lines l JOIN bills b ON b.id = l.bill_id WHERE b.cancelled = 0");
      final soldTax = await d.db.scalarInt("SELECT COALESCE(SUM(l.tax_paise),0) FROM bill_lines l JOIN bills b ON b.id = l.bill_id WHERE b.cancelled = 0");
      final soldTotal = await d.db.scalarInt("SELECT COALESCE(SUM(l.total_paise),0) FROM bill_lines l JOIN bills b ON b.id = l.bill_id WHERE b.cancelled = 0");
      final backTaxable = await d.db.scalarInt('SELECT COALESCE(SUM(taxable_paise),0) FROM sales_return_lines');
      final backTax = await d.db.scalarInt('SELECT COALESCE(SUM(tax_paise),0) FROM sales_return_lines');
      final backAmount = await d.db.scalarInt('SELECT COALESCE(SUM(amount_paise),0) FROM sales_return_lines');
      final why = 'seed $seed';
      expect(m.b2b.isNotEmpty, isTrue, reason: why);
      // outward = all sales less all credit notes
      expect(m.outward.values.fold<int>(0, (s, x) => s + x.taxable), soldTaxable - backTaxable, reason: '$why: outward taxable');
      expect(m.outward.values.fold<int>(0, (s, x) => s + x.tax), soldTax - backTax, reason: '$why: outward tax');
      // GSTR-1: B2B + B2C - credit notes to registered = outward
      final regTaxable = m.b2b.fold<int>(0, (s, x) => s + x.taxable) - m.creditNotes.fold<int>(0, (s, x) => s + x.taxable);
      final regTax = m.b2b.fold<int>(0, (s, x) => s + x.cgst + x.sgst + x.igst) - m.creditNotes.fold<int>(0, (s, x) => s + x.cgst + x.sgst + x.igst);
      expect(regTaxable + m.b2c.values.fold<int>(0, (s, x) => s + x.taxable), soldTaxable - backTaxable, reason: '$why: B2B + B2C taxable');
      expect(regTax + m.b2c.values.fold<int>(0, (s, x) => s + x.tax), soldTax - backTax, reason: '$why: B2B + B2C tax');
      // HSN summary
      expect(m.hsn.values.fold<int>(0, (s, x) => s + x.totals.taxable), soldTaxable - backTaxable, reason: '$why: HSN taxable');
      expect(m.hsn.values.fold<int>(0, (s, x) => s + x.totals.tax), soldTax - backTax, reason: '$why: HSN tax');
      expect(m.hsn.values.fold<int>(0, (s, x) => s + x.value), soldTotal - backAmount, reason: '$why: HSN value');
      // GSTR-3B 3.1 equals the outward figures
      final b = gstr3bTable(m);
      final a = b.rows.firstWhere((x) => x[0] == '3.1(a)'), c = b.rows.firstWhere((x) => x[0] == '3.1(c)');
      expect((a[2] as Rupees).paise + (c[2] as Rupees).paise, soldTaxable - backTaxable, reason: '$why: 3B taxable');
      expect((a[3] as Rupees).paise + (a[4] as Rupees).paise + (a[5] as Rupees).paise, soldTax - backTax, reason: '$why: 3B tax');
      expect((c[3] as Rupees).paise + (c[4] as Rupees).paise + (c[5] as Rupees).paise, 0, reason: '$why: nil-rated sales carry no tax');
      // CGST and SGST are halves in every row
      for (final x in [...m.b2b, ...m.creditNotes]) {
        expect((x.cgst - x.sgst).abs(), lessThanOrEqualTo(1), reason: why);
      }
    }
  });

  test('the files are real: Excel has a sheet for each part, PDF is a PDF', () async {
    final d = memoryShop();
    addTearDown(d.close);
    await d.catalog.saveProduct(sampleProduct('PVC PIPE', price: 100000, cost: 70000, stock: 1000000, id: 'p18', gst: 1800), create: true);
    await d.bills.saveBill(SaveBillInput(idemKey: 'a', at: DateTime(2026, 10, 10), lines: [const BillLineInput(productId: 'p18', name: 'PVC PIPE', unit: 'pcs', qtyMilli: 1000, ratePaise: 100000, gstBp: 1800)]));
    final m = await d.gst.month(DateTime(2026, 10, 1), shopGstin: shopGstin);
    final tables = gstr1Tables(m);
    expect(tables.map((t) => t.name), ['GSTR-1 B2B invoices', 'GSTR-1 B2C by rate', 'GSTR-1 Credit notes', 'HSN summary', 'GSTR-1 Documents issued']);
    final xlsx = encodeXlsxBook(tables);
    final zip = ZipDecoder().decodeBytes(xlsx);
    expect(zip.files.where((f) => f.name.startsWith('xl/worksheets/sheet')).length, 5);
    final wb = String.fromCharCodes(zip.files.firstWhere((f) => f.name == 'xl/workbook.xml').content as List<int>);
    expect(wb, contains('GSTR-1 B2B invoices'));
    expect(wb, contains('HSN summary'));
  });
}
