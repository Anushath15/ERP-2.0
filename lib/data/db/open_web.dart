import 'package:drift/wasm.dart';
import 'app_database.dart';
import 'errors.dart';

/// The browser database: sqlite3 compiled to WebAssembly, kept in the browser's own storage (OPFS where the browser has it, IndexedDB
/// otherwise), run in a worker so a slow query never freezes the page. The two files it needs sit next to index.html.
Future<AppDatabase> openShopDatabase(String location, {bool background = false}) async {
  try {
    final result = await WasmDatabase.open(databaseName: location, sqlite3Uri: Uri.parse('sqlite3.wasm'), driftWorkerUri: Uri.parse('drift_worker.js'));
    final db = AppDatabase(result.resolvedExecutor, native: false);
    await db.customSelect('SELECT 1').get();
    return db;
  } on DatabaseTooNewException catch (e) {
    throw DatabaseOpenException(DbProblem.tooNew, fileVersion: e.fileVersion, appVersion: e.appVersion);
  } catch (e, st) {
    if (e is DatabaseOpenException) rethrow;
    final t = '$st';
    throw DatabaseOpenException(DbProblem.other, detail: '$e ${t.length > 500 ? t.substring(0, 500) : t}');
  }
}
