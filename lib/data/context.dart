import 'package:drift/drift.dart';
import 'db/app_database.dart';
import 'hlc.dart';

/// Who is working: the person's name for the audit columns ("by"), and their role (the UI hides what the role may not do; the
/// Firestore rules are the real gate).
class Actor {
  const Actor({this.name = 'Owner', this.email = '', this.role = 'owner'});
  final String name, email, role;
  bool get isOwner => role == 'owner';
  bool get isManagerUp => role == 'owner' || role == 'manager';
}

/// Everything a repository needs: the database, this device's id and clock, and who is acting.
class DataContext {
  DataContext({required this.db, required this.deviceId, DateTime Function()? clock, this.actor = const Actor()})
      : _clock = clock ?? DateTime.now,
        hlc = Hlc(deviceId, nowMs: clock == null ? null : () => clock().millisecondsSinceEpoch);

  final AppDatabase db;
  final String deviceId;
  final Hlc hlc;
  final DateTime Function() _clock;
  Actor actor;

  DateTime now() => _clock();
  int nowMs() => _clock().millisecondsSinceEpoch;

  /// The local calendar day of [t] as `YYYY-MM-DD` (reports and the summary tables use the shop's local day).
  static String dayOf(DateTime t) => '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// `YYYY-MM` of [t].
  static String monthOf(DateTime t) => '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}';
}

/// Small helpers so repositories read as SQL. [exec] and [rows] accept plain Dart values (int, String, null, double).
extension SqlHelpers on DatabaseConnectionUser {
  Future<void> exec(String sql, [List<Object?> args = const []]) => customStatement(sql, args);

  Future<List<QueryRow>> rows(String sql, [List<Object?> args = const []]) => customSelect(sql, variables: [for (final a in args) _v(a)]).get();

  Future<QueryRow?> row(String sql, [List<Object?> args = const []]) async {
    final r = await rows(sql, args);
    return r.isEmpty ? null : r.first;
  }

  Future<int> scalarInt(String sql, [List<Object?> args = const []]) async {
    final r = await row(sql, args);
    if (r == null) return 0;
    final v = r.data.values.first;
    return v == null ? 0 : (v as num).toInt();
  }

  /// The id of the row just inserted by [exec] (valid inside the same transaction).
  Future<int> lastRowId() => scalarInt('SELECT last_insert_rowid()');
}

Variable _v(Object? a) {
  if (a == null) return const Variable<Object>(null);
  if (a is int) return Variable<int>(a);
  if (a is String) return Variable<String>(a);
  if (a is double) return Variable<double>(a);
  if (a is bool) return Variable<int>(a ? 1 : 0);
  throw ArgumentError('Unsupported SQL value ${a.runtimeType}');
}

/// Puts (or re-puts) a document in the upload queue. Editing the same document again before it is sent replaces the pending
/// row, so one document is uploaded once. Must be called inside the same transaction as the change itself.
Future<void> enqueue(DataContext cx, DatabaseConnectionUser tx, String coll, String docId, {String op = 'set', int holdMs = 0}) async {
  final now = cx.nowMs();
  await tx.exec(
    'INSERT INTO outbox(coll, doc_id, op, stamp, state, attempts, hold_until, created_at) VALUES (?,?,?,?,?,?,?,?) '
    "ON CONFLICT(coll, doc_id) DO UPDATE SET op = excluded.op, stamp = excluded.stamp, state = 'pending', attempts = 0, last_error = NULL, hold_until = excluded.hold_until",
    [coll, docId, op, cx.hlc.next(), 'pending', 0, holdMs == 0 ? 0 : now + holdMs, now],
  );
}

/// Next number of a counter, inside the caller's transaction (gapless: the row is incremented in the same transaction as the
/// document that uses it, so a number is never skipped or repeated).
Future<int> nextCounter(DatabaseConnectionUser tx, String name) async {
  await tx.exec('INSERT INTO counters(name, value) VALUES (?, 1) ON CONFLICT(name) DO UPDATE SET value = value + 1', [name]);
  return tx.scalarInt('SELECT value FROM counters WHERE name = ?', [name]);
}
