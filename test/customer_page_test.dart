import 'package:erp2/core/money.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/return_repo.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/models.dart';
import 'package:erp2/fake/actions.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// The customer's page: what they bought, the profit on them and their bills come first; the credit account (balance, bills still to
// pay, ledger, reminders) shows only when the customer has credit or a debit. A bill opens the same popup as the Sales register.
void main() {
  Future<ProviderContainer> app(WidgetTester t, {String loc = '/customers'}) =>
      pumpApp(t, size: const ScreenSpec('tall', 1500, 3200), location: loc, motion: MotionLevel.off, followSystemMotion: false);

  /// A made-up customer with bills saved through the real save path: 4 bulbs (buying 60.00, selling 90.00) paid in full, and 2 more on credit.
  Future<(Customer, List<SavedBill>)> shopper(WidgetTester t, ProviderContainer c, {bool withCredit = true}) async {
    const cust = Customer(id: 'c-test', name: 'Test Shopper', phone: '9876500001', city: 'Erode', balancePaise: 0);
    c.read(customersProvider.notifier).add(cust);
    const p = Product(id: 'p-bulb-test', name: 'Test bulb', category: 'Electrical', unit: 'pcs', pricePaise: 9000, costPaise: 6000, stockMilli: 100000, gstBp: 1800, barcode: '');
    c.read(productsProvider.notifier).add(p);
    await t.runAsync(() => c.read(writeQueueProvider).flush());
    BillLineInput line(int q) => BillLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: q, ratePaise: 9000, gstBp: 1800, costPaise: 6000);
    final saved = <SavedBill>[];
    await t.runAsync(() async {
      saved.add(await c.read(billActionsProvider).save(SaveBillInput(idemKey: 'cp1', at: DateTime(2026, 10, 15, 10), lines: [line(4000)], customerId: cust.id, customerName: cust.name)));
      if (withCredit) {
        saved.add(await c.read(billActionsProvider).save(SaveBillInput(idemKey: 'cp2', at: DateTime(2026, 10, 16, 10), lines: [line(2000)], customerId: cust.id, customerName: cust.name, receivedPaise: 0)));
      }
    });
    return (cust, saved);
  }

  void go(WidgetTester t, String path) => GoRouter.of(t.element(find.byType(Scaffold).first)).go(path);

  testWidgets('what they bought, the profit on them and their bills come first, newest bill first', (tester) async {
    final c = await app(tester);
    final (cust, bills) = await shopper(tester, c);
    go(tester, '/customers/${cust.id}');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    final summary = (await tester.runAsync(() => c.read(appDataProvider).reports.customerSummary(cust.id)))!;
    expect(summary.bills, 2);
    expect(summary.boughtPaise, bills[0].totalPaise + bills[1].totalPaise);
    expect(summary.profitPaise, greaterThan(0));
    // the figures are on the page
    expect(find.text('Total bought'), findsOneWidget);
    expect(find.text('₹ ${formatPaise(summary.boughtPaise)}'), findsOneWidget);
    expect(find.text('Profit from this customer'), findsOneWidget);
    expect(find.text('₹ ${formatPaise(summary.profitPaise)}'), findsOneWidget);
    // both bills are listed, and they are above the credit account
    for (final b in bills) {
      expect(find.text(b.number), findsWidgets);
    }
    final billsY = tester.getTopLeft(find.text('Their bills')).dy;
    final accountY = tester.getTopLeft(find.byKey(const ValueKey('cust-account-card'))).dy;
    expect(billsY, lessThan(accountY), reason: 'the bills come before the account card');
    expect(tester.getTopLeft(find.text('Total bought')).dy, lessThan(billsY), reason: 'the totals come first');
    expect(find.text('Bills still to pay'), findsNothing, reason: 'the account is on its own page, not under the bills');
    expect(find.byKey(const ValueKey('cust-account-amount')), findsOneWidget, reason: 'only how much they owe is shown here');
    await tester.tap(find.byKey(const ValueKey('cust-account-open')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Bills still to pay'), findsOneWidget, reason: 'the account status page');
  });

  testWidgets('a customer with no credit or debit has no account section: only what they bought', (tester) async {
    final c = await app(tester);
    final (cust, _) = await shopper(tester, c, withCredit: false);
    go(tester, '/customers/${cust.id}');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Total bought'), findsOneWidget);
    expect(find.text('Their bills'), findsOneWidget);
    for (final gone in ['Credit account', 'Bills still to pay', 'Statement', 'Download statement', 'Receive payment']) {
      expect(find.text(gone), findsNothing, reason: '$gone is for a customer with an account');
    }
    expect(find.text('Add credit'), findsOneWidget, reason: 'credit can still be started');
  });

  testWidgets('a customer without any bill says so', (tester) async {
    final c = await app(tester);
    c.read(customersProvider.notifier).add(const Customer(id: 'c-none', name: 'No Bills Yet', phone: '', city: '', balancePaise: 0));
    await tester.runAsync(() => c.read(writeQueueProvider).flush());
    go(tester, '/customers/c-none');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cust-no-bills')), findsOneWidget);
    expect(find.text('₹ 0.00'), findsWidgets);
  });

  testWidgets('a bill in the customer\'s list opens the Sales-register popup; Print again then Back returns to this page with the popup', (tester) async {
    final c = await app(tester);
    final (cust, bills) = await shopper(tester, c);
    go(tester, '/customers/${cust.id}');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('cust-bill-${bills[0].id}')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Return items'), findsOneWidget);
    expect(find.text('Cancel bill'), findsOneWidget);
    expect(find.text('Print again'), findsOneWidget);
    await tester.tap(find.text('Print again'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    expect(find.text('Print again'), findsNothing, reason: 'no popup on the print page');
    await tester.tap(find.byKey(const ValueKey('printBack')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    expect(find.text('Total bought'), findsOneWidget, reason: 'back on the customer page');
    expect(find.text('Print again'), findsOneWidget, reason: 'with the bill popup open again');
  });

  testWidgets('Return items from the popup opens the return page of that bill; after a return the page shows less bought and the return', (tester) async {
    final c = await app(tester);
    final (cust, bills) = await shopper(tester, c);
    final ret = await tester.runAsync(() async {
      final v = (await c.read(appDataProvider).returns.returnable(bills[0].id))!;
      return c.read(billActionsProvider).returnItems(
            SaveReturnInput(idemKey: 'cr1', billId: bills[0].id, at: DateTime(2026, 10, 17, 9), lines: {v.lines.first.billLineId: 1000}, reason: 'Faulty'),
            productIds: [v.lines.first.productId],
            customerId: cust.id,
          );
    });
    go(tester, '/customers/${cust.id}');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    final summary = (await tester.runAsync(() => c.read(appDataProvider).reports.customerSummary(cust.id)))!;
    expect(summary.returnedPaise, ret!.totalPaise);
    expect(summary.boughtPaise, summary.grossPaise - ret.totalPaise);
    expect(find.text('Gave back'), findsOneWidget);
    expect(find.text('₹ ${formatPaise(summary.boughtPaise)}'), findsOneWidget);
  });
}
