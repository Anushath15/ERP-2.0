import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/domain/credit/account.dart';
import 'package:erp2/domain/models.dart';
import 'helpers.dart';

// SECURITY: text typed by a person (a search, a name, a note) can never change what a statement does.
void main() {
  const evil = [
    "'; DROP TABLE bills; --",
    "' OR 1=1 --",
    '" OR ""="',
    "x'); DELETE FROM customers; --",
    '%',
    '_',
    r'\',
    r'\%',
    '*',
    'NEAR(',
    'a" b',
    "Robert'); DROP TABLE products;--",
    'ünïcödé ₹ 😀',
    '\u0000',
  ];

  test('searching products, customers, bills and balances with hostile text neither fails nor returns everything, and nothing is damaged', () async {
    final d = memoryShop();
    await d.catalog.saveProduct(sampleProduct('1/2" WOOD SCREW', id: 'p1'), create: true);
    await d.catalog.saveCustomer(sampleCustomer("D'Souza & Sons", id: 'c1'), create: true);
    final before = [await d.catalog.productCount(), await d.catalog.customerCount(), await d.bills.count()];
    for (final q in evil) {
      expect((await d.catalog.searchProducts(q)).length, lessThanOrEqualTo(1), reason: q);
      expect((await d.catalog.searchCustomers(q)).length, lessThanOrEqualTo(1), reason: q);
      expect(await d.bills.page(search: q), isEmpty);
      await d.ledger.balances(PartyKind.customer, search: q, onlyOwing: false);
    }
    expect([await d.catalog.productCount(), await d.catalog.customerCount(), await d.bills.count()], before);
    final tables = (await d.db.rows("SELECT name FROM sqlite_master WHERE type = 'table'")).map((r) => r.read<String>('name')).toSet();
    expect(tables, containsAll(['bills', 'products', 'customers', 'ledger_entries']));
    expect((await d.catalog.searchCustomers("D'Souza")).single.name, "D'Souza & Sons", reason: 'an apostrophe in a real name is just a letter');
    await d.close();
  });

  test('a customer GST number is optional and is saved, changed and read back', () async {
    final d = memoryShop();
    await d.catalog.saveCustomer(const Customer(id: 'c1', name: 'No GST', phone: '9876543210', city: '', balancePaise: 0), create: true);
    await d.catalog.saveCustomer(const Customer(id: 'c2', name: 'With GST', phone: '', city: '', gstin: '33ABCDE1234F1Z5', balancePaise: 0), create: true);
    expect((await d.catalog.customer('c1'))!.gstin, '');
    expect((await d.catalog.customer('c2'))!.gstin, '33ABCDE1234F1Z5');
    await d.catalog.saveCustomer((await d.catalog.customer('c1'))!.copyWith(gstin: '29ABCDE1234F1Z5'), create: false);
    expect((await d.catalog.customer('c1'))!.gstin, '29ABCDE1234F1Z5');
    await d.close();
  });

  test('names, notes and reasons with quotes and SQL words are stored and read back exactly as typed', () async {
    final d = memoryShop();
    const name = r'''Robert'); DROP TABLE products;-- "x" 100% _ \ ₹''';
    await d.catalog.saveCustomer(const Customer(id: 'c1', name: name, phone: '9876543210', city: "O'Neil", balancePaise: 0), create: true);
    await d.catalog.saveProduct(sampleProduct(name, id: 'p1'), create: true);
    expect((await d.catalog.customer('c1'))!.name, name);
    expect((await d.catalog.customer('c1'))!.city, "O'Neil");
    expect((await d.catalog.product('p1'))!.name, name);
    await d.ledger.addAdjustment(PartyKind.customer, partyId: 'c1', signedPaise: 100, at: DateTime(2026, 10, 14), reason: "'; DELETE FROM ledger_entries; --");
    final acct = await d.ledger.account('c1');
    expect(acct.ledger.single.note, "'; DELETE FROM ledger_entries; --");
    await d.close();
  });
}
