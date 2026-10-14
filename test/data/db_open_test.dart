import 'dart:io';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:erp2/data/db/app_database.dart';
import 'package:erp2/data/db/errors.dart';
import 'package:erp2/data/db/open.dart';
import 'package:erp2/data/platform/disk_space.dart';

// The database file: creation, the product search index, refusing a newer or damaged file, disk space levels.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('erp2_db_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> addProduct(AppDatabase db, String id, String name, {String barcode = ''}) => db.customStatement(
      'INSERT INTO products(id, name, barcode, price_paise, created_at, updated_at, device_id) VALUES (?,?,?,?,?,?,?)', [id, name, barcode, 1000, 1, 1, 'dev']);

  test('a new database is created with WAL, foreign keys on, the current version and the product search index', () async {
    final db = await openShopDatabase('${tmp.path}/shop.sqlite');
    expect((await db.customSelect('PRAGMA journal_mode').getSingle()).data.values.first, 'wal');
    expect((await db.customSelect('PRAGMA foreign_keys').getSingle()).data.values.first, 1);
    expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.first, currentSchemaVersion);
    await addProduct(db, 'p1', 'HAVELLS 1 WAY SWITCH WHITE', barcode: '890123');
    await addProduct(db, 'p2', 'ANCHOR 3 PIN SOCKET');
    final hits = await db.customSelect("SELECT p.id FROM product_fts f JOIN products p ON p.rowid = f.rowid WHERE product_fts MATCH ?", variables: [const Variable('switch*')]).get();
    expect(hits.map((r) => r.read<String>('id')), ['p1']);
    final byCode = await db.customSelect("SELECT p.id FROM product_fts f JOIN products p ON p.rowid = f.rowid WHERE product_fts MATCH ?", variables: [const Variable('barcode:890123')]).get();
    expect(byCode.single.read<String>('id'), 'p1');
    await db.close();
  });

  test('the search index follows edits and removals of a product', () async {
    final db = AppDatabase(NativeDatabase.memory(), native: false);
    await addProduct(db, 'p1', 'OLD NAME');
    await db.customStatement("UPDATE products SET name = 'NEW NAME' WHERE id = 'p1'");
    Future<int> count(String q) async => (await db.customSelect('SELECT p.id FROM product_fts f JOIN products p ON p.rowid = f.rowid WHERE product_fts MATCH ?', variables: [Variable(q)]).get()).length;
    expect(await count('old'), 0);
    expect(await count('new'), 1);
    await db.customStatement("DELETE FROM products WHERE id = 'p1'");
    expect(await count('new'), 0);
    await db.close();
  });

  test('reopening keeps the data', () async {
    final path = '${tmp.path}/shop.sqlite';
    var db = await openShopDatabase(path);
    await addProduct(db, 'p1', 'ONE');
    await db.close();
    db = await openShopDatabase(path);
    expect((await db.customSelect('SELECT COUNT(*) c FROM products').getSingle()).read<int>('c'), 1);
    await db.close();
  });

  test('a database made by a NEWER program is never opened or changed', () async {
    final path = '${tmp.path}/shop.sqlite';
    final raw = sqlite3.open(path);
    raw.execute('CREATE TABLE t(x)');
    raw.execute('PRAGMA user_version = ${currentSchemaVersion + 5}');
    raw.close();
    final before = File(path).readAsBytesSync();
    await expectLater(
      openShopDatabase(path),
      throwsA(isA<DatabaseOpenException>().having((e) => e.problem, 'problem', DbProblem.tooNew).having((e) => e.fileVersion, 'fileVersion', currentSchemaVersion + 5)),
    );
    expect(File(path).readAsBytesSync(), before, reason: 'not a single byte may change');
  });

  test('a file that is not a database, and a damaged one, give a clear problem and are not overwritten', () async {
    final junk = File('${tmp.path}/junk.sqlite')..writeAsBytesSync(List.generate(5000, (i) => i % 251));
    await expectLater(openShopDatabase(junk.path), throwsA(isA<DatabaseOpenException>().having((e) => e.problem, 'problem', DbProblem.notDatabase)));
    expect(junk.lengthSync(), 5000);
  });

  test('disk space levels: warn below 500 MB, block below 100 MB, unknown never blocks', () {
    expect(diskLevel(null), DiskLevel.unknown);
    expect(diskLevel(10 * 1024 * 1024 * 1024), DiskLevel.ok);
    expect(diskLevel(499 * 1024 * 1024), DiskLevel.low);
    expect(diskLevel(99 * 1024 * 1024), DiskLevel.full);
    expect(diskLevel(100 * 1024 * 1024), DiskLevel.low);
  });

  test('free disk space is reported on this computer (and for a folder that does not exist yet)', () async {
    final free = await freeDiskBytes('${tmp.path}/not/yet/created');
    expect(free, isNotNull);
    expect(free, greaterThan(1024 * 1024));
  });
}
