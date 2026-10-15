import 'dart:convert';
import 'package:erp2/import/erp1/checksum.dart';
import 'package:erp2/import/erp1/convert.dart';
import 'package:erp2/import/erp1/plan.dart';
import 'package:erp2/import/erp1/report.dart';
import 'package:erp2/data/importer/erp1_writer.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/self_check.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/import/synthetic.dart';
import '../data/helpers.dart';

Erp1Plan planOf(Map<String, Object?> m) => Erp1Plan.parse(jsonEncode(m));

Map<String, Object?> backup(Map<String, Object?> data) => {'_metadata': {'format': 'senthil_erp_full_backup_v2', 'timestamp': '2025-07-01T10:00:00.000Z'}, 'data': data};

void main() {
  group('reading ERP 1 values', () {
    test('rupees become paise, with rounding reported', () {
      final f = Findings();
      expect(paise(1234.5, f, 'x'), 123450);
      expect(paise('1,200.00', f, 'x'), 120000);
      expect(f.repaired, isEmpty);
      expect(paise(10.123, f, 'x'), 1012);
      expect(f.repaired, hasLength(1));
      expect(paise(0.1 + 0.2, Findings(), 'x'), 30);
    });
    test('nonsense numbers are never accepted', () {
      final f = Findings();
      expect(paise('abc', f, 'x', missing: -1), -1);
      expect(paise(double.nan, f, 'x', missing: -1), -1);
      expect(paise(double.infinity, f, 'x', missing: -1), -1);
      final g = Findings();
      paise(1e12, g, 'x');
      expect(g.rejected, isNotNull);
      expect(paise(-5, Findings(), 'x'), 0, reason: 'negative where not allowed reads as zero');
      expect(paise(-5, Findings(), 'x', negativeOk: true), -500);
    });
    test('quantities become milli-units', () {
      expect(milli(2.5, Findings(), 'q'), 2500);
      expect(milli(0.001, Findings(), 'q'), 1);
    });
    test('dates: India time, date alone is noon, impossible dates refused', () {
      expect(moment('2025-03-31T20:00:00.000Z')!.day, '2025-04-01', reason: '20:00 UTC is 01:30 the next day in India');
      expect(moment('2025-03-31')!.day, '2025-03-31');
      expect(moment('2025-02-31'), isNull);
      expect(moment('1999-01-01'), isNull);
      expect(moment('hello'), isNull);
      expect(moment(null), isNull);
      expect(moment('2025-06-01T10:00:00')!.day, '2025-06-01');
    });
    test('rupee formatting uses Indian grouping', () {
      expect(rupees(12345678901), '₹12,34,56,789.01');
      expect(rupees(-150), '-₹1.50');
    });
  });

  group('the synthetic shop', () {
    final syn = Synthetic(bills: 600, products: 80, customers: 40, dealers: 6);
    final raw = syn.build();
    final plan = planOf(raw);

    test('everything real is read; every planted flaw is reported, none crashes', () {
      expect(plan.read['erp_sales_invoices'], 601); // 600 + the duplicate planted at the end
      final rejected = plan.issues.buckets.values.where((b) => b.kind == IssueKind.rejected).map((b) => b.reason).join('|');
      expect(rejected, contains('date is missing'));
      expect(rejected, contains('same bill number appears twice'));
      expect(rejected, contains('customer is not in the customer list'));
      expect(rejected, contains('amount is not above zero'));
      expect(plan.unmappedKeys.keys, contains('erp_mystery_list'));
      expect(plan.unmappedKeys.keys, contains('erp_daily_closings'));
      final notes = plan.issues.buckets.values.map((b) => b.reason).join('|');
      expect(notes, contains('placeholder'));
      expect(notes, contains('negative'));
      expect(notes, contains('more than 2 decimals'));
      expect(notes, contains('barcode was already used'));
      expect(notes, contains('amount paid was more than the total'));
      expect(plan.bills.length, 599, reason: '600 minus the unreadable date; the unreadable total is repaired from the lines; the duplicate is dropped');
    });

    test('the report names the three stock values and does not choose one', () {
      final t = buildReport(plan);
      expect(t, contains('DRY RUN'));
      expect(t, contains('Average cost (recommended)'));
      expect(t, contains('Latest buying price'));
      expect(t, contains('Selling price'));
      expect(t, contains('NOT SET'));
      expect(t, contains('COST NOT SET'));
      expect(t, contains('NEGATIVE STOCK'));
      expect(t, contains('This month'));
      expect(t, contains('Old bill no.'));
      expect(t, contains('Example from your own list'));
    });

    test('the own checksum of the file is re-computed the way ERP 1 does it; any change is caught', () {
      expect(plan.checksum, ChecksumResult.ok);
      expect(buildReport(plan), contains('CHECKED AND CORRECT'));
      final edited = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      ((edited['data'] as Map<String, dynamic>)['erp_sales_invoices'] as List<dynamic>)[10]['totalAmount'] = 1.0;
      final p2 = Erp1Plan.parse(jsonEncode(edited));
      expect(p2.checksum, ChecksumResult.mismatch);
      expect(buildReport(p2), contains('DOES NOT MATCH'));
      expect(planOf(backup({})).checksum, ChecksumResult.notPresent);
    });

    test('canonical text follows JavaScript: whole-number doubles have no .0, keys sorted, nested order kept', () {
      expect(canonicalText({'b': [1, 2.0, 'x"y'], 'a': {'z': 1.5, 'y': null}}), '[["a",{"z":1.5,"y":null}],["b",[1,2,"x\\"y"]]]');
    });

    test('a dry run needs no database at all (planning is pure)', () {
      expect(plan.products, isNotEmpty);
    });

    test('write: every total read back from the database equals the backup', () async {
      final d = memoryShop();
      final res = await writePlan(d, plan, nowMs: 1760000000000);
      expect(res.mismatches, isEmpty, reason: res.mismatches.join('\n'));
      expect(res.verified, isTrue);
      expect(await selfCheck(d.db), isEmpty, reason: 'the program\'s own consistency check passes on imported data');
      // each customer's balance is exactly ERP 1's "outstanding"
      for (final c in plan.customers.values) {
        final got = await d.db.scalarInt('SELECT COALESCE((SELECT balance_paise FROM party_balance WHERE party_id = ?), 0)', [c.id]);
        expect(got, c.outstandingPaise, reason: c.name);
      }
      // every stock figure is exactly ERP 1's "stock"
      for (final x in plan.products.values.where((x) => !x.placeholder)) {
        final got = await d.db.scalarInt('SELECT COALESCE((SELECT qty_milli FROM stock_cache WHERE product_id = ?), 0)', [x.id]);
        expect(got, x.stockMilli, reason: x.name);
      }
      // old bill numbers are kept and searchable
      final found = await d.bills.page(search: 'INV-2425-000010');
      expect(found.map((b) => b.number), contains('INV-2425-000010'));
      expect(await d.db.scalarInt("SELECT COUNT(*) FROM bills WHERE old_bill_no = 'INV-2425-000010'"), 1);
      // a cancelled bill is kept, marked, and not counted in sales
      expect(await d.db.scalarInt('SELECT COUNT(*) FROM bill_cancellations'), plan.bills.where((b) => b.cancelled).length);
    });

    test('importing the same file again changes nothing', () async {
      final d = memoryShop();
      await writePlan(d, plan, nowMs: 1760000000000);
      Future<List<int>> counts() async => [
            for (final t in ['products', 'customers', 'dealers', 'bills', 'bill_lines', 'ledger_entries', 'payments', 'stock_movements', 'records', 'estimations', 'party_bills', 'categories'])
              await d.db.scalarInt('SELECT COUNT(*) FROM $t')
          ];
      final first = await counts();
      final sums = await d.db.scalarInt('SELECT SUM(balance_paise) FROM party_balance');
      final again = await writePlan(d, planOf(raw), nowMs: 1760000999000);
      expect(again.alreadyImported, isTrue);
      expect(await counts(), first);
      expect(await d.db.scalarInt('SELECT SUM(balance_paise) FROM party_balance'), sums);
      expect(again.verified, isTrue);
    });

    test('a database that already has shop data is refused', () async {
      final d = memoryShop();
      await d.catalog.saveProduct(sampleProduct('Existing', id: 'p-existing'), create: true);
      await expectLater(writePlan(d, plan, nowMs: 1), throwsA(isA<ImportInputError>()));
      expect(await d.db.scalarInt('SELECT COUNT(*) FROM bills'), 0);
    });

    test('a failure half-way leaves nothing behind (one transaction)', () async {
      final d = memoryShop();
      await d.db.exec("CREATE TRIGGER boom BEFORE INSERT ON payments BEGIN SELECT RAISE(ABORT, 'boom'); END");
      await expectLater(writePlan(d, plan, nowMs: 1), throwsA(anything));
      for (final t in ['products', 'customers', 'bills', 'bill_lines', 'ledger_entries', 'stock_movements']) {
        expect(await d.db.scalarInt('SELECT COUNT(*) FROM $t'), 0, reason: t);
      }
    });
  });

  group('hostile and corrupt input', () {
    void bad(String name, String text) => test(name, () {
          expect(() => Erp1Plan.parse(text), throwsA(isA<ImportInputError>()));
        });
    bad('not JSON', 'this is not json {');
    bad('empty file', '');
    bad('a list at the top', '[1,2,3]');
    bad('a number', '42');
    bad('no data section', '{"_metadata": {}}');
    bad('data is a list', '{"data": []}');
    bad('truncated backup', '{"data": {"erp_products": [{"id": "a", "name": "b"');

    test('every list the wrong type or full of junk is survived', () {
      final p = planOf(backup({
        'erp_products': 'text',
        'erp_customers': {'__rawText': 'garbage'},
        'erp_sales_invoices': [1, 'x', null, [], {}],
        'erp_credit_payments': [
          {'customerId': 7, 'amount': {}}
        ],
        'erp_stock_adjustments': [
          {'productId': [], 'qty': 'many'}
        ],
        'erp_purchases': [
          {'id': 5, 'items': 'none'}
        ],
        'erp_expenses': [
          {'amount': 'NaN', 'date': 3}
        ],
        'erp_settings': 'nope',
      }));
      expect(p.bills, isEmpty);
      expect(p.products, isEmpty);
      expect(p.issues.count(IssueKind.rejected), greaterThan(5));
    });

    test('huge, negative, infinite and control-character values', () {
      final big = 'x' * 5000000;
      final p = planOf(backup({
        'erp_products': [
          {'id': 'a', 'name': big, 'price': 1e300, 'stock': -1e300},
          {'id': 'b', 'name': 'ok\u0000\u0007name', 'price': -5, 'stock': 1e12, 'barcode': 'z' * 500},
          {'id': 'c', 'name': 'fine', 'price': 12.5, 'stock': 3}
        ],
      }));
      expect(p.products['c']!.pricePaise, 1250);
      expect(p.products.containsKey('b'), isFalse, reason: 'stock 1e12 is out of range');
      if (p.products.containsKey('a')) expect(p.products['a']!.name.length, lessThanOrEqualTo(200));
    });

    test('dates in the far past and future and impossible days are rejected', () {
      final p = planOf(backup({
        'erp_sales_invoices': [
          {'id': 'A', 'date': '1850-01-01', 'totalAmount': 10},
          {'id': 'B', 'date': '2999-01-01', 'totalAmount': 10},
          {'id': 'C', 'date': '2025-13-01', 'totalAmount': 10},
          {'id': 'D', 'date': '2025-04-31', 'totalAmount': 10},
          {'id': 'E', 'date': '2025-04-30', 'totalAmount': 10, 'items': []}
        ],
      }));
      expect(p.bills.map((b) => b.oldNo), ['E']);
    });

    test('negative and absurd money on a bill', () {
      final p = planOf(backup({
        'erp_sales_invoices': [
          {'id': 'N', 'date': '2025-04-30', 'totalAmount': -50},
          {'id': 'H', 'date': '2025-04-30', 'totalAmount': 1e15},
          {'id': 'OK', 'date': '2025-04-30', 'totalAmount': 100, 'amountPaid': 40}
        ],
      }));
      expect(p.bills.map((b) => b.oldNo), ['OK']);
      expect(p.bills.single.balance, 6000);
    });

    test('a very deeply nested file does not crash the program', () {
      final deep = '${'[' * 200000}${']' * 200000}';
      expect(() => Erp1Plan.parse('{"data": {"erp_products": $deep}}'), anyOf(throwsA(isA<ImportInputError>()), returnsNormally));
    });

    test('a hundred thousand bad rows are counted, not stored one by one', () {
      final rows = List.generate(100000, (i) => {'id': 'X$i', 'name': ''});
      final p = planOf(backup({'erp_products': rows}));
      expect(p.issues.count(IssueKind.rejected, 'products'), 100000);
      expect(p.issues.buckets.length, lessThan(20));
      expect(p.issues.buckets.values.every((b) => b.examples.length <= IssueLog.maxExamples), isTrue);
    });
  });

  group('how balances and stock are made to agree', () {
    test('a customer with unpaid bills and a payment gets exactly their ERP 1 balance, and the sale cuts stock once', () async {
      final p = planOf(backup({
        'erp_products': [
          {'id': 'P1', 'name': 'Pipe', 'price': 100, 'buyingPrice': 60, 'stock': 8, 'taxRate': 18}
        ],
        'erp_customers': [
          {'id': 'C1', 'name': 'Ravi', 'outstanding': 150.0}
        ],
        'erp_sales_invoices': [
          {
            'id': 'B1', 'date': '2025-05-01T10:00:00Z', 'customerId': 'C1', 'totalAmount': 200.0, 'amountPaid': 50.0, 'paymentMode': 'Credit',
            'items': [
              {'productId': 'P1', 'qty': 2, 'price': 100, 'taxRate': 18, 'total': 200}
            ]
          }
        ],
        'erp_credit_payments': [
          {'id': 'CP1', 'customerId': 'C1', 'amount': 25, 'date': '2025-05-10'}
        ],
      }));
      final d = memoryShop();
      final r = await writePlan(d, p, nowMs: 1);
      expect(r.mismatches, isEmpty);
      // 150 owed in ERP 1; bill left 150 unpaid; payment -25; so the residual opening entry is +25
      expect(p.openingCustomer['C1'], 2500);
      expect(await d.db.scalarInt("SELECT balance_paise FROM party_balance WHERE party_id = 'e1-cust-C1'"), 15000);
      // ERP 1 says 8 in stock now; the sale of 2 is a movement; opening is 10 so that the total is 8
      expect(p.openingStock['P1'], 10000);
      expect(await d.db.scalarInt("SELECT qty_milli FROM stock_cache WHERE product_id = 'e1-prod-P1'"), 8000);
      expect(await d.db.scalarInt('SELECT COUNT(*) FROM outbox'), 0, reason: 'nothing is queued for upload by an import');
    });
  });

  Map<String, Object?> ramShop(String billId) => backup({
        'erp_products': [
          {'id': 'P1', 'name': 'Pipe', 'price': 110, 'buyingPrice': 60, 'stock': 5}
        ],
        'erp_customers': [
          {'id': 'C1', 'name': 'Ram', 'outstanding': 0}
        ],
        'erp_sales_invoices': [
          {
            'id': billId, 'date': '2025-05-01T10:00:00Z', 'customerId': 'C1', 'totalAmount': 110.0, 'amountPaid': 50.0, 'paymentMode': 'UPI',
            'items': [
              {'productId': 'P1', 'qty': 1, 'price': 110, 'taxRate': 18, 'total': 110}
            ]
          }
        ],
      });

  test('the one correction the owner named is applied, listed in the report and written to the audit record', () async {
    final p = planOf(ramShop('INV-2627-000001'));
    expect(p.bills.single.balance, 0);
    expect(p.bills.single.received, 11000);
    expect(p.corrections.single.billOldNo, 'INV-2627-000001');
    expect(p.decisions, isEmpty);
    expect(buildReport(p), contains('APPLIED (named by the owner)'));
    final d = memoryShop();
    final r = await writePlan(d, p, nowMs: 1);
    expect(r.mismatches, isEmpty);
    expect(await d.db.scalarInt('SELECT COALESCE(SUM(balance_paise),0) FROM party_balance'), 0);
    expect(await d.db.scalarInt("SELECT COUNT(*) FROM audit WHERE what LIKE 'Corrected during import: bill INV-2627-000001%'"), 1);
  });

  test('any other shortfall is NOT changed: it stays as ERP 1 recorded it and is listed as needing a decision from the owner', () async {
    final p = planOf(ramShop('INV-OTHER-1'));
    expect(p.corrections, isEmpty);
    expect(p.bills.single.balance, 6000, reason: 'the bill is left exactly as ERP 1 had it');
    expect(p.decisions.single.customer, 'Ram');
    expect(p.decisions.single.differencePaise, 6000);
    expect(p.decisions.single.bills.single, contains('INV-OTHER-1'));
    final t = buildReport(p);
    expect(t, contains('NEEDS A DECISION FROM THE OWNER'));
    expect(t, contains('Ram'));
    final d = memoryShop();
    final r = await writePlan(d, p, nowMs: 1);
    expect(r.mismatches, isEmpty, reason: 'the customer balance still equals the ERP 1 figure (through an opening entry)');
    expect(await d.db.scalarInt('SELECT COUNT(*) FROM audit'), 0);
  });
}
