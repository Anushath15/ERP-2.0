import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/credit/ledger.dart';
import 'package:erp2/fake/credit_store.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/features/billing/cart.dart';
import 'helpers.dart';

// What these tests prove: our screens and rules for part payment, credit, receiving payments and reminders.
// What they do NOT prove: that WhatsApp itself opens or sends (needs a real phone or PC), or a real printer.

const t1 = Customer(id: 't1', name: 'Test Trader', phone: '98765 43210', city: 'Salem', balancePaise: 0);

Future<ProviderContainer> billing(WidgetTester tester, {ScreenSpec size = desktop1366, List<Override> extra = const [], bool named = true}) async {
  final c = await pumpApp(tester, size: size, location: '/bill', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: extra);
  c.read(customersProvider.notifier).add(t1);
  final cart = c.read(cartProvider(DocMode.invoice).notifier);
  cart.add(c.read(productsProvider)[5]);
  cart.setRate(0, 15000); // exactly Rs. 150.00
  if (named) cart.setCustomer(t1);
  await tester.pumpAndSettle();
  return c;
}

Future<void> typeReceived(WidgetTester tester, String v) async {
  await tester.enterText(find.byKey(const ValueKey('receivedField')), v);
  await tester.pump();
}

CreditAccount acct(ProviderContainer c, String id) => c.read(creditProvider)[id] ?? const CreditAccount();

