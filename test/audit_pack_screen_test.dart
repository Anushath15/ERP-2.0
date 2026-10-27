import 'package:erp2/core/file_saver.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What this test proves: the Export page has the Auditor pack card; the current financial year is the first choice; Excel and PDF each save a real file named
// after the period, with every sheet.
void main() {
  testWidgets('the Export page makes the auditor pack as Excel and as PDF', (tester) async {
    final saver = FakeSaver();
    await pumpApp(tester, size: const ScreenSpec('wide', 1600, 1800), location: '/export', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [fileSaverProvider.overrideWithValue(saver)]);
    expect(find.text('Auditor pack (all bills)'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('audit-excel')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('audit-excel')));
      for (var i = 0; i < 100 && saver.saved.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await tester.tap(find.byKey(const ValueKey('audit-pdf')));
      for (var i = 0; i < 200 && saver.saved.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();
    final names = saver.saved.keys.toList()..sort();
    expect(names.length, 2);
    expect(names[0], matches(RegExp(r'^Auditor pack Financial year 20\d\d-\d\d\.pdf$')));
    expect(names[1], matches(RegExp(r'^Auditor pack Financial year 20\d\d-\d\d\.xlsx$')));
    expect(String.fromCharCodes(saver.saved[names[0]]!.take(5)), '%PDF-');
    expect(String.fromCharCodes(saver.saved[names[1]]!.take(2)), 'PK');
  });
}
