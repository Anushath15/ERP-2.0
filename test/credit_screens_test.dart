import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:erp2/domain/credit/reminder.dart' show LinkPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/core/link_launcher.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/credit/dues.dart';
import 'package:erp2/domain/credit/ledger.dart';
import 'package:erp2/fake/credit_store.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/fake/store.dart';
import 'helpers.dart';

// These tests cover our screens and rules. They do not prove that WhatsApp itself opens or sends anything.

/// A customer from the sample data with at least two unpaid bills and a phone number, and the credit account the app builds for them.
({Customer c, CreditAccount a}) sample({bool reminded = false, bool withPhone = true}) {
  final customers = seedCustomers();
  final credit = seedCredit(customers, fixedNow);
  final log = seedReminders(credit, fixedNow);
  for (final c in customers) {
    final a = credit[c.id];
    if (a == null || a.balance <= 0 || unpaidBills(a.bills).length < 2) continue;
    if (withPhone != c.phone.isNotEmpty) continue;
    if (reminded != (log.countFor(c.id) > 0)) continue;
    return (c: c, a: a);
  }
  throw StateError('no sample customer');
}

Future<ProviderContainer> app(WidgetTester tester, String location, {ScreenSpec size = desktop1920, List<Override> extra = const [], MotionLevel motion = MotionLevel.off}) =>
    pumpApp(tester, size: size, location: location, motion: motion, followSystemMotion: false, extraOverrides: extra);

