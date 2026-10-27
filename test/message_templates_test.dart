import 'dart:convert';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/core/link_launcher.dart';
import 'package:erp2/core/reveal_file.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/credit/dues.dart';
import 'package:erp2/domain/message_templates.dart';
import 'package:erp2/domain/orders.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/features/credit/statement_share.dart';
import 'package:erp2/features/print/doc_share.dart';
import 'package:erp2/features/print/print_preview.dart' show samplePrintDoc;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// What these tests prove: every WhatsApp message (bill, estimate, statement, order) comes from a template the shop edits on the Shop profile page. The standard
// texts say what the old fixed messages said. A line whose detail is empty (no UPI ID, nothing due, no note) is left out. The shop's own text is used everywhere
// and is saved with the shop (a strange saved value is ignored). The editor puts details in with a tap, previews the message, and goes back to the standard
// text; the standard text itself is never stored, so it stays current.
void main() {
  final now = DateTime(2026, 10, 27, 12);
  final products = seedProducts();

  test('filling: empty details drop their line, unknown ones stay as typed, the length is capped', () {
    const t = 'Hello {customer_name}\nPay by UPI: {upi_id}\nTypo stays: {custmer}\nBye';
    expect(fillMessage(t, {'{customer_name}': 'Sibi', '{upi_id}': ''}), 'Hello Sibi\nTypo stays: {custmer}\nBye');
    expect(fillMessage(t, {'{customer_name}': 'Sibi', '{upi_id}': 'shop@oksbi'}), contains('Pay by UPI: shop@oksbi'));
    final long = fillMessage(List.filled(400, 'a line of text').join('\n'), const {});
    expect(long.length, lessThanOrEqualTo(maxMessageLength));
  });

  test('the standard texts say what the old messages said', () {
    final bill = samplePrintDoc(products, now); // part paid: a balance is due
    final m = docMessage(bill, shopName: 'Senthil Enterprises', shopPhone: '9342363155', upiId: 'shop@oksbi');
    expect(m, startsWith('Hello Murugan Electricals,\nThis is Senthil Enterprises.'));
    expect(m, contains('Your bill A-020001 dated'));
    expect(m, contains('Balance to pay: ₹'));
    expect(m, contains('Pay by UPI: shop@oksbi'));
    expect(m, contains('For any question: 9342363155'));
    final paid = PrintDoc(mode: DocMode.invoice, number: 'A-1', date: now, customer: 'Sibi', lines: bill.lines, calc: bill.calc, pay: bill.pay, receivedPaise: bill.calc.grandTotal);
    final pm = docMessage(paid, shopName: 'S', shopPhone: '', upiId: 'shop@oksbi');
    expect(pm, isNot(contains('Balance to pay')), reason: 'nothing due: the line is left out');
    expect(pm, isNot(contains('UPI')), reason: 'nothing due: no UPI line');
    expect(pm, isNot(contains('For any question')), reason: 'no shop phone: no line');
    final est = docMessage(samplePrintDoc(products, now, mode: DocMode.estimation), shopName: 'S', shopPhone: '9');
    expect(est, contains('Your estimate EST-00231'));
    expect(est, contains('This is an estimate, not a bill.'));
    final st = Statement(from: DateTime(2000), to: now, openingPaise: 0, lines: const [], closingPaise: 345000);
    final sm = statementMessage(customerName: 'Sibi', shopName: 'S', shopPhone: '', upiId: 'shop@oksbi', statement: st, today: now);
    expect(sm, contains('Your account statement (up to 27/10/2026) is attached.'));
    expect(sm, contains('Amount to pay: ₹'));
    expect(sm, contains('Pay by UPI: shop@oksbi'));
    final none = statementMessage(customerName: 'Sibi', shopName: 'S', shopPhone: '', upiId: 'shop@oksbi', statement: Statement(from: DateTime(2000), to: now, openingPaise: 0, lines: const [], closingPaise: 0), today: now);
    expect(none, contains('Nothing is due'));
    expect(none, isNot(contains('UPI')));
  });

  test('the shop\'s own text is used for every kind of message', () {
    final t = {
      'bill': 'Vanakkam {customer_name}! Bill {number}: {amount}. Balance {balance_due}.',
      'estimate': 'Estimate {number} for {customer_name}: {amount}',
      'statement': 'Statement for {customer_name}: {balance_text}',
      'order': 'To {dealer_name}: please send\n{item_list}',
    };
    final bill = samplePrintDoc(products, now);
    expect(docMessage(bill, shopName: 'S', shopPhone: '', templates: t), startsWith('Vanakkam Murugan Electricals! Bill A-020001: ₹'));
    expect(docMessage(samplePrintDoc(products, now, mode: DocMode.estimation), shopName: 'S', shopPhone: '', templates: t), startsWith('Estimate EST-00231 for'));
    final st = Statement(from: DateTime(2000), to: now, openingPaise: 0, lines: const [], closingPaise: 100000);
    expect(statementMessage(customerName: 'Sibi', shopName: 'S', shopPhone: '', upiId: '', statement: st, today: now, templates: t), 'Statement for Sibi: Amount to pay: ₹1,000.00');
    final o = orderMessage(dealerName: 'Kumar', shopName: 'S', shopPhone: '', number: 'PO-1', lines: const [OrderLine(productId: 'p', name: 'PIPE', unit: 'Nos', qtyMilli: 3000)], template: messageTemplateOf(t, MessageKind.order));
    expect(o, 'To Kumar: please send\n1. PIPE - 3 Nos');
  });

  test('saved with the shop; a strange saved value is ignored', () {
    const p = ShopProfile(messageTemplates: {'bill': 'Hi {customer_name}'});
    final back = ShopProfile.fromJson(jsonDecode(jsonEncode(p.toJson())));
    expect(back.messageTemplates, {'bill': 'Hi {customer_name}'});
    final bad = ShopProfile.fromJson({'messageTemplates': {'bill': 7, 'nonsense': 'x', 'estimate': '', 'order': 'x' * 3000, 'statement': 'ok {customer_name}'}});
    expect(bad.messageTemplates, {'statement': 'ok {customer_name}'});
    expect(ShopProfile.fromJson({'name': 'old shop'}).messageTemplates, isEmpty, reason: 'a shop saved before templates existed uses the standard texts');
  });

  testWidgets('Shop profile: pick a message, change it, put a detail in, see the preview, go back to the standard text', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 4200), location: '/shop', motion: MotionLevel.off, followSystemMotion: false);
    expect(find.text('WhatsApp messages'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('msg-kind-estimate')));
    await tester.tap(find.byKey(const ValueKey('msg-kind-estimate')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('msgTplField'))).controller!.text, defaultEstimateMessage, reason: 'the standard text to start from');
    await tester.enterText(find.byKey(const ValueKey('msgTplField')), 'Dear ');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('msg-ph-{customer_name}')));
    await tester.tap(find.byKey(const ValueKey('msg-ph-{customer_name}')));
    await tester.pumpAndSettle();
    expect(c.read(shopProvider).messageTemplates['estimate'], 'Dear {customer_name}');
    expect(find.descendant(of: find.byKey(const ValueKey('msgTplPreview')), matching: find.text('Dear Murugan Electricals')), findsOneWidget);
    expect(c.read(shopProvider).messageTemplates.containsKey('bill'), isFalse, reason: 'the bill message is untouched');
    await tester.ensureVisible(find.byKey(const ValueKey('msgTplReset')));
    await tester.tap(find.byKey(const ValueKey('msgTplReset')));
    await tester.pumpAndSettle();
    expect(c.read(shopProvider).messageTemplates.containsKey('estimate'), isFalse, reason: 'the standard text is not stored: it stays current');
  });

  testWidgets('the shop\'s own bill message is what WhatsApp opens with', (tester) async {
    final saver = FakeSaver(), launcher = FakeLauncher(), revealer = FakeRevealer();
    final c = await pumpApp(tester, size: const ScreenSpec('wide', 1600, 1400), location: '/sales', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [
      fileSaverProvider.overrideWithValue(saver),
      linkLauncherProvider.overrideWithValue(launcher),
      fileRevealerProvider.overrideWithValue(revealer),
    ]);
    c.read(shopProvider.notifier).set((x) => x.copyWith(messageTemplates: {'bill': 'Vanakkam {customer_name}, bill {number} ({amount}) attached. Nandri!'}));
    final b = (await tester.runAsync(() => c.read(appDataProvider).db.rows('SELECT id, number FROM bills WHERE cancelled = 0 ORDER BY billed_at DESC LIMIT 1')))!.single;
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/sales?open=${Uri.encodeQueryComponent(b.read<String>('id'))}');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('bill-whatsapp')));
    await tester.tap(find.byKey(const ValueKey('bill-whatsapp')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wa-phone')), '9876543210');
    await tester.tap(find.byKey(const ValueKey('wa-go')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wa-close')));
    await tester.pumpAndSettle();
    final url = Uri.decodeComponent(launcher.opened.single);
    expect(url, contains('Vanakkam'));
    expect(url, contains('bill ${b.read<String>('number')}'));
    expect(url, contains('Nandri!'));
  });
}
