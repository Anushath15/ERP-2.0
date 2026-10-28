import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/models.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'data/helpers.dart' as data;
import 'helpers.dart';

// What these tests prove: a dealer keeps more than a name: GST number, bank account, bank, IFSC, contact person, collection agent and his phone, e-mail,
// notes. They are saved in the shop's file and read back, shown on the dealer page, and found by the search. Only the shop or organization name and
// its phone must be filled in.
void main() {
  test('every detail of a dealer is saved, read back and changed', () async {
    final d = data.memoryShop();
    addTearDown(d.close);
    const full = {'name': 'Kovai Pipes', 'phone': '9876543210', 'gstin': '33AAAAA0000A1Z5', 'contact': 'Mr Raja', 'agentName': 'Selvam', 'agentPhone': '9123456780', 'account': '123456789012', 'bank': 'SBI', 'ifsc': 'SBIN0000001', 'email': 'a@b.in', 'city': 'Coimbatore', 'address': '12 Main Road', 'notes': 'pays on Fridays'};
    await d.catalog.saveDealer(const Rec('d1', full), create: true);
    final back = (await d.catalog.dealers()).single;
    for (final e in full.entries) {
      expect(back.s(e.key), e.value, reason: e.key);
    }
    await d.catalog.saveDealer(back.with_({'agentName': 'Murugan', 'account': '999'}), create: false);
    final again = (await d.catalog.dealers()).single;
    expect((again.s('agentName'), again.s('account'), again.s('gstin')), ('Murugan', '999', '33AAAAA0000A1Z5'));
  });

  testWidgets('Add dealer: name and phone are required, the rest is optional; the details show on the dealer page', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 2200), location: '/dealers', motion: MotionLevel.off, followSystemMotion: false);
    await tester.tap(find.text('Add dealer').first);
    await tester.pumpAndSettle();
    for (final label in ['Shop or organization name', 'Phone', 'GST number (optional)', 'Contact person', 'Collection agent name', 'Collection agent phone', 'Bank account number', 'Bank name', 'IFSC code', 'Email', 'Town', 'Address', 'Note']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    Finder box(String label) => find.ancestor(of: find.text(label), matching: find.byType(TextFormField)).first;
    final before = c.read(recsProvider('dealers')).length;
    await tester.enterText(box('Shop or organization name'), 'Test Traders');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(c.read(recsProvider('dealers')).length, before, reason: 'no phone: not saved');
    await tester.enterText(box('Phone'), '94222 12345');
    await tester.enterText(box('Collection agent name'), 'Selvam');
    await tester.enterText(box('Collection agent phone'), '9123456780');
    await tester.enterText(box('Bank account number'), '555566667777');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final added = c.read(recsProvider('dealers')).firstWhere((r) => r.s('name') == 'Test Traders');
    expect((added.s('agentName'), added.s('account'), added.s('gstin')), ('Selvam', '555566667777', ''));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/dealers/${added.id}');
    await tester.pumpAndSettle();
    expect(find.text('Shop or organization name'), findsOneWidget);
    expect(find.text('Collection agent name'), findsOneWidget);
    expect(find.text('Selvam'), findsOneWidget);
    expect(find.text('555566667777'), findsOneWidget);
  });
}
