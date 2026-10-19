import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/features/billing/cart.dart';
import 'helpers.dart';

// What these tests prove: at the counter, when a customer asks for a GST bill, the shop can type (or fix) the customer's GST number
// right on the bill screen, it is checked, saved on the customer for next time, and printed on the tax invoice.
// What they do NOT prove: a real printer, or that a typed GST number is registered with the government (only its shape is checked).

const named = Customer(id: 'g1', name: 'Test Trader', phone: '98765 43210', city: 'Salem', balancePaise: 0);
const withGst = Customer(id: 'g2', name: 'Old Customer', phone: '', city: '', gstin: '33ABCDE1234F1Z5', balancePaise: 0);

Future<ProviderContainer> bill(WidgetTester tester, {String location = '/bill', Customer? customer, DocMode mode = DocMode.invoice}) async {
  final c = await pumpApp(tester, size: desktop1366, location: location, motion: MotionLevel.off, followSystemMotion: false);
  c.read(customersProvider.notifier).add(named);
  c.read(customersProvider.notifier).add(withGst);
  final cart = c.read(cartProvider(mode).notifier);
  cart.add(c.read(productsProvider)[5]);
  if (customer != null) cart.setCustomer(customer);
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('a walk-in bill points at choosing the customer first (a GST number belongs to a customer)', (tester) async {
    await bill(tester);
    expect(find.byTooltip('Customer wants a GST bill? Choose the customer first'), findsOneWidget);
  });

  testWidgets('a customer without GST: type the number, a wrong one is refused, a right one is saved on the customer and the bill', (tester) async {
    final c = await bill(tester, customer: named);
    expect(find.byTooltip('Customer wants GST? Add their GST number'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bill-gst')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'ABC123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not a valid GSTIN'), findsOneWidget, reason: 'a wrong number is not accepted');
    await tester.enterText(find.byType(TextFormField).last, '33abcde1234f1z5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('GST on bill: 33ABCDE1234F1Z5'), findsOneWidget, reason: 'in capitals, shown on the bill screen');
    expect(c.read(customersProvider).firstWhere((x) => x.id == 'g1').gstin, '33ABCDE1234F1Z5', reason: 'kept on the customer for next time');
    expect(c.read(cartProvider(DocMode.invoice)).customer!.gstin, '33ABCDE1234F1Z5');
    // saving the bill puts it on the tax invoice
    await tester.tap(find.text('Save and print'));
    await tester.pumpAndSettle();
    expect(c.read(printDocProvider)!.customerGstin, '33ABCDE1234F1Z5');
    expect(c.read(printDocProvider)!.customerPhone, '98765 43210');
    expect(find.text('GST  33ABCDE1234F1Z5'), findsOneWidget, reason: 'under the customer name on the paper');
  });

  testWidgets('a customer who already has a GST number shows it, and it can be changed or removed', (tester) async {
    final c = await bill(tester, customer: withGst);
    expect(find.text('GST on bill: 33ABCDE1234F1Z5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bill-gst')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(c.read(customersProvider).firstWhere((x) => x.id == 'g2').gstin, '');
    expect(find.byTooltip('Customer wants GST? Add their GST number'), findsOneWidget);
  });

  testWidgets('an estimate has no GST: no GST button there', (tester) async {
    await bill(tester, location: '/estimate', customer: named, mode: DocMode.estimation);
    expect(find.byKey(const ValueKey('bill-gst')), findsNothing);
  });

  testWidgets('adding a customer needs a name and a phone number; the GST number is optional', (tester) async {
    final c = await bill(tester);
    await tester.tap(find.text('Walk-in customer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add customer').last);
    await tester.pumpAndSettle();
    expect(find.text('GST number (optional)'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Ravi Traders');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Please fill this in'), findsOneWidget, reason: 'no phone number: not saved');
    expect(c.read(customersProvider).where((x) => x.name == 'Ravi Traders'), isEmpty);
    await tester.enterText(find.byType(TextFormField).at(1), '9876501234');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = c.read(customersProvider).where((x) => x.name == 'Ravi Traders').single;
    expect(saved.phone.replaceAll(' ', ''), contains('9876501234'));
    expect(saved.gstin, '', reason: 'GST left empty is fine');
  });
}
