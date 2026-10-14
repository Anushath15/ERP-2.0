import 'dart:io';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'app_database.dart';
import 'errors.dart';

/// The version number inside an existing database file (0 = empty or new). Throws [DatabaseOpenException] for a file that is not a database.
int readUserVersion(File file) {
  if (!file.existsSync() || file.lengthSync() == 0) return 0;
  Database? raw;
  try {
    raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
    return raw.select('PRAGMA user_version').first.values.first as int;
  } on SqliteException catch (e) {
    throw DatabaseOpenException(classifySqlite(e), detail: e.message);
  } finally {
    raw?.close();
  }
}

Future<AppDatabase> openShopDatabase(String location, {bool background = false}) async {
  final file = File(location);
  try {
    await file.parent.create(recursive: true);
  } on FileSystemException catch (e) {
    throw DatabaseOpenException(DbProblem.cannotOpen, detail: e.message);
  }
  final v = readUserVersion(file);
  if (v > currentSchemaVersion) throw DatabaseOpenException(DbProblem.tooNew, fileVersion: v, appVersion: currentSchemaVersion);
  if (v > 0 && v < currentSchemaVersion) {
    // a safety copy before any migration; a failed migration leaves the original untouched
    final raw = sqlite3.open(file.path);
    try {
      final copy = File('${file.path}.before-v$v.bak');
      if (copy.existsSync()) copy.deleteSync();
      raw.execute('VACUUM INTO ?', [copy.path]);
    } finally {
      raw.close();
    }
  }
  final executor = background ? NativeDatabase.createInBackground(file) : NativeDatabase(file);
  final db = AppDatabase(executor);
  try {
    await db.customSelect('SELECT 1').get(); // opens the file and runs create / migrate
  } on SqliteException catch (e) {
    await db.close();
    throw DatabaseOpenException(classifySqlite(e), detail: e.message);
  } catch (e) {
    await db.close();
    if (e is DatabaseOpenException) rethrow;
    throw DatabaseOpenException(DbProblem.other, detail: '$e');
  }
  return db;
}
