import 'dart:async';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// The schema version this build of the app understands. Raise it ONLY together with a numbered migration in
/// [AppDatabase.migrations], a new schema dump (`dart run drift_dev schema dump ...`) and a migration test.
const currentSchemaVersion = 2;

/// The database file was made by a NEWER version of the app. It is never opened (an old app could damage it).
class DatabaseTooNewException implements Exception {
  const DatabaseTooNewException(this.fileVersion, this.appVersion);
  final int fileVersion, appVersion;
  @override
  String toString() => 'This data was made by a newer version of the program (data version $fileVersion, this program understands up to $appVersion).';
}

/// When the write-ahead log is folded back into the main file. SQLite's own automatic checkpoint does it INSIDE the save that crosses 1,000 pages,
/// which made 1 save in ~20 take about 15 ms instead of 2 ms (measured, docs/perf-results.md). So the program does it in a quiet moment between saves,
/// and SQLite's automatic checkpoint stays as a net at [netPages] (it is never switched off, so the log can never grow without limit).
class CheckpointPolicy {
  const CheckpointPolicy({this.commitsBetween = 15, this.idleMs = 300, this.tickMs = 500, this.netPages = 4000});
  final int commitsBetween, idleMs, tickMs, netPages;
}

@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e, {this.native = true, this.busyTimeoutMs = 5000});

  /// How long a write waits for another program that has the file locked before it gives up.
  final int busyTimeoutMs;

  /// WAL and a durable fsync are for files on disk; the in-memory and browser databases ignore them.
  final bool native;

  Timer? _checkpointTimer;
  int _lastWriteMs = 0, _commitsSince = 0, _activeTransactions = 0;
  bool _checkpointBusy = false;

  /// How many controlled (idle-moment) checkpoints have run, for tests and the Health page.
  int controlledCheckpoints = 0;

  @override
  Future<T> transaction<T>(Future<T> Function() action, {bool requireNew = false}) async {
    _activeTransactions++;
    _lastWriteMs = DateTime.now().millisecondsSinceEpoch;
    try {
      return await super.transaction(action, requireNew: requireNew);
    } finally {
      _activeTransactions--;
      _lastWriteMs = DateTime.now().millisecondsSinceEpoch;
      _commitsSince++;
    }
  }

  /// Turns on idle-moment checkpoints (files on disk only). Safe to call once after opening; [close] stops it.
  Future<void> startControlledCheckpoints([CheckpointPolicy policy = const CheckpointPolicy()]) async {
    if (!native || _checkpointTimer != null) return;
    await customStatement('PRAGMA wal_autocheckpoint = ${policy.netPages}');
    _checkpointTimer = Timer.periodic(Duration(milliseconds: policy.tickMs), (_) async {
      if (_checkpointBusy || _activeTransactions > 0 || _commitsSince < policy.commitsBetween) return;
      if (DateTime.now().millisecondsSinceEpoch - _lastWriteMs < policy.idleMs) return;
      _checkpointBusy = true;
      try {
        _commitsSince = 0;
        await customSelect('PRAGMA wal_checkpoint(PASSIVE)').get(); // never blocks a writer; a busy result just means "next time"
        controlledCheckpoints++;
      } catch (_) {
        // the automatic net still applies; a failed checkpoint is not an error the person can act on
      } finally {
        _checkpointBusy = false;
      }
    });
  }

  @override
  Future<void> close() {
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
    return super.close();
  }

  @override
  int get schemaVersion => 2; // keep equal to [currentSchemaVersion] (a test checks it); drift_dev reads this literal

  /// Numbered migrations: key = the version the step produces. Every step runs inside the upgrade transaction; the caller
  /// makes a backup first (see DatabaseOpener) and a failed step leaves the old file untouched.
  static final Map<int, Future<void> Function(Migrator m, AppDatabase db)> migrations = {
    // 2: the average buying cost of a product (0 = not known). Needed for the stock-value rule; ERP 1's own average is imported into it.
    2: (m, db) => db.customStatement('ALTER TABLE products ADD COLUMN avg_cost_paise INTEGER NOT NULL DEFAULT 0'),
  };

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from > to) throw DatabaseTooNewException(from, to); // never write an older version number into newer data
          for (var v = from + 1; v <= to; v++) {
            final step = migrations[v];
            if (step == null) throw StateError('No migration to version $v');
            await step(m, this);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          if (native) {
            await customStatement('PRAGMA busy_timeout = $busyTimeoutMs');
            await customStatement('PRAGMA journal_mode = WAL');
            await customStatement('PRAGMA synchronous = FULL');
          }
        },
      );
}
