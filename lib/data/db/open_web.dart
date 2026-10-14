import 'app_database.dart';

// The browser database (sqlite3 compiled to WebAssembly, stored in OPFS or IndexedDB) is wired in a later step of this gate.
Future<AppDatabase> openShopDatabase(String location, {bool background = false}) => throw UnsupportedError('Web database is wired in step 2A-web');
