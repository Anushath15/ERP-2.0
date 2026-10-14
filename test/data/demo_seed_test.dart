import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/data/repo/self_check.dart';
import 'package:erp2/demo/demo_seeder.dart';
import 'package:erp2/domain/credit/account.dart';
import 'helpers.dart';

void main() {
  test('the sample shop goes in through the real tables and passes the self-check', () async {
    final d = memoryShop();
    final sw = Stopwatch()..start();
    await seedDemo(d, DateTime(2026, 10, 13, 17, 30), counts: const DemoCounts(bills: 600, estimates: 50));
    // ignore: avoid_print
    print('seeded in ${sw.elapsedMilliseconds} ms');
    expect(await d.catalog.productCount(), 757);
    expect(await d.catalog.customerCount(), 5000);
    expect(await d.bills.count(), 600);
    final problems = await selfCheck(d.db, deep: true);
    expect(problems, isEmpty, reason: '$problems');
    expect(await sqliteIntegrity(d.db, full: true), isEmpty);
    final owing = await d.ledger.balances(PartyKind.customer, limit: 1000);
    expect(owing.length, greaterThan(100));
    await d.close();
  });
}


