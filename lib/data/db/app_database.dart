import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// The schema version this build of the app understands. Raise it ONLY together with a numbered migration in
/// [AppDatabase.migrations], a new schema dump (`dart run drift_dev schema dump ...`) and a migration test.
const currentSchemaVersion = 1;

/// The database file was made by a NEWER version of the app. It is never opened (an old app could damage it).
class DatabaseTooNewException implements Exception {
  const DatabaseTooNewException(this.fileVersion, this.appVersion);
  final int fileVersion, appVersion;
  @override
  String toString() => 'This data was made by a newer version of the program (data version $fileVersion, this program understands up to $appVersion).';
}

@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e, {this.native = true});

  /// WAL and a durable fsync are for files on disk; the in-memory and browser databases ignore them.
  final bool native;

  @override
  int get schemaVersion => currentSchemaVersion;

  /// Numbered migrations: key = the version the step produces. Every step runs inside the upgrade transaction; the caller
  /// makes a backup first (see DatabaseOpener) and a failed step leaves the old file untouched.
  static final Map<int, Future<void> Function(Migrator m, AppDatabase db)> migrations = {};

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          for (var v = from + 1; v <= to; v++) {
            final step = migrations[v];
            if (step == null) throw StateError('No migration to version $v');
            await step(m, this);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          if (native) {
            await customStatement('PRAGMA journal_mode = WAL');
            await customStatement('PRAGMA synchronous = FULL');
            await customStatement('PRAGMA busy_timeout = 5000');
          }
        },
      );
}
