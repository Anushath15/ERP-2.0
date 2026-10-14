import 'integrity_stub.dart' if (dart.library.io) 'integrity_native.dart' as impl;

/// SQLite's own check of the database FILE on a separate connection in a separate isolate, so billing carries on while it runs
/// (a check of a 3.6 GB file takes about 40 seconds, the full one minutes). Returns the problems found (empty = healthy).
/// Returns an empty list where there is no file to check (the browser).
Future<List<String>> checkDatabaseFile(String path, {bool full = false}) => impl.checkDatabaseFile(path, full: full);
