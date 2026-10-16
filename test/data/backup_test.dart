import 'dart:io';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/backup/backup.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/open.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'helpers.dart';

Future<String> makeShop(String path, {String shop = 'shop-A', int products = 5}) async {
  final db = await openShopDatabase(path);
  final d = AppData(DataContext(db: db, deviceId: 'dev-test'));
  await d.settings.put('shop.id', shop);
  for (var i = 0; i < products; i++) {
    await d.catalog.saveProduct(sampleProduct('Item $i', id: 'p$i'), create: true);
  }
  await d.catalog.saveCustomer(sampleCustomer('Ravi', id: 'c1'), create: true);
  await db.close();
  return path;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('backup'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('names, rotation and freshness (pure rules)', () {
    test('a name says when, which computer, which program version and why; and reads back', () {
      final at = DateTime(2026, 10, 16, 14, 30, 12);
      final n = BackupInfo.fileName(at: at, device: '0192ab34-cdef-7000-8000-123456789abc', appVersion: '2.0.0-proto.3', kind: BackupKind.auto);
      expect(n, 'ASKERP_20261016-143012_0192ab34_v2.0.0-proto.3_auto.sqlite');
      final i = BackupInfo.fromName('/x/$n', n)!;
      expect(i.at, at);
      expect(i.kind, BackupKind.auto);
      expect(i.device, '0192ab34');
      expect(i.appVersion, '2.0.0-proto.3');
      final a = BackupInfo.fileName(at: at, device: 'abcdef12', appVersion: '2.0.0', kind: BackupKind.archive, fy: 'FY2025-26');
      expect(BackupInfo.fromName('/x/$a', a)!.fy, 'FY2025-26');
      expect(BackupInfo.fromName('/x/notes.sqlite', 'notes.sqlite'), isNull, reason: 'a file that is not ours is never treated as a backup');
    });

    test('rotation over 400 days of 2-hourly backups keeps 7 days, 4 weeks, 12 months and the newest, and never touches safety copies', () {
      final now = DateTime(2026, 10, 16, 18);
      final all = <BackupInfo>[];
      for (var h = 0; h < 400 * 12; h++) {
        final at = now.subtract(Duration(hours: h * 2));
        final n = BackupInfo.fileName(at: at, device: 'abcdef12', appVersion: '2.0.0', kind: BackupKind.auto);
        all.add(BackupInfo.fromName('/b/$n', n)!);
      }
      final safety = BackupInfo.fileName(at: now.subtract(const Duration(days: 300)), device: 'abcdef12', appVersion: '2.0.0', kind: BackupKind.safety);
      all.add(BackupInfo.fromName('/b/$safety', safety)!);
      final keep = backupsToKeep(all);
      expect(keep.length, lessThanOrEqualTo(7 + 4 + 12 + 1));
      expect(keep, contains(all.first.name), reason: 'the newest is always kept');
      expect(keep, isNot(contains(safety)), reason: 'safety copies are not part of the rotation (it never removes them)');
      final kept = all.where((b) => keep.contains(b.name)).toList();
      final days = {for (final b in kept) '${b.at.year}-${b.at.month}-${b.at.day}'};
      for (var d = 0; d < 7; d++) {
        final t = now.subtract(Duration(days: d));
        expect(days, contains('${t.year}-${t.month}-${t.day}'), reason: 'day $d');
      }
      final months = {for (final b in kept) '${b.at.year}-${b.at.month}'};
      expect(months.length, greaterThanOrEqualTo(12));
    });

    test('with fewer backups than the limits, everything is kept', () {
      final now = DateTime(2026, 10, 16, 18);
      final all = [
        for (var i = 0; i < 3; i++) BackupInfo.fromName('/b/x', BackupInfo.fileName(at: now.subtract(Duration(days: i)), device: 'abcdef12', appVersion: '2', kind: BackupKind.manual))!
      ];
      expect(backupsToKeep(all), hasLength(3));
      expect(backupsToKeep(const []), isEmpty);
    });

    test('the Home colours: fine, amber after 2 days, red after 7 days or never', () {
      final now = DateTime(2026, 10, 16, 12);
      expect(freshnessOf(now.subtract(const Duration(hours: 47)), now), BackupFreshness.fresh);
      expect(freshnessOf(now.subtract(const Duration(days: 2)), now), BackupFreshness.amber);
      expect(freshnessOf(now.subtract(const Duration(days: 6, hours: 23)), now), BackupFreshness.amber);
      expect(freshnessOf(now.subtract(const Duration(days: 7)), now), BackupFreshness.red);
      expect(freshnessOf(null, now), BackupFreshness.red);
    });

    test('financial years run April to March', () {
      expect(financialYearOf(DateTime(2026, 3, 31)), 'FY2025-26');
      expect(financialYearOf(DateTime(2026, 4, 1)), 'FY2026-27');
      expect(previousFinancialYear(DateTime(2026, 4, 2)), 'FY2025-26');
      expect(previousFinancialYear(DateTime(2027, 1, 2)), 'FY2025-26');
    });
  });

  group('making a backup', () {
    test('a consistent, checked snapshot while the shop keeps saving; the file says what it holds; the live data is untouched', () async {
      final live = await makeShop(p.join(dir.path, 'shop.sqlite'));
      final db = await openShopDatabase(live);
      final d = AppData(DataContext(db: db, deviceId: 'dev-test'));
      final folder = p.join(dir.path, 'Backups');
      var running = true;
      final writer = () async {
        var i = 100;
        while (running) {
          await d.catalog.saveProduct(sampleProduct('Busy $i', id: 'b$i'), create: true);
          i++;
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      }();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final info = await createBackup(livePath: live, folder: folder, deviceId: 'abcdef12-0000', appVersion: '2.0.0-proto.3', kind: BackupKind.manual);
      running = false;
      await writer;
      expect(File(info.path).existsSync(), isTrue);
      expect(listBackups(folder).map((b) => b.name), [info.name]);
      expect(Directory(folder).listSync().any((f) => f.path.endsWith('.part')), isFalse);
      final ins = await inspectBackup(info.path, expectedShopId: 'shop-A');
      expect(ins.ok, isTrue, reason: '${ins.problem}');
      expect(ins.contents!.products, greaterThanOrEqualTo(5));
      expect(ins.contents!.customers, 1);
      expect(ins.contents!.device, 'abcdef12-0000');
      expect(ins.contents!.appVersion, '2.0.0-proto.3');
      expect(File('${info.path}-wal').existsSync(), isFalse, reason: 'a plain single file');
      expect(await db.scalarInt('SELECT COUNT(*) FROM products'), greaterThan(ins.contents!.products - 1));
      await db.close();
    });

    test('not enough free space: a plain message, nothing left behind', () async {
      final live = await makeShop(p.join(dir.path, 'shop.sqlite'));
      final folder = p.join(dir.path, 'Backups');
      await expectLater(createBackup(livePath: live, folder: folder, deviceId: 'abcdef12', appVersion: '2', freeBytesOverride: 1024), throwsA(isA<BackupException>().having((e) => e.message, 'message', contains('not enough free space'))));
      expect(listBackups(folder), isEmpty);
    });

    test('a folder that cannot be used (a file is in the way, or the drive is gone) is explained', () async {
      final live = await makeShop(p.join(dir.path, 'shop.sqlite'));
      final blocker = File(p.join(dir.path, 'notafolder'))..writeAsStringSync('x');
      await expectLater(createBackup(livePath: live, folder: p.join(blocker.path, 'sub'), deviceId: 'abcdef12', appVersion: '2'), throwsA(isA<BackupException>().having((e) => e.message, 'message', contains('backup folder cannot be used'))));
    });

    test('no data file yet: a plain message', () async {
      await expectLater(createBackup(livePath: p.join(dir.path, 'none.sqlite'), folder: p.join(dir.path, 'B'), deviceId: 'abcdef12', appVersion: '2'), throwsA(isA<BackupException>()));
    });

    test('a half-made backup left by a crash is cleaned up and never listed', () async {
      final live = await makeShop(p.join(dir.path, 'shop.sqlite'));
      final folder = p.join(dir.path, 'B');
      Directory(folder).createSync();
      File(p.join(folder, 'ASKERP_20260101-000000_abcdef12_v2_auto.sqlite.part')).writeAsStringSync('junk');
      expect(listBackups(folder), isEmpty);
      await createBackup(livePath: live, folder: folder, deviceId: 'abcdef12', appVersion: '2');
      expect(Directory(folder).listSync().where((f) => f.path.endsWith('.part')), isEmpty);
    });
  });

  group('checking a file before it is restored', () {
    late String good;
    setUp(() async {
      final live = await makeShop(p.join(dir.path, 'shop.sqlite'));
      good = (await createBackup(livePath: live, folder: p.join(dir.path, 'B'), deviceId: 'abcdef12', appVersion: '2.0.0')).path;
    });

    test('a good backup of this shop passes and shows what it holds', () async {
      final r = await inspectBackup(good, expectedShopId: 'shop-A');
      expect(r.ok, isTrue);
      expect(r.contents!.products, 5);
    });

    test('a file from another shop is refused', () async {
      expect((await inspectBackup(good, expectedShopId: 'shop-B')).problem, RestoreProblem.otherShop);
    });

    test('a corrupted file is refused', () async {
      final bad = File(p.join(dir.path, 'bad.sqlite'))..writeAsBytesSync(File(good).readAsBytesSync());
      final bytes = bad.readAsBytesSync();
      for (var i = 4096; i < bytes.length - 100; i++) {
        bytes[i] = 0xAB; // everything after the first page
      }
      bad.writeAsBytesSync(bytes);
      final r = await inspectBackup(bad.path, expectedShopId: 'shop-A');
      expect(r.ok, isFalse);
      expect([RestoreProblem.corrupt, RestoreProblem.notDatabase], contains(r.problem));
    });

    test('a file made by a newer version of the program is refused', () async {
      final newer = File(p.join(dir.path, 'newer.sqlite'))..writeAsBytesSync(File(good).readAsBytesSync());
      final db = sqlite3.open(newer.path);
      db.execute('PRAGMA user_version = 99');
      db.close();
      expect((await inspectBackup(newer.path, expectedShopId: 'shop-A')).problem, RestoreProblem.tooNew);
    });

    test('a file that is not a database, or has no shop mark, is refused', () async {
      final txt = File(p.join(dir.path, 'a.sqlite'))..writeAsStringSync('hello, this is not a database at all');
      expect((await inspectBackup(txt.path, expectedShopId: 'shop-A')).problem, RestoreProblem.notDatabase);
      final noId = File(p.join(dir.path, 'noid.sqlite'))..writeAsBytesSync(File(good).readAsBytesSync());
      final db = sqlite3.open(noId.path);
      db.execute("DELETE FROM kv WHERE name = 'shop.id'");
      db.close();
      expect((await inspectBackup(noId.path, expectedShopId: 'shop-A')).problem, RestoreProblem.unknownShop);
      expect((await inspectBackup(p.join(dir.path, 'missing.sqlite'), expectedShopId: 'x')).ok, isFalse);
    });
  });

  group('rotation and copying on disk', () {
    test('rotation removes only what it should, keeps the newest, and does nothing if the newest is not a good file', () async {
      final live = await makeShop(p.join(dir.path, 'shop.sqlite'));
      final folder = p.join(dir.path, 'B');
      final base = DateTime(2026, 10, 16, 12);
      final first = await createBackup(livePath: live, folder: folder, deviceId: 'abcdef12', appVersion: '2', now: base);
      for (var d = 1; d < 30; d++) {
        final n = BackupInfo.fileName(at: base.subtract(Duration(days: d)), device: 'abcdef12', appVersion: '2', kind: BackupKind.auto);
        File(first.path).copySync(p.join(folder, n));
      }
      final safety = BackupInfo.fileName(at: base.subtract(const Duration(days: 200)), device: 'abcdef12', appVersion: '2', kind: BackupKind.safety);
      File(first.path).copySync(p.join(folder, safety));
      final removed = await rotateBackups(folder);
      expect(removed, isNotEmpty);
      final left = listBackups(folder).map((b) => b.name).toSet();
      expect(left, contains(first.name));
      expect(left, contains(safety));
      expect(left.length, lessThan(31));
      File(first.path).writeAsBytesSync(List.filled(4000, 1));
      expect(await rotateBackups(folder), isEmpty);
    });

    test('copying to a pen drive or another folder is proved identical', () async {
      final live = await makeShop(p.join(dir.path, 'shop.sqlite'));
      final info = await createBackup(livePath: live, folder: p.join(dir.path, 'B'), deviceId: 'abcdef12', appVersion: '2');
      final copy = await copyBackupTo(info.path, p.join(dir.path, 'pen', 'drive'));
      expect(File(copy).readAsBytesSync(), File(info.path).readAsBytesSync());
      expect(Directory(p.join(dir.path, 'pen', 'drive')).listSync().any((f) => f.path.endsWith('.part')), isFalse);
    });
  });
}
