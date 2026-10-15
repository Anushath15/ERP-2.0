import 'dart:io';
import 'dart:isolate';
import 'package:sqlite3/sqlite3.dart';
import '../repo/self_check.dart';

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

Future<List<String>> selfCheckFile(String path, {bool deep = false}) {
  return Isolate.run(() {
    if (!File(path).existsSync()) return <String>[];
    Database? db;
    final out = <String>[];
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
      for (final q in selfCheckQueries(deep: deep)) {
        final n = db.select('SELECT COUNT(*) FROM (${q.sql})').first.values.first as int;
        if (n > 0) out.add('${q.what} ($n)');
      }
      final fk = db.select('PRAGMA foreign_key_check');
      if (fk.isNotEmpty) out.add('Records that point at something that is missing (${fk.length})');
    } on SqliteException catch (e) {
      out.add('${e.message} (code ${e.resultCode})');
    } finally {
      db?.close();
    }
    return out;
  });
}
