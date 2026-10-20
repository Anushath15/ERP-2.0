import 'dart:typed_data';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/export/export_table.dart';
import 'package:erp2/domain/product_sheet/sheet_reader.dart';
import 'package:erp2/features/products/product_excel.dart';
import 'package:erp2/fake/data_providers.dart' show appDataProvider;
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove, on the Products page: Excel > the sheet is saved with every product; a sheet filled in and uploaded shows what will change before
// anything is saved; applying it changes the products (MRP, stock...) on the screen and in the database; a damaged file or a sheet with problems is explained.
void main() {
  testWidgets('download the sheet, fill MRP and counted stock in two rows, upload it, see the preview, apply', (tester) async {
    final saver = FakeSaver();
    PickedSheet? toPick;
    final c = await pumpApp(tester, size: const ScreenSpec('wide', 1366, 1400), location: '/products', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [
      fileSaverProvider.overrideWithValue(saver),
      sheetPickerProvider.overrideWithValue(() async => toPick),
    ]);
    await tester.tap(find.byKey(const ValueKey('productsExcel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('xlDownload')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('xlSaved')), findsOneWidget);
    final file = saver.saved.entries.single;
    expect(file.key, matches(RegExp(r'^ASK-ERP-Products-\d{4}-\d{2}-\d{2}\.xlsx$')));
    final rows = readXlsxRows(file.value);
    expect(rows.first.first, 'Code');
    expect(rows.length, c.read(productsProvider).length + 1, reason: 'every product is in the sheet');

    // the owner fills MRP (column I) and the counted stock (column L) of the first two products
    final p1 = c.read(productsProvider).firstWhere((p) => p.code == rows[1][0]);
    final p2 = c.read(productsProvider).firstWhere((p) => p.code == rows[2][0]);
    rows[1][8] = '999';
    rows[1][11] = '7';
    rows[2][11] = '3';
    final table = ExportTable(name: 'Products', headers: rows.first, rows: [for (final r in rows.skip(1)) r]);
    toPick = PickedSheet('filled.xlsx', encodeXlsx(table));
    await tester.tap(find.byKey(const ValueKey('xlUpload')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('xlCounts')), findsOneWidget);
    expect(find.textContaining('2 to update, 0 new'), findsOneWidget);
    expect(find.textContaining('MRP'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('xlApply')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('xlApply')), findsNothing, reason: 'the dialog closed');
    final a = c.read(productsProvider).firstWhere((p) => p.id == p1.id);
    final b = c.read(productsProvider).firstWhere((p) => p.id == p2.id);
    expect(a.mrpPaise, 99900);
    expect(a.stockMilli, 7000);
    expect(b.stockMilli, 3000);
    final fromDb = (await tester.runAsync(() => c.read(appDataProvider).catalog.product(p1.id)))!;
    expect((fromDb.mrpPaise, fromDb.stockMilli), (99900, 7000));
  });

  testWidgets('a file that is not an Excel file, and a sheet whose rows have problems, are explained and change nothing', (tester) async {
    PickedSheet? toPick = PickedSheet('broken.xlsx', Uint8List.fromList([1, 2, 3]));
    final c = await pumpApp(tester, size: const ScreenSpec('wide', 1366, 1400), location: '/products', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [sheetPickerProvider.overrideWithValue(() async => toPick)]);
    await tester.tap(find.byKey(const ValueKey('productsExcel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('xlUpload')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('xlError')), findsOneWidget);
    expect(find.textContaining('not an Excel'), findsOneWidget);
    final before = c.read(productsProvider).map((p) => p.mrpPaise).toList();
    toPick = PickedSheet('bad.csv', Uint8List.fromList('Code,Name,MRP\nZZZ-0001,,100\n${c.read(productsProvider).first.code},,abc\n'.codeUnits));
    await tester.tap(find.byKey(const ValueKey('xlUpload')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 with a problem'), findsOneWidget);
    expect(find.textContaining('is not in your products'), findsOneWidget);
    expect(find.textContaining('"abc" is not a number'), findsOneWidget);
    expect(find.byKey(const ValueKey('xlApply')), findsNothing, reason: 'nothing to apply');
    expect(c.read(productsProvider).map((p) => p.mrpPaise).toList(), before);
  });
}