void main() {
  group('sample data is realistic and consistent', () {
    test('every credit account: ledger balance equals bill-wise dues plus the carried-in balance; part-paid, advance, overdue and reminded cases exist', () {
      final customers = seedCustomers();
      final credit = seedCredit(customers, fixedNow);
      final log = seedReminders(credit, fixedNow);
      var advances = 0, overdue = 0, partPaid = 0, reminded = 0, withOpening = 0;
      for (final e in credit.entries) {
        final a = e.value;
        if (a.balance < 0) advances++;
        if (a.balance > 0) {
          expect(a.balance, a.bills.fold<int>(0, (s, b) => s + b.outstanding) + a.ledger.where((x) => x.kind == LedgerKind.opening).fold<int>(0, (s, x) => s + x.amountPaise), reason: e.key);
          if (overdueAmount(a.bills, fixedNow) > 0) overdue++;
          if (a.bills.any((b) => b.paidPaise > 0 && b.outstanding > 0)) partPaid++;
          if (log.countFor(e.key) > 0) reminded++;
          if (a.ledger.any((x) => x.kind == LedgerKind.opening)) withOpening++;
        }
      }
      expect(advances, greaterThan(5));
      expect(overdue, greaterThan(20));
      expect(partPaid, greaterThan(10));
      expect(reminded, greaterThan(10));
      expect(withOpening, greaterThan(1));
      expect(customers.where((c) => c.phone.isEmpty).length, greaterThan(50), reason: 'some customers have no number');
    });
  });

  group('Credit and Dues screen', () {
    testWidgets('totals, rows, filters, and a reminder badge per row', (tester) async {
      final s = sample(reminded: true);
      final c = await app(tester, '/credit');
      expect(find.text('Money to collect'), findsWidgets);
      expect(find.text('Overdue'), findsWidgets);
      expect(find.text('Advances we hold'), findsOneWidget);
      expect(find.textContaining('Reminded'), findsWidgets);
      expect(find.text('Not reminded yet'), findsWidgets);
      expect(tester.takeException(), isNull);
      // search finds the customer
      await tester.enterText(find.byType(TextField).first, s.c.name);
      await tester.pumpAndSettle();
      expect(find.text(s.c.name), findsWidgets);
      // advance filter
      await tester.enterText(find.byType(TextField).first, '');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Advance'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Advance ₹'), findsWidgets);
      expect(c.read(creditProvider).values.any((a) => a.balance < 0), true);
    });

    testWidgets('row actions: Receive payment, WhatsApp, Statement exist; offline the tooltip says why', (tester) async {
      sample();
      final c = await app(tester, '/credit');
      expect(find.text('Receive payment'), findsWidgets);
      expect(find.byIcon(Icons.chat_outlined), findsWidgets);
      expect(find.byIcon(Icons.description_outlined), findsWidgets);
      c.read(settingsProvider.notifier).set((x) => x.copyWith(sync: SyncState.offline));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remind on WhatsApp: Needs internet; you are offline'), findsWidgets);
    });
  });

  group('customer page', () {
    testWidgets('balance, limit, ageing buckets, bill-wise dues, ledger with running balance, reminders', (tester) async {
      final s = sample(reminded: true);
      await app(tester, '/customers/${s.c.id}/account', size: const ScreenSpec('tall', 1920, 3600));
      expect(find.text(s.c.name), findsWidgets);
      expect(find.text('Money to collect'), findsWidgets);
      expect(find.text('Credit limit'), findsWidgets);
      expect(find.text('Last payment'), findsOneWidget);
      expect(find.text('Bills still to pay'), findsOneWidget);
      expect(find.textContaining('0-30 days'), findsOneWidget);
      expect(find.textContaining('31-60 days'), findsOneWidget);
      expect(find.textContaining('61-90 days'), findsOneWidget);
      expect(find.textContaining('Over 90 days'), findsOneWidget);
      expect(find.text('Credit account'), findsWidgets, reason: 'the page subtitle and the ledger card');
      expect(find.textContaining('Bill on credit'), findsWidgets);
      expect(find.text('Reminders opened in WhatsApp'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('statement: opening, charged, received and closing balance, printable', (tester) async {
      final s = sample();
      await app(tester, '/customers/${s.c.id}/statement');
      expect(find.text('Statement of account'), findsWidgets);
      expect(find.text('Opening balance'), findsOneWidget);
      expect(find.text('Closing balance'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Save as PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Statement PDF', () {
    testWidgets('Save as PDF makes a real PDF file (saved through a stand-in, not to disk) and says where', (tester) async {
      final s = sample();
      final saver = FakeSaver();
      await app(tester, '/customers/${s.c.id}/statement', extra: [fileSaverProvider.overrideWithValue(saver)]);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('statementPdf')));
        for (var i = 0; i < 100 && saver.saved.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();
      expect(saver.saved.length, 1);
      final bytes = saver.saved.values.first;
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(2000));
      expect(saver.saved.keys.first, startsWith('Statement '));
      expect(find.textContaining('PDF saved'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });
  });

  group('Receive payment', () {
    testWidgets('amount defaults to the dues; the oldest bill is settled first; the receipt can be opened', (tester) async {
      final s = sample();
      final c = await app(tester, '/customers/${s.c.id}/account');
      await tester.tap(find.byKey(const ValueKey('receiveOrPay')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byKey(const ValueKey('payAmount')));
      expect(field.controller!.text, (s.a.balance / 100).toStringAsFixed(2));
      // pay only part: the oldest unpaid bill must be the first one to receive money
      final oldest = unpaidBills(s.a.bills).first;
      final pay = (oldest.outstanding ~/ 2 + 1) / 100;
      await tester.enterText(find.byKey(const ValueKey('payAmount')), pay.toStringAsFixed(2));
      await tester.pump();
      expect(find.textContaining('pays ₹'), findsOneWidget);
      await tester.tap(find.text('Save payment'));
      await tester.pumpAndSettle();
      final after = c.read(creditProvider)[s.c.id]!;
      expect(after.bills.firstWhere((b) => b.billNo == oldest.billNo).paidPaise, greaterThan(oldest.paidPaise));
      expect(after.balance, s.a.balance - (oldest.outstanding ~/ 2 + 1));
      expect(after.ledger.last.kind, LedgerKind.payment);
      expect(find.text('Print receipt'), findsOneWidget, reason: 'offered right after saving');
      await tester.tap(find.text('Print receipt'));
      await tester.pumpAndSettle();
      expect(find.text('PAYMENT RECEIPT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('paying more than the dues keeps the rest as an advance; the dialog says so', (tester) async {
      final s = sample();
      final c = await app(tester, '/customers/${s.c.id}/account');
      await tester.tap(find.byKey(const ValueKey('receiveOrPay')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('payAmount')), ((s.a.balance + 12345) / 100).toStringAsFixed(2));
      await tester.pump();
      expect(find.textContaining('will be kept as an advance'), findsOneWidget);
      await tester.tap(find.text('Save payment'));
      await tester.pumpAndSettle();
      expect(c.read(creditProvider)[s.c.id]!.balance, -12345);
    });

    testWidgets('"I will choose the bills": only the chosen bills are settled', (tester) async {
      final s = sample();
      final c = await app(tester, '/customers/${s.c.id}/account');
      await tester.tap(find.byKey(const ValueKey('receiveOrPay')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      final bills = unpaidBills(s.a.bills);
      final newest = bills.last;
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('payAmount')), (newest.outstanding / 100).toStringAsFixed(2));
      await tester.pump();
      await tester.tap(find.text('Save payment'));
      await tester.pumpAndSettle();
      final after = c.read(creditProvider)[s.c.id]!;
      expect(after.bills.firstWhere((b) => b.billNo == newest.billNo).outstanding, 0);
      expect(after.bills.firstWhere((b) => b.billNo == bills.first.billNo).outstanding, bills.first.outstanding, reason: 'the oldest was not chosen, so untouched');
    });

    testWidgets('write-off is limited to what is owed and keeps bills and ledger equal', (tester) async {
      final s = sample();
      final c = await app(tester, '/customers/${s.c.id}/account');
      final n = c.read(creditProvider.notifier);
      await expectLater(n.writeOff(customerId: s.c.id, amount: s.a.balance + 1, reason: 'x', at: fixedNow), throwsStateError);
      await n.writeOff(customerId: s.c.id, amount: 500, reason: 'small amount', at: fixedNow);
      final a = c.read(creditProvider)[s.c.id]!;
      expect(a.balance, s.a.balance - 500);
      expect(a.balance, a.bills.fold<int>(0, (t, b) => t + b.outstanding) + a.ledger.where((x) => x.kind == LedgerKind.opening).fold<int>(0, (t, x) => t + x.amountPaise));
    });
  });

  group('WhatsApp reminder', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(OutlinedButton, 'Remind on WhatsApp').first);
      await tester.pumpAndSettle();
    }

    testWidgets('preview dialog: ready message (editable), tones, Open WhatsApp builds the app link first on Windows; one reminder is counted', (tester) async {
      final s = sample();
      final fake = FakeLauncher();
      final c = await app(tester, '/customers/${s.c.id}/account', extra: [linkLauncherProvider.overrideWithValue(fake)]);
      await openDialog(tester);
      expect(find.text('Remind ${s.c.name} on WhatsApp'), findsOneWidget);
      final msg = tester.widget<TextField>(find.byKey(const ValueKey('remMessage'))).controller!.text;
      expect(msg, contains(s.c.name));
      expect(msg, contains('Senthil Enterprises'));
      expect(msg, contains('is pending'));
      expect(msg.length, lessThanOrEqualTo(1500));
      await tester.enterText(find.byKey(const ValueKey('remMessage')), '$msg\nPlease call me.');
      await tester.tap(find.text('Firm'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('remMessage'))).controller!.text, contains('overdue'), reason: 'switching tone rebuilds the message');
      final before = c.read(reminderLogProvider).countFor(s.c.id);
      await tester.tap(find.byKey(const ValueKey('openWhatsapp')));
      await tester.pumpAndSettle();
      expect(fake.opened.length, 1);
      expect(fake.opened.single, startsWith('whatsapp://send?phone=91'));
      expect(c.read(reminderLogProvider).countFor(s.c.id), before + 1);
      expect(find.text('Not sent? Undo'), findsOneWidget);
      expect(find.textContaining('Opened in WhatsApp'), findsOneWidget);
      // Undo takes the record back and the count goes down again
      await tester.tap(find.text('Not sent? Undo'));
      await tester.pumpAndSettle();
      expect(c.read(reminderLogProvider).countFor(s.c.id), before);
      expect(find.text('Reminder removed'), findsOneWidget);
    });

    testWidgets('app not installed: falls back to the wa.me link; on the web only wa.me is used', (tester) async {
      final s = sample();
      final fake = FakeLauncher(appInstalled: false);
      await app(tester, '/customers/${s.c.id}/account', extra: [linkLauncherProvider.overrideWithValue(fake)]);
      await openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('openWhatsapp')));
      await tester.pumpAndSettle();
      expect(fake.opened.single, startsWith('https://wa.me/91'));
      final web = FakeLauncher(platform: LinkPlatform.web);
      await app(tester, '/customers/${s.c.id}/account', extra: [linkLauncherProvider.overrideWithValue(web)]);
      await openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('openWhatsapp')));
      await tester.pumpAndSettle();
      expect(web.opened.single, startsWith('https://wa.me/91'));
    });

    testWidgets('offline: Open WhatsApp is disabled with the reason; Copy message still works', (tester) async {
      final s = sample();
      final fake = FakeLauncher();
      final c = await app(tester, '/customers/${s.c.id}/account', extra: [linkLauncherProvider.overrideWithValue(fake)]);
      c.read(settingsProvider.notifier).set((x) => x.copyWith(sync: SyncState.offline));
      await tester.pumpAndSettle();
      await openDialog(tester);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('openWhatsapp'))).onPressed, isNull);
      expect(find.text('Needs internet; you are offline'), findsOneWidget);
      await tester.tap(find.text('Copy message'));
      await tester.pumpAndSettle();
      expect(find.text('Message copied'), findsOneWidget);
      expect(fake.opened, isEmpty);
    });

    testWidgets('no WhatsApp number: asks for it first, refuses nonsense, accepts 10 digits and enables the button', (tester) async {
      final s = sample(withPhone: false);
      final fake = FakeLauncher();
      final c = await app(tester, '/customers/${s.c.id}/account', extra: [linkLauncherProvider.overrideWithValue(fake)]);
      await openDialog(tester);
      expect(find.text('This customer has no WhatsApp number yet. Add one to continue.'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('openWhatsapp'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('remPhone')), '12345');
      await tester.tap(find.text('Save number'));
      await tester.pump();
      expect(find.text('That does not look like a mobile number. Try 98765 43210.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('remPhone')), '098765-43210');
      await tester.tap(find.text('Save number'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('openWhatsapp'))).onPressed, isNotNull);
      expect(c.read(customersProvider).firstWhere((x) => x.id == s.c.id).phone, '098765-43210');
      await tester.tap(find.byKey(const ValueKey('openWhatsapp')));
      await tester.pumpAndSettle();
      expect(fake.opened.single, contains('phone=919876543210'));
    });

    testWidgets('24-hour guard: asks "Send again?" and only opens if the person says yes', (tester) async {
      final s = sample();
      final fake = FakeLauncher();
      final c = await app(tester, '/customers/${s.c.id}/account', extra: [linkLauncherProvider.overrideWithValue(fake)]);
      c.read(reminderLogProvider.notifier).record(customerId: s.c.id, amountDue: s.a.balance, message: 'earlier', at: fixedNow.subtract(const Duration(hours: 2)));
      await tester.pumpAndSettle();
      await openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('openWhatsapp')));
      await tester.pumpAndSettle();
      expect(find.text('Already reminded'), findsOneWidget);
      expect(find.textContaining('Reminded today at'), findsOneWidget);
      expect(fake.opened, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.opened, isEmpty, reason: 'No: nothing opened');
      await tester.tap(find.byKey(const ValueKey('openWhatsapp')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send again'));
      await tester.pumpAndSettle();
      expect(fake.opened.length, 1);
    });

    testWidgets('if WhatsApp cannot be opened nothing is counted', (tester) async {
      final s = sample();
      final fake = FakeLauncher(ok: false);
      final c = await app(tester, '/customers/${s.c.id}/account', extra: [linkLauncherProvider.overrideWithValue(fake)]);
      final before = c.read(reminderLogProvider).countFor(s.c.id);
      await openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('openWhatsapp')));
      await tester.pumpAndSettle();
      expect(c.read(reminderLogProvider).countFor(s.c.id), before);
      expect(find.text('Could not open WhatsApp. Use Copy message instead.'), findsOneWidget);
    });
  });

  group('Shop profile > Messages to customers and Credit', () {
    testWidgets('template, tones, placeholders, UPI, guard hours, country code; credit limit mode (now on the Shop profile page)', (tester) async {
      final c = await app(tester, '/shop', size: const ScreenSpec('tall', 1920, 3000));
      expect(find.text('Reminders'), findsWidgets);
      expect(find.text('{amount_due}'), findsOneWidget);
      expect(find.text('{upi_id}'), findsOneWidget);
      expect(find.text('UPI ID (shown in the message)'), findsOneWidget);
      expect(find.text('Ask before reminding again within (hours)'), findsOneWidget);
      expect(find.text('Default country code'), findsOneWidget);
      expect(find.text('When a bill goes over the credit limit'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('templateField')), 'Hello {customer_name}, {amount_due} pending');
      await tester.pump();
      expect(c.read(shopProvider).templateFriendly, 'Hello {customer_name}, {amount_due} pending');
      await tester.ensureVisible(find.text('Use the standard text'));
      await tester.tap(find.text('Use the standard text'));
      await tester.pumpAndSettle();
      expect(c.read(shopProvider).templateFriendly, contains('Greetings from'));
      expect(tester.takeException(), isNull);
    });
  });
}
