import 'integrity_stub.dart' if (dart.library.io) 'integrity_native.dart' as impl;

/// SQLite's own check of the database FILE on a separate connection in a separate isolate, so billing carries on while it runs
/// (a check of a 4.4 GB file takes about 7 seconds, the full one minutes). Returns the problems found (empty = healthy).
/// Returns an empty list where there is no file to check (the browser).
Future<List<String>> checkDatabaseFile(String path, {bool full = false}) => impl.checkDatabaseFile(path, full: full);

/// The program's own check (docs/data-model.md "Invariants": summaries against the raw rows) on a separate connection in a separate
/// isolate, so a million bills can be checked without holding up a sale. Returns plain-English problems (empty = all fine).
Future<List<String>> selfCheckFile(String path, {bool deep = false}) => impl.selfCheckFile(path, deep: deep);
