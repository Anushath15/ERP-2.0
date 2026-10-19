import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/stats.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// What this proves: a bill saved after All bills was first opened is in the list when All bills is opened again (it used to show the old list,
// found by clicking through the program like a person: open All bills, make a bill, open All bills again).
void main() {
  testWidgets('All bills opened again after a sale shows the new bill', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/sales', motion: MotionLevel.off, followSystemMotion: false);
    final d = c.read(appDataProvider);
    final p = c.read(productsProvider).first;
    final saved = (await tester.runAsync(() => d.bills.saveBill(SaveBillInput(idemKey: 'fresh-1', at: DateTime(2026, 10, 13, 17, 31), lines: [BillLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: 1000, ratePaise: 12345, gstBp: p.gstBp)]))))!;
    await tester.runAsync(() => c.read(statsProvider.notifier).refresh());
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/estimates');
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/sales');
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();
    expect(find.textContaining(saved.number), findsWidgets, reason: 'the bill just made is the newest row');
  });
}
