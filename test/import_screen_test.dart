import 'dart:convert';
import 'dart:io';
import 'package:erp2/core/data_mode.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/health.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'helpers.dart';
import 'import_helpers.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets('a file that is not an ERP 1 backup is refused in plain words and cannot be imported', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/import', extraOverrides: importOverrides(runner: FakeRunner(), text: '{"hello": "world"}'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('chooseBackup')));
    await settle(tester);
    expect(find.text('This file cannot be used'), findsOneWidget);
    expect(find.textContaining('not an ERP 1 backup'), findsOneWidget);
    expect(find.byKey(const ValueKey('createNewData')), findsNothing);
    expect(find.text('Nothing has been changed yet. Your current data is untouched.'), findsOneWidget);
  });

  testWidgets('text that is not JSON at all is refused too', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/import', extraOverrides: importOverrides(runner: FakeRunner(), text: 'MZ binary garbage'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('chooseBackup')));
    await settle(tester);
    expect(find.text('This file cannot be used'), findsOneWidget);
    expect(find.byKey(const ValueKey('createNewData')), findsNothing);
  });

  testWidgets('a good backup shows counts, sales, the three stock values and the checks, and offers to create the new data', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/import', extraOverrides: importOverrides(runner: FakeRunner()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('chooseBackup')));
    await settle(tester);
    expect(find.text('What we found'), findsOneWidget);
    expect(find.textContaining('80 products'), findsOneWidget);
    expect(find.textContaining('Average cost (recommended)'), findsOneWidget);
    expect(find.textContaining('Latest buying price'), findsOneWidget);
    expect(find.textContaining('Selling price'), findsWidgets);
    expect(find.textContaining('exactly as ERP 1 saved it'), findsOneWidget);
    final create = tester.widget<FilledButton>(find.byKey(const ValueKey('createNewData')));
    expect(create.onPressed, isNotNull);
  });

  testWidgets('a backup that fails its own check code cannot be imported', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/import', extraOverrides: importOverrides(runner: FakeRunner(), text: syntheticBackup(tamper: true)));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('chooseBackup')));
    await settle(tester);
    expect(find.textContaining('does not match its check code'), findsOneWidget);
    final create = tester.widget<FilledButton>(find.byKey(const ValueKey('createNewData')));
    expect(create.onPressed, isNull);
  });

  testWidgets('create -> checks -> confirm: only the second confirmation asks for a switch, and then it writes the request and restarts on real data', (tester) async {
    final dir = Directory.systemTemp.createTempSync('imp_screen');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory(p.join(dir.path, 'import')).createSync();
    final switched = <DataMode>[];
    final runner = FakeRunner();
    // the page asks the runner to write into <data folder>/import/...; the fake pretends it did, so make the file the request will point to
    await pumpApp(tester, size: desktop1366, location: '/import', extraOverrides: [
      ...importOverrides(runner: runner, dataDir: dir.path),
      modeSwitcherProvider.overrideWithValue((m) async => switched.add(m)),
    ]);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('chooseBackup')));
    await settle(tester);
    expect(runner.creates, 0, reason: 'nothing is written before the first confirmation');
    await tester.tap(find.byKey(const ValueKey('createNewData')));
    await settle(tester);
    expect(runner.creates, 1);
    expect(find.text('The new data is ready and passed every check'), findsOneWidget);
    expect(find.textContaining('80 products, 12 customers and 60 bills'), findsOneWidget);
    expect(switched, isEmpty, reason: 'creating the new file does not switch anything');
    expect(File(p.join(dir.path, 'swap.pending.json')).existsSync(), isFalse);
    await tester.ensureVisible(find.byKey(const ValueKey('switchNow')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('switchNow')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100))); // the request file is written on the real disk
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(File(p.join(dir.path, 'swap.pending.json')).existsSync(), isTrue, reason: 'request file');
    expect(find.textContaining('did not happen'), findsNothing, reason: tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(' | '));
    expect(switched, [DataMode.real]);
    final req = jsonDecode(File(p.join(dir.path, 'swap.pending.json')).readAsStringSync()) as Map<String, dynamic>;
    expect(req['kind'], 'import');
    expect(req['expected'], containsPair('products', 80));
    expect(p.isWithin(dir.path, p.join(dir.path, req['file'] as String)), isTrue);
  });

  testWidgets('a check that did not pass blocks the switch', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/import', extraOverrides: importOverrides(runner: FakeRunner(createOk: false)));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('chooseBackup')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('createNewData')));
    await settle(tester);
    expect(find.textContaining('A check did not pass'), findsOneWidget);
    expect(find.byKey(const ValueKey('switchNow')), findsNothing);
  });

  testWidgets('without a data folder (the browser) the page says importing needs the Windows or Mac program', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/import', extraOverrides: [dataDirProvider.overrideWithValue(null)]);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('needs the Windows or Mac program'), findsOneWidget);
    expect(find.byKey(const ValueKey('chooseBackup')), findsNothing);
  });

  for (final (size, scale) in [(phone360, 2.0), (desktop1280, 1.5)]) {
    testWidgets('the Import page lays out cleanly in every step at ${size.name}, text ${(scale * 100).round()}%', (tester) async {
      await pumpApp(tester, size: size, location: '/import', textScale: scale, extraOverrides: importOverrides(runner: FakeRunner()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('chooseBackup')));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'preview');
      await tester.ensureVisible(find.byKey(const ValueKey('createNewData')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('createNewData')));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'checks');
      expect(find.byKey(const ValueKey('switchNow')), findsOneWidget);
    });
  }
}
