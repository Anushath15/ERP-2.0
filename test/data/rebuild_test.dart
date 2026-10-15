import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/rebuild.dart';
import 'package:erp2/data/repo/self_check.dart';
import 'package:erp2/domain/credit/account.dart';
import 'helpers.dart';

void main() {
  test('Rebuild totals gives back exactly the figures the program kept, from nothing but the raw rows, and fixes damaged ones', () async {
    final d = memoryShop();
    await d.catalog.saveProduct(sampleProduct('SCREW', id: 'p1', price: 12500, cost: 8000, stock: 50000), create: true);
    await d.catalog.saveProduct(sampleProduct('SWITCH', id: 'p2', price: 4500, cost: 3000, stock: 20000), create: true);
    await d.catalog.saveCustomer(sampleCustomer('Murugan', id: 'c1'), create: true);
    await d.catalog.saveCustomer(sampleCustomer('Anbu', id: 'c2'), create: true);
    BillLineInput line(String p, int q, int rate, int cost) => BillLineInput(productId: p, name: p, unit: 'pcs', qtyMilli: q, ratePaise: rate, gstBp: 1800, costPaise: cost);
    var t = DateTime(2026, 10, 1, 10);
    final bills = <SavedBill>[];
    for (var i = 0; i < 12; i++) {
      t = t.add(Duration(hours: 9 + i));
      bills.add(await d.bills.saveBill(SaveBillInput(idemKey: 'k$i', at: t, lines: [line('p1', 1000 * (1 + i % 3), 12500, 8000), line('p2', 2000, 4500, 3000)], customerId: i % 2 == 0 ? 'c1' : (i % 3 == 0 ? 'c2' : null), customerName: i % 2 == 0 ? 'Murugan' : '', receivedPaise: i % 4 == 0 ? 0 : null, payMode: i % 3)));
    }
    await d.ledger.receivePayment(PartyKind.customer, partyId: 'c1', partyName: 'Murugan', amount: 3000, mode: 'upi', at: t);
    await d.ledger.addAdjustment(PartyKind.customer, partyId: 'c1', signedPaise: -500, at: t, reason: 'Discount');
    await d.bills.cancelBill(bills[3].id, reason: 'Wrong item');
    await d.catalog.saveProduct(sampleProduct('SCREW', id: 'p1', price: 12500, cost: 8000, stock: 44000), create: false); // stock edited on the product page

    Future<List<String>> snapshot() async {
      final out = <String>[];
      for (final tbl in ['stock_cache', 'party_balance', 'day_totals', 'product_month', 'counters']) {
        final cols = (await d.db.rows('PRAGMA table_info($tbl)')).map((r) => r.read<String>('name')).toList();
        final rows = await d.db.rows('SELECT * FROM $tbl ORDER BY ${cols.join(',')}');
        out.add(tbl);
        out.addAll([for (final r in rows) cols.map((c) => '${r.data[c]}').join('|')]);
      }
      final run = await d.db.rows('SELECT id, running_paise FROM ledger_entries ORDER BY id');
      out.addAll([for (final r in run) '${r.read<String>('id')}:${r.read<int>('running_paise')}']);
      return out;
    }

    final before = await snapshot();
    expect(await selfCheck(d.db), isEmpty);
    // damage every summary
    await d.db.customStatement('UPDATE stock_cache SET qty_milli = qty_milli + 7');
    await d.db.customStatement('DELETE FROM day_totals WHERE rowid % 2 = 0');
    await d.db.customStatement('UPDATE day_totals SET sales_paise = sales_paise + 1');
    await d.db.customStatement('UPDATE party_balance SET balance_paise = 123456');
    await d.db.customStatement('UPDATE ledger_entries SET running_paise = 0');
    await d.db.customStatement("DELETE FROM product_month WHERE month = '2026-10'");
    await d.db.customStatement("UPDATE counters SET value = 1 WHERE name LIKE 'inv.%'");
    expect(await selfCheck(d.db), isNotEmpty, reason: 'the self-check sees the damage');
    await rebuildSummaries(d.db);
    expect(await selfCheck(d.db, deep: true), isEmpty);
    final after = await snapshot();
    expect(after, before, reason: 'rebuilt from the rows alone, every summary is exactly what the program had kept');
    expect(DataContext.dayOf(t), isNotEmpty);
    await d.close();
  });
}
