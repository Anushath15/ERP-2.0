import 'package:sqlite3/common.dart' show SqliteException;

/// What went wrong when the database could not be opened or used, in terms a screen can explain to a shop owner.
enum DbProblem { tooNew, locked, readOnly, cannotOpen, notDatabase, corrupt, diskFull, other }

class DatabaseOpenException implements Exception {
  const DatabaseOpenException(this.problem, {this.detail = '', this.fileVersion, this.appVersion});
  final DbProblem problem;
  final String detail;
  final int? fileVersion, appVersion;
  @override
  String toString() => 'DatabaseOpenException($problem${detail.isEmpty ? '' : ': $detail'})';
}

/// Maps a SQLite error to a [DbProblem]. Result codes: 5 BUSY, 6 LOCKED, 8 READONLY, 10 IOERR, 11 CORRUPT, 13 FULL, 14 CANTOPEN, 26 NOTADB.
DbProblem classifySqlite(SqliteException e) {
  final code = e.resultCode & 0xff;
  return switch (code) {
    5 || 6 => DbProblem.locked,
    8 => DbProblem.readOnly,
    11 => DbProblem.corrupt,
    13 => DbProblem.diskFull,
    14 => DbProblem.cannotOpen,
    26 => DbProblem.notDatabase,
    _ => DbProblem.other,
  };
}
