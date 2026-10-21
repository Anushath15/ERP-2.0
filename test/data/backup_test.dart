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

  group('one file that is updated (the routine backups)', () {
    const device = 'abcdef12-0000';
    Future<BackupInfo> roll(String live, String folder, DateTime at, {BackupKind kind = BackupKind.auto}) =>
        createBackup(livePath: live, folder: folder, deviceId: device, appVersion: '2.0.0', kind: kind, now: at, rolling: true, freeBytesOverride: 1 << 40);
    Future<void> addProduct(String live, String id) async {
      final db = await openShopDatabase(live);
      final d = AppData(DataContext(db: db, deviceId: 'dev-test'));
      await d.catalog.saveProduct(sampleProduct('More $id', id: id), create: true);
      await db.close();
    }

    int products(String path) {
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        return db.select('SELECT COUNT(*) FROM products').first.values.first as int;
      } finally {
        db.close();
      }
    }

    test('names: the file has one fixed name per computer; the copy from just before is kept beside it; neither is ever removed by the rotation', () {
      expect(BackupInfo.rollingName(device), 'ASKERP_abcdef12_latest.sqlite');
      expect(BackupInfo.previousName(device), 'ASKERP_abcdef12_latest.previous.sqlite');
      final i = BackupInfo.fromName('/b/ASKERP_abcdef12_latest.previous.sqlite', 'ASKERP_abcdef12_latest.previous.sqlite')!;
      expect((i.rolling, i.previous, i.device), (true, true, 'abcdef12'));
      expect(BackupInfo.fromName('/b/x', BackupInfo.rollingName(device))!.previous, isFalse);
      final keep = backupsToKeep([i, BackupInfo.fromName('/b/y', BackupInfo.rollingName(device))!]);
      expect(keep, isEmpty, reason: 'the rotation does not look at these two files');
    });

    test('every routine backup updates the same file; the one before is kept as previous; always two files however many backups', () async {
      final live = await makeShop(p.join(dir.path, 'shop.sqlite'));
      final folder = p.join(dir.path, 'Backups');
      final first = await roll(live, folder, DateTime(2026, 10, 20, 10));
      expect(p.basename(first.path), 'ASKERP_abcdef12_latest.sqlite');
      expect(Directory(folder).listSync().whereType<File>().map((f) => p.basename(f.path)), ['ASKERP_abcdef12_latest.sqlite']);
      expect(products(first.path), 5);
      await addProduct(live, 'n1');
      final second = await roll(live, folder, DateTime(2026, 10, 20, 12), kind: BackupKind.closing);
      expect(second.path, first.path, reason: 'the same file');
      expect(products(second.path), 6, reason: 'updated with what is new');
      final prev = p.join(folder, 'ASKERP_abcdef12_latest.previous.sqlite');
      expect(File(prev).existsSync(), isTrue);
      expect(products(prev), 5, reason: 'the previous copy is the file as it was before the update');
      for (var i = 0; i < 4; i++) {
        await addProduct(live, 'm$i');
        await roll(live, folder, DateTime(2026, 10, 20, 13 + i), kind: i.isEven ? BackupKind.manual : BackupKind.auto);
      }
      expect(Directory(folder).listSync().whereType<File>().length, 2, reason: 'no pile of files');
      expect(Directory(folder).listSync().whereType<File>().any((f) => f.path.endsWith('.part')), isFalse);
      expect(products(first.path), 10);
      expect(products(prev), 9);
    });

    test('the listing reads when and why the file was made from inside it; newest first; both files can be checked for a restore', () async {
      final live = await makeShop(p.join(dir.path, 'shop.sqlite'));
      final folder = p.join(dir.path, 'Backups');
      await roll(live, folder, DateTime(2026, 10, 20, 10));
      await addProduct(live, 'n1');
      await roll(live, folder, DateTime(2026, 10, 21, 9), kind: BackupKind.closing);
      final list = listBackups(folder);
      expect(list.map((b) => (b.previous, b.at, b.kind)), [(false, DateTime(2026, 10, 21, 9), BackupKind.closing), (true, DateTime(2026, 10, 20, 10), BackupKind.auto)]);
      for (final b in list) {
        final r = await inspectBackup(b.path, expectedShopId: 'shop-A');
        expect(r.ok, isTrue, reason: b.name);
      }
    });

    test('a damaged file is never promoted to the previous copy: the older good copy stays', () async {
      final live = await makeShop(p.join(dir.path, 'shop.sqlite'));
      final folder = p.join(dir.path, 'Backups');
      await roll(live, folder, DateTime(2026, 10, 20, 10));
      await addProduct(live, 'n1');
      await roll(live, folder, DateTime(2026, 10, 20, 11)); // now: latest (6), previous (5)
      final latest = p.join(folder, 'ASKERP_abcdef12_latest.sqlite');
      final prev = p.join(folder, 'ASKERP_abcdef12_latest.previous.sqlite');
      File(latest).writeAsBytesSync(List<int>.filled(4096, 7)); // the latest gets damaged
      await addProduct(live, 'n2');
      await roll(live, folder, DateTime(2026, 10, 20, 12));
      expect(products(latest), 7, reason: 'the new good backup took the name');
      expect(products(prev), 5, reason: 'the damaged file was not kept as the previous copy; the older good one stays');
    });

    test('safety copies and the yearly archive are one-off protections: each keeps its own dated file even when rolling is asked for', () async {
      final live = await makeShop(p.join(dir.path, 'shop.sqlite'));
      final folder = p.join(dir.path, 'Backups');
      final a = await roll(live, folder, DateTime(2026, 10, 20, 10), kind: BackupKind.safety);
      final b = await createBackup(livePath: live, folder: folder, deviceId: device, appVersion: '2.0.0', kind: BackupKind.archive, fy: 'FY2025-26', now: DateTime(2026, 10, 20, 10, 5), rolling: true, freeBytesOverride: 1 << 40);
      expect(a.name, contains('_safety'));
      expect(b.name, contains('_archive-FY2025-26'));
      expect(a.rolling, isFalse);
      expect(Directory(folder).listSync().whereType<File>().length, 2);
    });
  });
}
