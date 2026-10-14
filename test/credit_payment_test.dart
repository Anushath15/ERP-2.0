import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/credit_store.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/data_providers.dart';
import 'helpers.dart';

// The owner's "Credit" payment: tap Credit, a "Paid now" field appears (default 0) with Nothing / Half / Full buttons.

const t1 = Customer(id: 't1', name: 'Test Trader', phone: '98765 43210', city: 'Salem', balancePaise: 0);

Future<ProviderContainer> billing(WidgetTester tester, {ScreenSpec size = desktop1366, bool named = true}) async {
  final c = await pumpApp(tester, size: size, location: '/bill', motion: MotionLevel.off, followSystemMotion: false);
  c.read(customersProvider.notifier).add(t1);
  final cart = c.read(cartProvider(DocMode.invoice).notifier);
  cart.add(c.read(productsProvider)[5]);
  cart.setRate(0, 15000); // exactly Rs. 150.00
  if (named) cart.setCustomer(t1);
  await tester.pumpAndSettle();
  return c;
}

String receivedText(WidgetTester t) => t.widget<TextField>(find.byKey(const ValueKey('receivedField'))).controller!.text;
String lineText(WidgetTester t) => t.widget<Text>(find.byKey(const ValueKey('balanceLine'))).data!;

void main() {
  testWidgets('Credit is one of the payment modes; tapping it shows "Paid now" (0) and says what goes on credit', (tester) async {
    final c = await billing(tester);
    expect(find.text('Credit'), findsOneWidget);
    expect(find.text('Amount received'), findsOneWidget);
    await tester.tap(find.text('Credit'));
    await tester.pumpAndSettle();
    expect(c.read(cartProvider(DocMode.invoice)).pay, PayMode.credit);
    expect(find.text('Paid now'), findsOneWidget);
    expect(find.text('Amount received'), findsNothing);
    expect(receivedText(tester), '0.00');
    expect(lineText(tester), startsWith('Paid now: ₹0.00, goes on credit: ₹150.00'));
  });

  testWidgets('a named customer: the same panel shows what they owe now', (tester) async {
    final c = await billing(tester);
    final d = c.read(appDataProvider);
    await d.db.transaction(() => d.ledger.addBillCredit(d.db, PartyKind.customer, partyId: 't1', billNo: 'OLD-1', at: fixedNow.subtract(const Duration(days: 5)), total: 20000, received: 0));
    await c.read(creditProvider.notifier).refreshParty('t1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credit'));
    await tester.pumpAndSettle();
    expect(lineText(tester), contains('Test Trader owes ₹200.00 now'));
  });

  testWidgets('Half, Full and Nothing buttons; Full means it is not credit any more', (tester) async {
    final c = await billing(tester);
    await tester.tap(find.text('Credit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payHalf')));
    await tester.pump();
    expect(receivedText(tester), '75.00');
    expect(lineText(tester), startsWith('Paid now: ₹75.00, goes on credit: ₹75.00'));
    await tester.tap(find.byKey(const ValueKey('payNothing')));
    await tester.pump();
    expect(receivedText(tester), '0.00');
    await tester.tap(find.byKey(const ValueKey('payFull')));
    await tester.pumpAndSettle();
    expect(c.read(cartProvider(DocMode.invoice)).pay, PayMode.cash, reason: 'paying in full is a normal cash sale');
    expect(find.text('Paid in full'), findsOneWidget);
    expect(find.text('Amount received'), findsOneWidget);
  });

  testWidgets('typing a paid-now amount splits the bill; saving puts the rest on the customer\'s account and shows it on the bill', (tester) async {
    final c = await billing(tester);
    await tester.tap(find.text('Credit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('receivedField')), '40');
    await tester.pump();
    expect(lineText(tester), startsWith('Paid now: ₹40.00, goes on credit: ₹110.00'));
    await tester.tap(find.text('Save bill'));
    await tester.pumpAndSettle();
    expect(c.read(creditProvider)['t1']!.balance, 11000);
    expect(c.read(creditProvider.notifier).balanceAfterBill('t1', c.read(creditProvider)['t1']!.bills.single.billNo), 11000);
  });

  testWidgets('walk-in on credit: the "who is this for" window opens; Cancel changes nothing', (tester) async {
    final c = await billing(tester, named: false);
    await tester.tap(find.text('Credit'));
    await tester.pumpAndSettle();
    expect(lineText(tester), contains('Pick a customer to save'));
    await tester.tap(find.text('Save bill'));
    await tester.pumpAndSettle();
    expect(find.text('Who is this credit for?'), findsOneWidget);
    expect(find.text('Pick a customer'), findsOneWidget);
    expect(find.text('Add new customer'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final cart = c.read(cartProvider(DocMode.invoice));
    expect(cart.lines.length, 1, reason: 'the bill is unchanged');
    expect(cart.pay, PayMode.credit);
    expect(cart.customer, isNull);
    expect(c.read(creditProvider).containsKey('t1'), isFalse);
  });

  testWidgets('walk-in on credit: Add new customer needs only a name and then the bill saves on credit', (tester) async {
    final c = await billing(tester, named: false);
    await tester.tap(find.text('Credit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add new customer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name').last, 'Only A Name');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    final created = c.read(customersProvider).firstWhere((x) => x.name == 'Only A Name');
    expect(c.read(creditProvider)[created.id]!.balance, 15000);
    expect(c.read(cartProvider(DocMode.invoice)).lines, isEmpty);
  });

  testWidgets('a smaller Amount received on Cash uses the same rules (shortfall is credit, same window for a walk-in)', (tester) async {
    await billing(tester, named: false);
    await tester.enterText(find.byKey(const ValueKey('receivedField')), '100');
    await tester.pump();
    await tester.tap(find.text('Save bill'));
    await tester.pumpAndSettle();
    expect(find.text('Who is this credit for?'), findsOneWidget);
  });
}
