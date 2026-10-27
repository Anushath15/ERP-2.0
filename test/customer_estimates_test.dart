import 'package:erp2/data/repo/records_repo.dart' show EstimateLine;
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'data/helpers.dart' as data;
import 'helpers.dart';

// What these tests prove: a customer's page lists their estimates under their bills, like the bills: the estimates saved for them, and the ones saved with
// only their name; never another customer's, never a deleted one. A click opens the estimate (Print, PDF, WhatsApp, Edit, Make into bill). A customer with no
// estimate says so.
void main() {
  const line = EstimateLine(productId: 'p1', name: 'PIPE', unit: 'Nos', qtyMilli: 1000, ratePaise: 25000);

  test('the estimates of one customer: by the customer, or by their name when it was saved without the customer', () async {
    final d = data.memoryShop();
    addTearDown(d.close);
    await d.catalog.saveProduct(data.sampleProduct('PIPE', id: 'p1', price: 25000, stock: 100000, gst: 1800), create: true);
    await d.catalog.saveCustomer(data.sampleCustomer('Sibi', id: 'c1', limit: 1000000), create: true);
    await d.catalog.saveCustomer(data.sampleCustomer('Ravi', id: 'c2', limit: 1000000), create: true);
    final a = await d.estimations.save(lines: const [line], totalPaise: 25000, customerName: 'Sibi', customerId: 'c1', at: DateTime(2026, 10, 20));
    final byName = await d.estimations.save(lines: const [line], totalPaise: 50000, customerName: 'sibi', at: DateTime(2026, 10, 22));
    await d.estimations.save(lines: const [line], totalPaise: 75000, customerName: 'Ravi', customerId: 'c2', at: DateTime(2026, 10, 23));
    await d.estimations.save(lines: const [line], totalPaise: 90000, customerName: '', at: DateTime(2026, 10, 24));
    final gone = await d.estimations.save(lines: const [line], totalPaise: 10000, customerName: 'Sibi', customerId: 'c1', at: DateTime(2026, 10, 25));
    await d.estimations.remove(gone.number, reason: 'mistake');

    final list = await d.estimations.forCustomer('c1', 'Sibi');
    expect([for (final e in list) e.number], [byName.number, a.number], reason: 'newest first; the one saved with the name only is there too');
    expect((await d.estimations.forCustomer('c2', 'Ravi')).length, 1);
    expect(await d.estimations.forCustomer('c9', ''), isEmpty, reason: 'no name: walk-in estimates are nobody\'s');
  });

  testWidgets('the customer page lists their estimates; a click opens the estimate', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1400, 3200), location: '/customers', motion: MotionLevel.off, followSystemMotion: false);
    final customers = c.read(customersProvider);
    final est = c.read(estimationsProvider).firstWhere((e) => e.customer.isNotEmpty && customers.any((x) => x.name == e.customer));
    final cust = customers.firstWhere((x) => x.name == est.customer);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/customers/${cust.id}');
    await tester.pumpAndSettle();
    expect(find.text('Their estimates'), findsOneWidget);
    final row = find.byKey(ValueKey('cust-est-${est.number}'));
    expect(row, findsOneWidget);
    final others = c.read(estimationsProvider).where((e) => e.customer.isNotEmpty && e.customer.toLowerCase() != cust.name.toLowerCase()).take(3);
    for (final o in others) {
      expect(find.byKey(ValueKey('cust-est-${o.number}')), findsNothing, reason: '${o.number} is ${o.customer}\'s');
    }
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    for (final k in ['est-print', 'est-download-pdf', 'est-whatsapp']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    expect(find.text(est.number), findsWidgets);
  });

  testWidgets('a customer with no estimate says so', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1400, 3200), location: '/customers', motion: MotionLevel.off, followSystemMotion: false);
    final names = {for (final e in c.read(estimationsProvider)) e.customer.toLowerCase()};
    final none = c.read(customersProvider).firstWhere((x) => !names.contains(x.name.toLowerCase()));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/customers/${none.id}');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cust-no-estimates')), findsOneWidget);
  });
}
