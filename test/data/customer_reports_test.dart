import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/return_repo.dart';
import 'package:erp2/domain/credit/account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove, worked by hand: top customers are ranked by what they bought less what they returned (cancelled bills and walk-in sales left
// out); the average days to pay counts only credit bills paid in full (from the bill to the payment that settled it, reversed payments not counted);
// overdue bills are the credit bills still unpaid more than 30 days after the bill.
void main() {
  test('top customers, days to pay and overdue bills', () async {
    final d = memoryShop();
    addTearDown(d.close);
    await d.catalog.saveProduct(sampleProduct('Bulb', id: 'p1', stock: 1000000, price: 10000, gst: 0), create: true);
    await d.catalog.saveCustomer(sampleCustomer('Murugan', id: 'c1', limit: 100000000), create: true);
    await d.catalog.saveCustomer(sampleCustomer('Selvi', id: 'c2', limit: 100000000), create: true);
    BillLineInput line(int qty) => BillLineInput(productId: 'p1', name: 'Bulb', unit: 'pcs', qtyMilli: qty, ratePaise: 10000, gstBp: 0);
    Future<SavedBill> bill(String key, DateTime at, {String? cust, int qty = 1000, int? received}) => d.bills.saveBill(SaveBillInput(idemKey: key, at: at, lines: [line(qty)], customerId: cust, customerName: cust == null ? '' : cust, receivedPaise: received));

    // Murugan: Rs 1000 on credit on 1 Sep, paid in full on 11 Sep (10 days); Rs 300 cash; Rs 100 returned
    final m1 = await bill('m1', DateTime(2026, 9, 1, 10), cust: 'c1', qty: 10000, received: 0);
    await d.ledger.receivePayment(PartyKind.customer, partyId: 'c1', partyName: 'Murugan', amount: 100000, mode: 'cash', at: DateTime(2026, 9, 11, 10));
    final m2 = await bill('m2', DateTime(2026, 9, 5, 10), cust: 'c1', qty: 3000);
    final ln = (await d.db.rows('SELECT id FROM bill_lines WHERE bill_id = ?', [m2.id])).single.read<String>('id');
    await d.returns.saveReturn(SaveReturnInput(idemKey: 'r', billId: m2.id, at: DateTime(2026, 9, 6), lines: {ln: 1000}, reason: 'extra'));
    // Selvi: Rs 500 on credit on 1 Sep, never paid; a Rs 2000 bill that was cancelled
    await bill('s1', DateTime(2026, 9, 1, 11), cust: 'c2', qty: 5000, received: 0);
    final gone = await bill('s2', DateTime(2026, 9, 2, 11), cust: 'c2', qty: 20000, received: 0);
    await d.bills.cancelBill(gone.id, reason: 'mistake');
    // a walk-in sale: in nobody's figures
    await bill('w', DateTime(2026, 9, 3, 11), qty: 50000);

    final top = await d.reports.topCustomers(DateTime(2026, 1, 1), DateTime(2026, 12, 31));
    expect([for (final t in top) (t.name, t.bills, t.salesPaise)], [('Murugan', 2, 130000 - 10000), ('Selvi', 1, 50000)]);

    final delay = await d.reports.paymentDelay();
    expect((delay.bills, delay.averageDays, delay.longestDays), (1, 10.0, 10), reason: 'only Murugan\'s bill is paid in full: 10 days');

    final overdue = await d.reports.overdueBills(DateTime(2026, 10, 20));
    expect(overdue.map((o) => (o.customerName, o.duePaise, o.daysOld)), [('Selvi', 50000, 49)]);
    expect(await d.reports.overdueBills(DateTime(2026, 9, 20)), isEmpty, reason: 'only 19 days old then');
    expect(m1.number, isNotEmpty);
  });
}
