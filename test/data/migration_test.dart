import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/data/db/app_database.dart';
import 'generated/schema.dart';

// Every released database version must upgrade to the current one without losing a row. The schema of each version is kept as a
// dump in drift_schemas/ (made with `dart run drift_dev schema dump lib/data/db/app_database.dart drift_schemas/`); when the schema
// changes: raise schemaVersion and currentSchemaVersion, add the numbered migration in AppDatabase.migrations, dump the new
// version, regenerate test/data/generated (`dart run drift_dev schema generate drift_schemas/ test/data/generated/`), and this test
// then upgrades from every earlier version by itself.
void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('the version written in the database class and the number the program checks are the same', () {
    final db = AppDatabase(NativeDatabase.memory(), native: false);
    expect(db.schemaVersion, currentSchemaVersion);
  });

  test('every version up to the current one has a schema dump, and every step after the first has its migration', () {
    expect(GeneratedHelper.versions, [for (var v = 1; v <= currentSchemaVersion; v++) v], reason: 'a dump is missing: run drift_dev schema dump');
    for (var v = 2; v <= currentSchemaVersion; v++) {
      expect(AppDatabase.migrations.containsKey(v), isTrue, reason: 'no migration to version $v');
    }
    expect(File('drift_schemas/drift_schema_v$currentSchemaVersion.json').existsSync(), isTrue);
  });

  for (final from in GeneratedHelper.versions) {
    test('a version $from database upgrades to the current version and ends with exactly the current schema', () async {
      final connection = await verifier.schemaAt(from);
      final db = AppDatabase(connection.newConnection(), native: false);
      await verifier.migrateAndValidate(db, currentSchemaVersion);
      await db.close();
    });
  }
}
