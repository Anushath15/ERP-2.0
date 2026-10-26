import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/models.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// What these tests prove: notifications brought in from ERP 1 (time as text, read as true/false, a title and a message) show instead of breaking the page
// (a grey box in the built program); the bell on the top bar counts the unread ones and opens the list; the side menu has no Notifications item.
void main() {
  test('a record keeps working whatever form ERP 1 gave its fields', () {
    const r = Rec('n', {'time': '2026-10-12T14:02:11.204Z', 'read': false, 'qty': '12', 'amount': 12.6});
    expect(r.d('time')!.toUtc(), DateTime.utc(2026, 10, 12, 14, 2, 11, 204));
    expect(r.i('read'), 0);
    expect(r.i('qty'), 12);
    expect(r.i('amount'), 13);
    expect(r.d('missing'), isNull);
    expect(r.date('missing'), DateTime.fromMillisecondsSinceEpoch(0));
    expect(const Rec('x', {'read': true}).i('read'), 1);
  });

  testWidgets('ERP 1 notifications show; the bell counts the unread and opens them', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('wide', 1500, 1000), location: '/', motion: MotionLevel.off, followSystemMotion: false);
    final before = c.read(recsProvider('notifications')).where((r) => r.i('read') == 0).length;
    c.read(recsProvider('notifications').notifier).showOnly(const Rec('NOT-000002', {
      'type': 'warning',
      'title': 'Low Stock Alert',
      'message': '1" PVC Coupler is running low (89 left).',
      'time': '2026-10-13T05:21:03.274Z',
      'read': false,
    }));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('topbar-notifications')), findsOneWidget);
    expect(find.text('${before + 1}'), findsWidgets, reason: 'the count on the bell');
    await tester.tap(find.byKey(const ValueKey('topbar-notifications')));
    await tester.pumpAndSettle();
    expect(GoRouter.of(tester.element(find.byType(Scaffold).first)).routerDelegate.currentConfiguration.uri.path, '/notifications');
    expect(tester.takeException(), isNull);
    expect(find.text('Low Stock Alert'), findsOneWidget);
    expect(find.textContaining('PVC Coupler is running low'), findsOneWidget);
  });
}
