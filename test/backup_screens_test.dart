import 'dart:convert';
import 'dart:io';
import 'package:erp2/core/app_paths_io.dart';
import 'package:erp2/core/data_mode.dart';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/backup/backup.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/open.dart';
import 'package:erp2/features/backup/backups_screen.dart';
import 'package:erp2/fake/backup_controller.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/health.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'data/helpers.dart';
import 'helpers.dart';

class Env {
  Env(this.dir, this.paths, this.live, this.switched, this.picked);
  final Directory dir;
  final FileAppPaths paths;
  final String live;
  final List<DataMode> switched;
  String? picked;
  List<Override> get overrides => [
        appPathsProvider.overrideWithValue(paths),
        dbFilePathProvider.overrideWithValue(live),
        deviceIdProvider.overrideWithValue('abcdef12-0000'),
        dataDirProvider.overrideWithValue(paths.dataDir),
        modeSwitcherProvider.overrideWithValue((m) async => switched.add(m)),
        folderPickerProvider.overrideWithValue(() async => picked),
        backupFilePickerProvider.overrideWithValue(() async => picked),
      ];
}

Future<Env> makeEnv(WidgetTester tester, {String shop = 'shop-A'}) async {
  final dir = Directory.systemTemp.createTempSync('bkui');
  addTearDown(() => dir.deleteSync(recursive: true));
  final paths = FileAppPaths(p.join(dir.path, 'ASK ERP 2.0'));
  final live = paths.dbLocation('shop');
  await tester.runAsync(() async {
    final db = await openShopDatabase(live);
    final d = AppData(DataContext(db: db, deviceId: 'dev-test'));
    await d.settings.put('shop.id', shop);
    for (var i = 0; i < 4; i++) {
      await d.catalog.saveProduct(sampleProduct('Item $i', id: 'p$i'), create: true);
    }
    await db.close();
    await paths.writeText('backup.folder', p.join(dir.path, 'Backups'));
  });
  return Env(dir, paths, live, [], null);
}

/// Lets real file work finish: every step of it needs the real clock to move AND the test clock to pump, many times in turn.
Future<void> real(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 25; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await t.pump(const Duration(milliseconds: 25));
  }
}

