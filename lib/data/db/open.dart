import 'app_database.dart';
import 'open_stub.dart' if (dart.library.io) 'open_native.dart' if (dart.library.js_interop) 'open_web.dart' as impl;

/// Opens (or creates) the shop database. [location] is a file path on Windows, macOS and Android, and a database name in the browser.
/// Throws [DatabaseOpenException] with a problem a screen can explain: data from a newer program, locked, read-only, damaged...
/// [background] puts SQLite in its own isolate so a slow query can never freeze the screen (the app uses it; tests do not).
Future<AppDatabase> openShopDatabase(String location, {bool background = false}) => impl.openShopDatabase(location, background: background);
