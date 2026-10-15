import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:erp2/core/plain_error.dart';
import 'package:erp2/data/db/errors.dart';
import 'package:erp2/data/db/integrity.dart';
import 'package:erp2/data/db/open.dart';
import 'package:erp2/data/platform/disk_space.dart';
import 'package:erp2/data/write_queue.dart';
import 'package:erp2/fake/health.dart';

// A file that is damaged, locked, read-only; a disk that is nearly full: the program says so plainly and never loses or half-writes anything.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('erp2_res_'));
  tearDown(() {
    try {
      for (final f in tmp.listSync()) {
        if (f is File && Platform.isWindows) Process.runSync('attrib', ['-R', f.path]);
      }
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> addProduct(dynamic db, String id) => db.customStatement("INSERT INTO products(id, name, price_paise, created_at, updated_at, device_id) VALUES ('$id','ITEM $id ${'x' * 80}',1,1,1,'d')") as Future<void>;

  group('the health check of the file (separate connection)', () {
    test('a healthy file and a missing file report nothing wrong', () async {
      final path = '${tmp.path}/shop.sqlite';
      final db = await openShopDatabase(path);
      await addProduct(db, 'p');
      expect(await checkDatabaseFile(path), isEmpty);
      expect(await checkDatabaseFile(path, full: true), isEmpty);
      expect(await checkDatabaseFile('${tmp.path}/nothing.sqlite'), isEmpty);
      await db.close();
    });

    test('a file with damaged pages is found by the full check, and the quick check never crashes on it', () async {
      final path = '${tmp.path}/shop.sqlite';
      final db = await openShopDatabase(path);
      await db.transaction(() async {
        for (var i = 0; i < 2000; i++) {
          await addProduct(db, 'p$i');
        }
      });
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      await db.close();
      final f = File(path);
      final bytes = f.readAsBytesSync();
      for (var i = 20000; i < 90000; i++) {
        bytes[i] = (i * 7919 + 13) % 251; // scribble over a stretch of pages in the middle
      }
      f.writeAsBytesSync(bytes);
      final full = await checkDatabaseFile(path, full: true);
      expect(full, isNotEmpty, reason: 'the full check sees the damage');
      await checkDatabaseFile(path); // the quick check may or may not notice, but it must answer
    });
  });

  group('the data file is read-only or locked by another program', () {
    test('a read-only file is refused with a clear reason and is not changed', () async {
      final path = '${tmp.path}/shop.sqlite';
      final db = await openShopDatabase(path);
      await db.close();
      for (final s in ['-wal', '-shm']) {
        final x = File('$path$s');
        if (x.existsSync()) x.deleteSync();
      }
      if (Platform.isWindows) {
        Process.runSync('attrib', ['+R', path]);
      } else {
        Process.runSync('chmod', ['444', path]);
      }
      final before = File(path).readAsBytesSync();
      await expectLater(openShopDatabase(path), throwsA(isA<DatabaseOpenException>().having((e) => e.problem, 'problem', DbProblem.readOnly)));
      expect(File(path).readAsBytesSync(), before);
    });

    test('a file another program holds locked gives "busy" after a short wait (not a crash), and works again once it lets go', () async {
      final path = '${tmp.path}/shop.sqlite';
      final first = await openShopDatabase(path);
      await first.close();
      final other = sqlite3.open(path);
      other.execute('PRAGMA journal_mode = DELETE'); // so the lock is a real file lock the second connection runs into
      other.execute('BEGIN EXCLUSIVE');
      final sw = Stopwatch()..start();
      await expectLater(openShopDatabase(path, busyTimeoutMs: 300), throwsA(isA<DatabaseOpenException>().having((e) => e.problem, 'problem', DbProblem.locked)));
      expect(sw.elapsedMilliseconds, lessThan(5000));
      other.execute('ROLLBACK');
      other.close();
      final ok = await openShopDatabase(path);
      await ok.close();
    });

    test('the plain-English words for each kind of failure never contain a code or a path', () {
      for (final code in [5, 6, 8, 10, 11, 13, 14, 1]) {
        final m = plainError(SqliteException(extendedResultCode: code, message: r'boom C:\secret\path'));
        expect(m, isNot(contains('C:')), reason: 'code $code');
        expect(m, isNot(contains('boom')));
        expect(m.length, greaterThan(20));
      }
    });
  });

  group('disk space', () {
    test('writes are refused below 100 MB free with a plain message, allowed above, and a disk that cannot say never blocks', () async {
      final guard = DiskGuard('C:/data', reader: (_) async => 50 * 1024 * 1024);
      final q = WriteQueue(beforeWrite: guard.checkBeforeWrite);
      await expectLater(q.run(() async => 1), throwsA(isA<Object>().having((e) => plainError(e), 'message', contains('50 MB free'))));
      await q.flush(); // flushing never fails: it only waits
      final low = DiskGuard('C:/data', reader: (_) async => 300 * 1024 * 1024); // low, but not blocked
      expect(await low.level(), DiskLevel.low);
      expect(await WriteQueue(beforeWrite: low.checkBeforeWrite).run(() async => 7), 7);
      expect(await WriteQueue(beforeWrite: DiskGuard('C:/data', reader: (_) async => null).checkBeforeWrite).run(() async => 8), 8);
      expect(await DiskGuard(null).level(), DiskLevel.unknown);
    });

    test('a failed fire-and-forget write is reported to the screen instead of being lost silently', () async {
      Object? reported;
      final q = WriteQueue(onError: (e, s) => reported = e);
      q.add(() async => throw StateError('disk said no'));
      await q.flush();
      expect(reported, isA<StateError>());
    });

    test('the answer about free space is remembered for a short while so every save does not ask the disk', () async {
      var asked = 0;
      var t = DateTime(2026, 1, 1);
      final g = DiskGuard('C:/x', reader: (_) async {
        asked++;
        return 10 * 1024 * 1024 * 1024;
      }, clock: () => t);
      await g.level();
      await g.level();
      expect(asked, 1);
      t = t.add(const Duration(seconds: 25));
      await g.level();
      expect(asked, 2);
    });
  });

  test('the save queue keeps order and a failing job does not stop the ones after it', () async {
    final q = WriteQueue();
    final order = <int>[];
    final a = q.run(() async {
      order.add(1);
    });
    final b = q.run<void>(() async => throw StateError('x')).catchError((Object _) {});
    final c = q.run(() async {
      order.add(3);
    });
    await Future.wait([a, b, c]);
    expect(order, [1, 3]);
  });
}
