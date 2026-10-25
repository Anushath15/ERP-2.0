import 'dart:math';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/purchase_repo.dart';
import 'package:erp2/data/repo/purchase_return_repo.dart';
import 'package:erp2/data/repo/rebuild.dart';
import 'package:erp2/data/repo/return_repo.dart';
import 'package:erp2/data/repo/self_check.dart';
import 'package:erp2/domain/credit/account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What this test proves: after hundreds of random sales (with and without GST in the price, item and bill discounts, round-off, part payment), partial returns,
// purchases (typed with or without GST), purchase returns and payments, EVERY figure still agrees with every other one, to the paisa: each bill and purchase
// adds up from its lines, GST is split exactly, a return never gives back more than was sold, the customer and dealer accounts equal what is unpaid, the stock
// equals the movements, the day totals equal the bills, and the average cost stays between the cheapest and dearest rate paid. The seed is printed on a failure.
void main() {
  for (final seed in [1, 2, 3, 4, 5]) {
    test('random shop, seed $seed: every total agrees with every other', () async {
      final r = Random(seed);
      final d = memoryShop();
      addTearDown(d.close);
      const gsts = [0, 500, 1200, 1800, 2800];
      final pids = <String>[];
      for (var i = 0; i < 10; i++) {
        final id = 'p$i';
        pids.add(id);
        await d.catalog.saveProduct(sampleProduct('ITEM $i', price: 500 + r.nextInt(300000), cost: 300 + r.nextInt(200000), stock: 100000 + r.nextInt(500000), id: id, gst: gsts[r.nextInt(gsts.length)]), create: true);
      }
      for (var i = 0; i < 3; i++) {
        await d.catalog.saveCustomer(sampleCustomer('Cust $i', id: 'c$i', limit: 1000000000), create: true);
        await d.db.exec("INSERT INTO dealers(id, name, created_at, updated_at, device_id) VALUES ('d$i','Dealer $i',1,1,'x')");
      }
      final rates = <String, List<int>>{for (final p in pids) p: [(await d.catalog.product(p))!.costPaise]};
      final bills = <String>[], purchases = <String>[];
      var n = 0;
      DateTime when() => DateTime(2026, 10, 1).add(Duration(minutes: n * 7));

      Future<void> sale() async {
        final lines = <BillLineInput>[];
        for (var k = 0; k < 1 + r.nextInt(5); k++) {
          final p = (await d.catalog.product(pids[r.nextInt(pids.length)]))!;
          lines.add(BillLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: 1 + r.nextInt(12000), ratePaise: 1 + r.nextInt(400000), gstBp: p.gstBp, discountBp: r.nextInt(4) == 0 ? r.nextInt(3000) : 0, costPaise: p.costPaise));
        }
        final cust = r.nextBool() ? 'c${r.nextInt(3)}' : null;
        final saved = await d.bills.saveBill(SaveBillInput(
          idemKey: 'b$n',
          at: when(),
          lines: lines,
          customerId: cust,
          customerName: cust == null ? '' : 'Cust ${cust.substring(1)}',
          pricesIncludeGst: r.nextBool(),
          roundOff: r.nextInt(4) != 0,
          extraDiscountPaise: r.nextInt(6) == 0 ? r.nextInt(50000) : 0,
          extraDiscountBp: r.nextInt(8) == 0 ? r.nextInt(2000) : 0,
          receivedPaise: cust != null && r.nextBool() ? r.nextInt(100000) : null,
        ));
        bills.add(saved.id);
      }

      Future<void> salesReturn() async {
        if (bills.isEmpty) return;
        final id = bills[r.nextInt(bills.length)];
        final ls = await d.db.rows(
            'SELECT l.id, l.qty_milli - COALESCE((SELECT SUM(r.qty_milli) FROM sales_return_lines r WHERE r.bill_line_id = l.id), 0) AS left FROM bill_lines l WHERE l.bill_id = ?', [id]);
        final pick = <String, int>{};
        for (final l in ls) {
          final left = l.read<int>('left');
          if (left > 0 && r.nextBool()) pick[l.read<String>('id')] = r.nextBool() ? left : 1 + r.nextInt(left);
        }
        if (pick.isEmpty) return;
        await d.returns.saveReturn(SaveReturnInput(idemKey: 'r$n', billId: id, at: when(), lines: pick, reason: 'test', keepAsCredit: r.nextBool()));
      }

      Future<void> purchase() async {
        final dealer = 'd${r.nextInt(3)}';
        final lines = <PurchaseLineInput>[];
        final used = <String>{};
        for (var k = 0; k < 1 + r.nextInt(4); k++) {
          final p = (await d.catalog.product(pids[r.nextInt(pids.length)]))!;
          if (!used.add(p.id)) continue;
          final qty = 1 + r.nextInt(30000);
          final typed = 50 + r.nextInt(200000);
          final inclusive = r.nextBool();
          final ex = inclusive ? (typed * 10000 / (10000 + p.gstBp)).round() : typed;
          lines.add(PurchaseLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: qty, ratePaise: ex, gstBp: p.gstBp, grossPaise: inclusive ? (typed * qty / 1000).round() : null));
          rates[p.id]!.add(ex);
        }
        final input = SavePurchaseInput(idemKey: 'pu$n', dealerId: dealer, at: when(), lines: lines, paidPaise: 0, received: r.nextInt(8) != 0);
        final paid = r.nextBool() ? r.nextInt(input.total + 1) : 0;
        final s = await d.purchases.savePurchase(SavePurchaseInput(idemKey: 'pu$n', dealerId: dealer, at: when(), lines: lines, paidPaise: paid, received: input.received));
        purchases.add(s.id);
      }

      Future<void> purchaseReturn() async {
        if (purchases.isEmpty) return;
        final id = purchases[r.nextInt(purchases.length)];
        final ls = await d.db.rows(
            'SELECT l.id, l.product_id, l.qty_milli - COALESCE((SELECT SUM(r.qty_milli) FROM purchase_return_lines r WHERE r.purchase_line_id = l.id), 0) AS left FROM purchase_lines l WHERE l.purchase_id = ?', [id]);
        final pick = <String, int>{};
        for (final l in ls) {
          final left = l.read<int>('left');
          if (left > 0 && r.nextBool()) pick[l.read<String>('id')] = 1 + r.nextInt(left);
        }
        if (pick.isEmpty) return;
        try {
          await d.purchaseReturns.saveReturn(SavePurchaseReturnInput(idemKey: 'pr$n', purchaseId: id, at: when(), lines: pick, reason: 'test', keepAsCredit: r.nextBool()));
        } on StateError {
          // not received yet, or not enough in stock: refused with nothing saved, which is the rule
        }
      }

      Future<void> payment() async {
        final cust = r.nextBool();
        final id = cust ? 'c${r.nextInt(3)}' : 'd${r.nextInt(3)}';
        final bal = await d.ledger.balanceOf(id);
        if (bal <= 0) return;
        await d.ledger.receivePayment(cust ? PartyKind.customer : PartyKind.dealer, partyId: id, partyName: id, amount: 1 + r.nextInt(bal), mode: 'cash', at: when());
      }

      for (n = 0; n < 160; n++) {
        final roll = r.nextInt(10);
        if (roll < 4) {
          await sale();
        } else if (roll < 5) {
          await salesReturn();
        } else if (roll < 7) {
          await purchase();
        } else if (roll < 8) {
          await purchaseReturn();
        } else {
          await payment();
        }
        if (n % 40 == 39) expect(await selfCheck(d.db, deep: true), isEmpty, reason: 'seed $seed after $n operations');
      }
      final why = 'seed $seed';
      // the run really did something of each kind (otherwise passing would mean nothing)
      Future<int> count(String t) => d.db.scalarInt('SELECT COUNT(*) FROM $t');
      expect(await count('bills'), greaterThan(30), reason: why);
      expect(await count('sales_returns'), greaterThan(0), reason: why);
      expect(await count('purchases'), greaterThan(10), reason: why);
      expect(await count('purchase_returns'), greaterThan(0), reason: why);
      expect(await count('ledger_entries'), greaterThan(10), reason: why);
      // ignore: avoid_print
      print('seed $seed: ${await count('bills')} bills, ${await count('sales_returns')} sales returns, ${await count('purchases')} purchases, ${await count('purchase_returns')} purchase returns, ${await count('ledger_entries')} ledger entries');

      // every bill adds up from its lines
      for (final b in await d.db.rows('SELECT * FROM bills')) {
        final id = b.read<String>('id');
        final sum = await d.db.scalarInt('SELECT COALESCE(SUM(total_paise),0) FROM bill_lines WHERE bill_id = ?', [id]);
        final tax = b.read<int>('cgst_paise') + b.read<int>('sgst_paise') + b.read<int>('igst_paise');
        expect(b.read<int>('total_paise'), sum + b.read<int>('round_off_paise'), reason: '$why bill ${b.read<String>('number')}: total = lines + round-off');
        expect(b.read<int>('taxable_paise') + tax, sum, reason: '$why bill ${b.read<String>('number')}: taxable + GST = lines');
        expect((b.read<int>('cgst_paise') - b.read<int>('sgst_paise')).abs(), lessThanOrEqualTo(1), reason: '$why: CGST and SGST are halves');
        expect(b.read<int>('balance_paise'), inInclusiveRange(0, b.read<int>('total_paise')), reason: '$why: the unpaid part is between nothing and the total');
      }
      // never more given back than sold
      for (final b in await d.db.rows('SELECT b.id, b.total_paise, COALESCE((SELECT SUM(total_paise) FROM sales_returns s WHERE s.bill_id = b.id), 0) AS back FROM bills b')) {
        expect(b.read<int>('back'), lessThanOrEqualTo(b.read<int>('total_paise')), reason: '$why: returns of a bill never exceed the bill');
      }
      for (final x in await d.db.rows('SELECT total_paise, taxable_paise, cgst_paise + sgst_paise + igst_paise AS tax, round_off_paise FROM sales_returns')) {
        expect(x.read<int>('taxable_paise') + x.read<int>('tax') + x.read<int>('round_off_paise'), x.read<int>('total_paise'), reason: '$why: a return = taxable + GST + round-off');
      }
      // every purchase adds up
      for (final p in await d.db.rows('SELECT * FROM purchases')) {
        final sum = await d.db.scalarInt('SELECT COALESCE(SUM(total_paise),0) FROM purchase_lines WHERE purchase_id = ?', [p.read<String>('id')]);
        expect(p.read<int>('total_paise'), sum, reason: '$why purchase ${p.read<String>('number')}: total = lines');
        expect(p.read<int>('taxable_paise') + p.read<int>('tax_paise'), sum, reason: '$why: taxable + GST = lines');
      }
      for (final l in await d.db.rows('SELECT total_paise, taxable_paise, tax_paise FROM purchase_lines')) {
        expect(l.read<int>('taxable_paise') + l.read<int>('tax_paise'), l.read<int>('total_paise'), reason: '$why: a purchase line = taxable + GST');
      }
      // the average cost is a real average of rates paid
      for (final p in pids) {
        final avg = (await d.db.scalarInt('SELECT avg_cost_paise FROM products WHERE id = ?', [p]));
        if (avg > 0) {
          final all = rates[p]!;
          expect(avg, inInclusiveRange(all.reduce(min), all.reduce(max)), reason: '$why: $p average cost between the cheapest and dearest rate paid');
        }
      }
      // the summaries equal the raw rows
      final before = (await d.db.rows('SELECT day, bills, sales_paise, taxable_paise, cost_paise, tax_paise, cash_paise, upi_paise, card_paise, credit_paise FROM day_totals ORDER BY day')).map((x) => x.data.values.join('|')).toList();
      final bal = (await d.db.rows('SELECT party_id, balance_paise FROM party_balance ORDER BY party_id')).map((x) => x.data.values.join('|')).toList();
      await rebuildSummaries(d.db);
      expect((await d.db.rows('SELECT day, bills, sales_paise, taxable_paise, cost_paise, tax_paise, cash_paise, upi_paise, card_paise, credit_paise FROM day_totals ORDER BY day')).map((x) => x.data.values.join('|')).toList(), before, reason: '$why: day totals');
      expect((await d.db.rows('SELECT party_id, balance_paise FROM party_balance ORDER BY party_id')).map((x) => x.data.values.join('|')).toList(), bal, reason: '$why: party balances');
      expect(await selfCheck(d.db, deep: true), isEmpty, reason: why);
    });
  }
}
