import 'dart:io';
import 'dart:isolate';
import 'package:sqlite3/sqlite3.dart';

Future<List<String>> checkDatabaseFile(String path, {bool full = false}) {
  return Isolate.run(() {
    if (!File(path).existsSync()) return <String>[];
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
      final rows = db.select(full ? 'PRAGMA integrity_check' : 'PRAGMA quick_check');
      final out = [for (final r in rows) r.values.first.toString()];
      return out.length == 1 && out.first == 'ok' ? <String>[] : out;
    } on SqliteException catch (e) {
      return <String>['${e.message} (code ${e.resultCode})'];
    } finally {
      db?.close();
    }
  });
}