void main() {
  group('POS payment area', () {
    testWidgets('a normal sale: Amount received defaults to the Grand Total and saves with no typing and no credit', (tester) async {
      final c = await billing(tester);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('receivedField'))).controller!.text, '150.00');
      expect(find.text('Paid in full'), findsOneWidget);
      await tester.tap(find.text('Save bill'));
      await tester.pump();
      expect(c.read(cartProvider(DocMode.invoice)).lines, isEmpty, reason: 'saved in the very same frame');
      expect(acct(c, 't1').ledger, isEmpty, reason: 'nothing was put on credit');
    });

    testWidgets('the owner example: 150 bill, 100 received: the screen says Balance 50 will be added to the customer, and saving adds it', (tester) async {
      final c = await billing(tester);
      await typeReceived(tester, '100');
      expect(find.text("Balance ₹50.00 will be added to Test Trader's credit"), findsOneWidget);
      await tester.tap(find.text('Save bill'));
      await tester.pumpAndSettle();
      final a = acct(c, 't1');
      expect(a.balance, 5000);
      expect(a.ledger.single.kind, LedgerKind.billCredit);
      expect(a.bills.single.outstanding, 5000);
      expect(a.bills.single.totalPaise, 15000);
      expect(c.read(cartProvider(DocMode.invoice)).lines, isEmpty);
    });

    testWidgets('Full amount button and the "nothing received" button', (tester) async {
      await billing(tester);
      await typeReceived(tester, '10');
      expect(find.textContaining('Balance ₹140.00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fullAmount')));
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('receivedField'))).controller!.text, '150.00');
      expect(find.text('Paid in full'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nothingReceived')));
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('receivedField'))).controller!.text, '0.00');
      expect(find.textContaining('goes on credit: ₹150.00'), findsOneWidget, reason: 'the clock button is the same as choosing Credit with nothing paid');
      expect(find.text('Paid now'), findsOneWidget);
    });

    testWidgets('walk-in customer with a balance: a prompt appears and the bill is NOT saved until resolved', (tester) async {
      final c = await billing(tester, named: false);
      await typeReceived(tester, '100');
      expect(find.textContaining('needs a customer'), findsOneWidget);
      await tester.tap(find.text('Save bill'));
      await tester.pumpAndSettle();
      expect(find.text('Who is this credit for?'), findsOneWidget);
      expect(c.read(cartProvider(DocMode.invoice)).lines.length, 1, reason: 'not saved');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.read(cartProvider(DocMode.invoice)).lines.length, 1, reason: 'still not saved after cancelling the prompt');
      expect(find.text('Who is this credit for?'), findsNothing);
    });

    testWidgets('walk-in prompt: add a new customer (name and phone checked) and the bill saves with the balance on their account', (tester) async {
      final c = await billing(tester, named: false);
      await typeReceived(tester, '100');
      await tester.tap(find.text('Save bill'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add new customer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'New Buyer');
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone'), 'abc12');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('Please type a correct mobile number, like 98765 43210'), findsOneWidget, reason: 'nonsense phone is refused');
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone'), '09876543211');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(c.read(cartProvider(DocMode.invoice)).lines, isEmpty, reason: 'saved after the customer was added');
      final owner = c.read(customersProvider).firstWhere((x) => x.name == 'New Buyer');
      expect(acct(c, owner.id).balance, 5000);
    });

    testWidgets('walk-in prompt: choose an existing customer', (tester) async {
      final c = await billing(tester, named: false);
      await typeReceived(tester, '0');
      await tester.tap(find.text('Save bill'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pickCustomerForCredit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Trader'));
      await tester.pumpAndSettle();
      expect(c.read(cartProvider(DocMode.invoice)).lines, isEmpty);
      expect(acct(c, 't1').balance, 15000, reason: 'received 0 means the whole bill is on credit');
    });

    testWidgets('overpaid walk-in: change is shown and nothing is kept; no advance option', (tester) async {
      final c = await billing(tester, named: false);
      await typeReceived(tester, '200');
      expect(find.text('Change to give back ₹50.00'), findsOneWidget);
      expect(find.byKey(const ValueKey('advanceToggle')), findsNothing);
      await tester.tap(find.text('Save bill'));
      await tester.pumpAndSettle();
      expect(c.read(cartProvider(DocMode.invoice)).lines, isEmpty);
      expect(c.read(creditProvider).values.where((a) => a.ledger.any((e) => e.billNo != null && e.at == fixedNow)), isEmpty);
    });

    testWidgets('overpaid named customer: change by default; "Keep as advance" puts the extra on their account', (tester) async {
      final c = await billing(tester);
      await typeReceived(tester, '200');
      expect(find.text('Change to give back ₹50.00'), findsOneWidget, reason: 'never silently keep extra money');
      await tester.tap(find.byKey(const ValueKey('advanceToggle')));
      await tester.pump();
      expect(find.text('₹50.00 kept as advance for Test Trader'), findsOneWidget);
      await tester.tap(find.text('Save bill'));
      await tester.pumpAndSettle();
      final a = acct(c, 't1');
      expect(a.balance, -5000, reason: 'an advance is a negative balance');
      expect(a.ledger.single.kind, LedgerKind.advance);
    });

    testWidgets('overpaid named customer who takes the change: no ledger entry', (tester) async {
      final c = await billing(tester);
      await typeReceived(tester, '200');
      await tester.tap(find.text('Save bill'));
      await tester.pumpAndSettle();
      expect(acct(c, 't1').ledger, isEmpty);
    });

    testWidgets('payment mode picks Cash, UPI or Card or other; and Credit (Credit mode has its own tests in credit_payment_test.dart)', (tester) async {
      final c = await billing(tester);
      expect(find.text('Card or other'), findsOneWidget);
      expect(find.text('Credit'), findsOneWidget, reason: 'Credit is the fourth payment mode');
      await tester.tap(find.text('UPI'));
      await tester.pump();
      expect(c.read(cartProvider(DocMode.invoice)).pay, PayMode.upi);
    });
  });

  group('credit limit', () {
    testWidgets('warn: asks "Save anyway?"; block: refuses with a reason; off: just saves', (tester) async {
      final c = await pumpApp(tester, size: desktop1366, location: '/bill', motion: MotionLevel.off, followSystemMotion: false);
      const limited = Customer(id: 't2', name: 'Limited Co', phone: '9876543210', city: 'X', balancePaise: 0, creditLimitPaise: 10000);
      c.read(customersProvider.notifier).add(limited);
      final cart = c.read(cartProvider(DocMode.invoice).notifier);
      void fill() {
        cart.add(c.read(productsProvider)[5]);
        cart.setRate(0, 15000);
        cart.setCustomer(limited);
        cart.setReceived(0); // 150 on credit against a limit of 100
      }

      fill();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save bill'));
      await tester.pumpAndSettle();
      expect(find.text('Over the credit limit'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.read(cartProvider(DocMode.invoice)).lines.length, 1);
      c.read(shopProvider.notifier).set((s) => s.copyWith(creditLimitMode: CreditLimitMode.block));
      await tester.tap(find.text('Save bill'));
      await tester.pumpAndSettle();
      expect(find.text('Credit limit reached'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(c.read(cartProvider(DocMode.invoice)).lines.length, 1, reason: 'blocked');
      c.read(shopProvider.notifier).set((s) => s.copyWith(creditLimitMode: CreditLimitMode.off));
      await tester.tap(find.text('Save bill'));
      await tester.pumpAndSettle();
      expect(c.read(cartProvider(DocMode.invoice)).lines, isEmpty);
      expect(c.read(creditProvider)['t2']!.balance, 15000);
    });
  });

  group('printed bill', () {
    testWidgets('invoice shows Received and Balance due (added to credit); estimate shows neither', (tester) async {
      await pumpApp(tester, size: desktop1366, location: '/preview/a4');
      expect(find.byKey(const ValueKey('paperReceived')), findsOneWidget);
      expect(find.byKey(const ValueKey('paperBalance')), findsOneWidget);
      expect(find.textContaining('Balance due (added to credit)'), findsOneWidget);
      await pumpApp(tester, size: desktop1366, location: '/preview/estimate');
      expect(find.byKey(const ValueKey('paperReceived')), findsNothing);
      expect(find.byKey(const ValueKey('paperBalance')), findsNothing);
    });
    testWidgets('80 mm and 58 mm receipts show them too', (tester) async {
      for (final r in ['/preview/80', '/preview/58']) {
        await pumpApp(tester, size: desktop1366, location: r);
        expect(find.byKey(const ValueKey('paperBalance')), findsOneWidget, reason: r);
        expect(tester.takeException(), isNull);
      }
    });
    testWidgets('saving part paid with Save and print leads to a preview with the balance', (tester) async {
      await billing(tester);
      await typeReceived(tester, '100');
      await tester.tap(find.text('Save and print'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paperBalance')), findsOneWidget);
      expect(find.textContaining('₹ 50.00'), findsWidgets);
    });
  });

  group('sales register', () {
    testWidgets('status chips: Paid, Part paid, Unpaid', (tester) async {
      await pumpApp(tester, size: desktop1920, location: '/sales');
      expect(find.text('Paid'), findsWidgets);
      expect(find.text('Part paid'), findsWidgets);
      expect(find.text('Unpaid'), findsWidgets);
    });
  });

  group('cancelling a bill', () {
    test('reverses the credit it added (owner, reason) and leaves other bills alone', () {
      final c = ProviderContainer(overrides: [clockProvider.overrideWithValue(fixedNow)]);
      addTearDown(c.dispose);
      final n = c.read(creditProvider.notifier);
      n.addBill(customerId: 'x', billNo: 'A-1', at: fixedNow, total: 15000, received: 10000);
      n.addBill(customerId: 'x', billNo: 'A-2', at: fixedNow, total: 8000, received: 0);
      expect(n.balanceOf('x'), 13000);
      n.cancelBill(billNo: 'A-1', reason: 'wrong customer', at: fixedNow);
      expect(n.balanceOf('x'), 8000);
      expect(c.read(creditProvider)['x']!.bills.firstWhere((b) => b.billNo == 'A-1').cancelled, true);
      expect(c.read(creditProvider)['x']!.ledger.last.kind, LedgerKind.billCancel);
      n.cancelBill(billNo: 'A-1', reason: 'again', at: fixedNow); // already reversed: ignored by the ledger rule
    });
  });
}
