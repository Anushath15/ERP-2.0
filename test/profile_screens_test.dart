import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/credit/dues.dart';
import 'package:erp2/domain/credit/ledger.dart';
import 'package:erp2/fake/credit_store.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/fake/store.dart';
import 'helpers.dart';

// Profiles of customers and dealers (for the shopkeeper's own eyes), Money to collect actions, Settle fully with Undo,
// manual credit, reversing a wrong entry, date filter, edit, and the local-only statement PDF. Nothing is shared or sent.

Future<ProviderContainer> app(WidgetTester tester, String location, {ScreenSpec size = desktop1920, List<Override> extra = const []}) =>
    pumpApp(tester, size: size, location: location, motion: MotionLevel.off, followSystemMotion: false, extraOverrides: extra);

({Customer c, CreditAccount a}) sample() {
  final customers = seedCustomers();
  final credit = seedCredit(customers, fixedNow);
  for (final c in customers) {
    final a = credit[c.id];
    if (a == null || a.balance <= 0 || unpaidBills(a.bills).length < 2 || c.phone.isEmpty) continue;
    return (c: c, a: a);
  }
  throw StateError('no sample customer');
}

Rec dealerWithBalance() => seedDealers().firstWhere((d) => d.i('balance') > 0);

void main() {
  group('Money to collect actions', () {
    testWidgets('each row has Settle fully, Receive payment, Add credit; the page has Add credit customer', (tester) async {
      final s = sample();
      await app(tester, '/credit');
      expect(find.text('Add credit customer'), findsOneWidget);
      expect(find.text('Settle fully'), findsWidgets);
      expect(find.text('Receive payment'), findsWidgets);
      expect(find.byIcon(Icons.add_card_outlined), findsWidgets);
      expect(s.c.name, isNotEmpty);
    });

    testWidgets('Settle fully: choose how it was paid, confirm, the balance becomes zero; Undo (8 seconds) takes it back', (tester) async {
      final s = sample();
      final c = await app(tester, '/customers/${s.c.id}/account');
      final before = c.read(creditProvider)[s.c.id]!.balance;
      await tester.tap(find.byKey(const ValueKey('settleFully')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Settle ${s.c.name} fully'), findsOneWidget);
      await tester.tap(find.text('UPI'));
      await tester.enterText(find.byKey(const ValueKey('settleNote')), 'Paid at the counter');
      await tester.tap(find.byKey(const ValueKey('settleConfirm')));
      await tester.pumpAndSettle();
      expect(c.read(creditProvider)[s.c.id]!.balance, 0);
      final pay = c.read(creditProvider)[s.c.id]!.ledger.lastWhere((e) => e.kind == LedgerKind.payment);
      expect(pay.mode, 'upi');
      expect(pay.note, 'Paid at the counter');
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(c.read(creditProvider)[s.c.id]!.balance, before);
    });

    testWidgets('Add credit customer: details, the amount owed and the start date; they appear in Money to collect with that age', (tester) async {
      final c = await app(tester, '/credit');
      await tester.tap(find.text('Add credit customer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name').last, 'Old Debt Traders');
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone').last, '9876501234');
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount owed now').last, '2500');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      final made = c.read(customersProvider).firstWhere((x) => x.name == 'Old Debt Traders');
      expect(c.read(creditProvider)[made.id]!.balance, 250000);
      expect(c.read(creditProvider)[made.id]!.ledger.single.kind, LedgerKind.opening);
    });

    testWidgets('Add credit (by hand): amount and a reason are required; it adds to what they owe', (tester) async {
      final s = sample();
      final c = await app(tester, '/customers/${s.c.id}/account');
      final before = c.read(creditProvider)[s.c.id]!.balance;
      await tester.tap(find.byKey(const ValueKey('addCredit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('Please fill this in'), findsWidgets, reason: 'amount and reason are needed');
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount').last, '300');
      await tester.enterText(find.widgetWithText(TextFormField, 'Reason').last, 'Goods taken without a bill');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(c.read(creditProvider)[s.c.id]!.balance, before + 30000);
      expect(c.read(creditProvider)[s.c.id]!.ledger.last.kind, LedgerKind.manualCredit);
    });
  });

  group('customer profile', () {
    testWidgets('shows the details, the key dates and amounts, ageing, the ledger and reminders; no sharing of any kind', (tester) async {
      final s = sample();
      // the profile: the details and a way into the account
      await app(tester, '/customers/${s.c.id}');
      for (final t in ['Details', 'Credit limit', 'Address', 'Edit details', 'Account status']) {
        expect(find.textContaining(t), findsWidgets, reason: t);
      }
      // the account status page: the key dates and amounts, ageing, the ledger and reminders
      await app(tester, '/customers/${s.c.id}/account');
      for (final t in ['Credit started', 'Next due', 'Last payment', 'Last credit added', 'Credit limit', 'Credit account', 'Reminders opened in WhatsApp', 'Download statement']) {
        expect(find.textContaining(t), findsWidgets, reason: t);
      }
      expect(find.textContaining('Over 90 days'), findsOneWidget);
      for (final banned in ['Share', 'Send profile', 'Public link', 'Copy link']) {
        expect(find.textContaining(banned), findsNothing, reason: 'the profile is only for the shopkeeper: no "$banned"');
      }
    });

    testWidgets('a wrong payment is reversed by a new entry: both stay in the ledger, the bills are unpaid again, "Reversed" is shown', (tester) async {
      final s = sample();
      final c = await app(tester, '/customers/${s.c.id}/account', size: const ScreenSpec('tall', 1280, 3600));
      final n = c.read(creditProvider.notifier);
      final rec = await n.receivePayment(customerId: s.c.id, customerName: s.c.name, amount: 1000, mode: 'cash', at: fixedNow);
      await tester.pumpAndSettle();
      final before = c.read(creditProvider)[s.c.id]!.balance;
      final pay = c.read(creditProvider)[s.c.id]!.ledger.lastWhere((e) => e.kind == LedgerKind.payment && e.amountPaise == -1000);
      await tester.ensureVisible(find.byKey(ValueKey('reverse-${pay.id}')));
      await tester.tap(find.byKey(ValueKey('reverse-${pay.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Why is it wrong?').last, 'Typed the wrong customer');
      await tester.tap(find.text('Reverse').last);
      await tester.pumpAndSettle();
      final a = c.read(creditProvider)[s.c.id]!;
      expect(a.balance, before + 1000);
      expect(a.ledger.where((e) => e.id == pay.id).length, 1, reason: 'the wrong entry is not deleted');
      expect(a.ledger.where((e) => e.reverses == pay.id).length, 1);
      expect(find.text('Reversed'), findsOneWidget);
      expect(rec.amountPaise, 1000);
    });

    testWidgets('the ledger can be filtered by date: this month shows fewer lines than the whole history', (tester) async {
      final s = sample();
      await app(tester, '/customers/${s.c.id}/account', size: const ScreenSpec('tall', 1280, 3000));
      int rows() => find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('ledgerRow-')).evaluate().length;
      final all = rows();
      expect(all, greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('range0')));
      await tester.pumpAndSettle();
      expect(rows(), lessThan(all));
      await tester.tap(find.byKey(const ValueKey('range2')));
      await tester.pumpAndSettle();
      expect(rows(), all);
    });

    testWidgets('Edit details changes the name, town, address and credit limit', (tester) async {
      final s = sample();
      final c = await app(tester, '/customers/${s.c.id}');
      await tester.tap(find.byKey(const ValueKey('editParty')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Address').last, '12 Mill Road');
      await tester.enterText(find.widgetWithText(TextFormField, 'Credit limit').last, '75000');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      final x = c.read(customersProvider).firstWhere((e) => e.id == s.c.id);
      expect(x.address, '12 Mill Road');
      expect(x.creditLimitPaise, 7500000);
      expect(find.text('12 Mill Road'), findsOneWidget);
    });

    testWidgets('Download statement saves a PDF on this computer only (stand-in saver here); nothing is sent', (tester) async {
      final s = sample();
      final saver = FakeSaver();
      await app(tester, '/customers/${s.c.id}/account', extra: [fileSaverProvider.overrideWithValue(saver)]);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('downloadStatement')));
        for (var i = 0; i < 100 && saver.saved.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();
      expect(saver.saved.length, 1);
      expect(String.fromCharCodes(saver.saved.values.first.take(5)), '%PDF-');
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });
  });

  group('dealer profile', () {
    testWidgets('the Dealers list shows what we owe and tapping a row opens the profile', (tester) async {
      final d = dealerWithBalance();
      await app(tester, '/dealers');
      expect(find.text('Total we owe dealers'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, d.s('name'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(d.s('name')).last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dealer-add-purchase')), findsOneWidget, reason: 'the profile: purchases first');
      expect(find.byKey(const ValueKey('cust-account-card')), findsOneWidget, reason: 'and one card for what we owe');
      expect(find.text('Add adjustment'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cust-account-open')));
      await tester.pumpAndSettle();
      expect(find.text('Pay dealer'), findsOneWidget, reason: 'the account status page');
      expect(find.text('Settle fully'), findsOneWidget);
    });

    testWidgets('profile: balance we owe, started, last payment, last purchase, next payment due, ledger; no reminder or sharing buttons', (tester) async {
      final d = dealerWithBalance();
      await app(tester, '/dealers/${d.id}/account');
      for (final t in ['We owe', 'Account started', 'Last payment', 'Last purchase', 'Next payment due', 'Account: purchases and payments', 'Download statement']) {
        expect(find.textContaining(t), findsWidgets, reason: t);
      }
      expect(find.text('Remind on WhatsApp'), findsNothing);
      for (final banned in ['Share', 'Send profile', 'Public link']) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
    });

    testWidgets('Pay dealer reduces what we owe (oldest purchase first); Settle fully clears it; Add adjustment works both ways', (tester) async {
      final d = dealerWithBalance();
      final c = await app(tester, '/dealers/${d.id}/account');
      final n = c.read(dealerLedgerProvider.notifier);
      final start = n.balanceOf(d.id);
      await tester.tap(find.byKey(const ValueKey('receiveOrPay')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('payAmount')), '100');
      await tester.pump();
      await tester.tap(find.text('Save payment'));
      await tester.pumpAndSettle();
      expect(n.balanceOf(d.id), start - 10000);

      await tester.tap(find.byKey(const ValueKey('addAdjustment')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount').last, '50');
      await tester.enterText(find.widgetWithText(TextFormField, 'Reason').last, 'Freight');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(n.balanceOf(d.id), start - 10000 + 5000);

      await tester.tap(find.byKey(const ValueKey('settleFully')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settleConfirm')));
      await tester.pumpAndSettle();
      expect(n.balanceOf(d.id), 0);
    });
  });
}