void main() {
  setUpAll(() => runBackupWorkInline = true);
  tearDownAll(() => runBackupWorkInline = false);

  testWidgets('Backups page: never backed up shows red; Back up now makes a checked backup and lists it', (tester) async {
    final env = await makeEnv(tester);
    final c = await pumpApp(tester, size: desktop1366, location: '/backups', extraOverrides: env.overrides);
    await tester.runAsync(() => c.read(backupControllerProvider.notifier).load());
    await real(tester, 200);
    expect(find.text('No backup has been made yet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('backupNow')));
    await real(tester, 2500);
    expect(c.read(backupControllerProvider).lastError, isNull);
    expect(find.textContaining('Last backup:'), findsWidgets, reason: 'running=${c.read(backupControllerProvider).running} last=${c.read(backupControllerProvider).last} folder=${c.read(backupControllerProvider).folder} avail=${c.read(backupControllerProvider.notifier).available}');
    expect(listBackups(p.join(env.dir.path, 'Backups')), hasLength(1));
    expect(find.textContaining('made by you'), findsOneWidget);
  });

  testWidgets('a backup that fails says so on every page, in plain words, and can be dismissed', (tester) async {
    final env = await makeEnv(tester);
    File(p.join(env.dir.path, 'blocker')).writeAsStringSync('x');
    await tester.runAsync(() => env.paths.writeText('backup.folder', p.join(env.dir.path, 'blocker', 'sub')));
    final c = await pumpApp(tester, size: desktop1366, location: '/', extraOverrides: env.overrides);
    await tester.runAsync(() => c.read(backupControllerProvider.notifier).load());
    await tester.runAsync(() => c.read(backupControllerProvider.notifier).run(BackupKind.manual));
    await real(tester, 300);
    expect(find.textContaining('backup folder cannot be used'), findsOneWidget);
    await tester.tap(find.text('Dismiss').first);
    await tester.pump();
    expect(find.textContaining('backup folder cannot be used'), findsNothing);
  });

  testWidgets('Home shows the last backup line (red when there is none)', (tester) async {
    final env = await makeEnv(tester);
    final c = await pumpApp(tester, size: desktop1366, location: '/', extraOverrides: env.overrides);
    await tester.runAsync(() => c.read(backupControllerProvider.notifier).load());
    await real(tester, 200);
    expect(find.byKey(const ValueKey('backupStatusLine')), findsOneWidget);
    expect(find.text('No backup has been made yet'), findsOneWidget);
  });

  testWidgets('Restore: pick a backup, see what is inside, confirm; a safety copy is made first, then the restore is requested and the program restarts on it', (tester) async {
    final env = await makeEnv(tester);
    final c = await pumpApp(tester, size: desktop1366, location: '/restore', extraOverrides: env.overrides);
    await tester.runAsync(() async {
      await c.read(backupControllerProvider.notifier).load();
      await c.read(backupControllerProvider.notifier).run(BackupKind.manual);
    });
    await real(tester, 300);
    final first = listBackups(p.join(env.dir.path, 'Backups')).single;
    await tester.tap(find.byKey(ValueKey('pick-${first.name}')));
    await real(tester, 800);
    expect(find.textContaining('Inside: 4 products'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('restoreNow')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('restoreNow')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('first saved as a safety copy'), findsOneWidget);
    await tester.tap(find.text('Restore this backup').last);
    await real(tester, 3000);
    final all = listBackups(p.join(env.dir.path, 'Backups'));
    expect(all.any((b) => b.kind == BackupKind.safety), isTrue, reason: 'the current data was backed up first');
    final req = jsonDecode(File(p.join(env.paths.dataDir, 'swap.pending.json')).readAsStringSync()) as Map<String, dynamic>;
    expect(req['kind'], 'restore');
    expect(env.switched, [DataMode.real]);
    expect(File(first.path).existsSync(), isTrue, reason: 'the backup itself is untouched');
  });

  testWidgets('Restore refuses another shop file, a damaged file and a non-backup, with a plain message and no Restore button', (tester) async {
    final env = await makeEnv(tester);
    // the shop in the program has a mark; a backup made by ANOTHER shop must be refused
    final other = await makeEnv(tester, shop: 'shop-OTHER');
    final c = await pumpApp(tester, size: desktop1366, location: '/restore', extraOverrides: env.overrides);
    await tester.runAsync(() => c.read(appDataProvider).settings.put('shop.id', 'shop-A'));
    await tester.runAsync(() => c.read(backupControllerProvider.notifier).load());
    final foreign = (await tester.runAsync(() => createBackup(livePath: other.live, folder: p.join(other.dir.path, 'B'), deviceId: 'abcdef12', appVersion: '2')))!;
    env.picked = foreign.path;
    await tester.tap(find.byKey(const ValueKey('chooseBackupFile')));
    await real(tester, 800);
    expect(find.textContaining('belongs to a different shop'), findsOneWidget);
    expect(find.byKey(const ValueKey('restoreNow')), findsNothing);
    final junk = File(p.join(env.dir.path, 'junk.sqlite'))..writeAsStringSync('this is not a database');
    env.picked = junk.path;
    await tester.tap(find.byKey(const ValueKey('chooseBackupFile')));
    await real(tester, 800);
    expect(find.textContaining('not a backup of ASK ERP'), findsOneWidget);
    expect(find.byKey(const ValueKey('restoreNow')), findsNothing);
    expect(env.switched, isEmpty);
  });

  for (final (size, scale) in [(phone360, 2.0), (desktop1280, 1.5)]) {
    testWidgets('Backups and Restore lay out cleanly with data at ${size.name}, text ${(scale * 100).round()}%', (tester) async {
      final env = await makeEnv(tester);
      final c = await pumpApp(tester, size: size, location: '/backups', textScale: scale, extraOverrides: env.overrides);
      await tester.runAsync(() async {
        await c.read(backupControllerProvider.notifier).load();
        await c.read(backupControllerProvider.notifier).run(BackupKind.manual);
        await c.read(backupControllerProvider.notifier).run(BackupKind.archive, fy: 'FY2025-26');
      });
      await real(tester, 300);
      expect(tester.takeException(), isNull, reason: 'backups');
      c.read(backupControllerProvider.notifier).state.toString();
      await tester.tap(find.byKey(const ValueKey('restoreLink')));
      await real(tester, 400);
      expect(find.text('Restore an old year'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'restore');
    });
  }
}
