import 'dart:async';
import '../repo/product_codes.dart';
import '../sync/sync_triggers.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// The schema version this build of the app understands. Raise it ONLY together with a numbered migration in
/// [AppDatabase.migrations], a new schema dump (`dart run drift_dev schema dump ...`) and a migration test.
const currentSchemaVersion = 12;

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
  int _lastWriteMs = 0, _commitsSince = 0, _activeTransactions = 0, _commitsTotal = 0;
  bool _checkpointBusy = false;

  /// How many saves have been made since this program opened the data, and when the last one finished: the backup schedule asks "has anything changed".
  int get commitCount => _commitsTotal;
  int get lastWriteMs => _lastWriteMs;

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
      _commitsTotal++;
    }
  }

  /// Tidies the data file: folds the log back in, refreshes the statistics the query planner uses, merges the search index and compacts the file. Nothing is
  /// deleted. Call it from the write queue so no save runs at the same moment. Returns the data size in bytes before and after.
  Future<({int before, int after})> maintain() async {
    Future<int> size() async {
      final r = await customSelect('SELECT (SELECT page_count FROM pragma_page_count) * (SELECT page_size FROM pragma_page_size) AS n').getSingle();
      return r.read<int>('n');
    }

    final before = await size();
    if (native) await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await customStatement("INSERT INTO product_fts(product_fts) VALUES('optimize')");
    await customStatement('ANALYZE');
    await customStatement('VACUUM');
    await customStatement('PRAGMA optimize');
    return (before: before, after: await size());
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
  int get schemaVersion => 12; // keep equal to [currentSchemaVersion] (a test checks it); drift_dev reads this literal

  /// Numbered migrations: key = the version the step produces. Every step runs inside the upgrade transaction; the caller
  /// makes a backup first (see DatabaseOpener) and a failed step leaves the old file untouched.
  static final Map<int, Future<void> Function(Migrator m, AppDatabase db)> migrations = {
    // 2: the average buying cost of a product (0 = not known). Needed for the stock-value rule; ERP 1's own average is imported into it.
    2: (m, db) => db.customStatement('ALTER TABLE products ADD COLUMN avg_cost_paise INTEGER NOT NULL DEFAULT 0'),
    3: (m, db) async {
      await db.customStatement('''CREATE TABLE sales_returns (
  id TEXT NOT NULL PRIMARY KEY,
  number TEXT NOT NULL,
  bill_id TEXT NOT NULL REFERENCES bills(id),
  bill_no TEXT NOT NULL,
  customer_id TEXT REFERENCES customers(id),
  customer_name TEXT NOT NULL DEFAULT '',
  returned_at INTEGER NOT NULL,
  day TEXT NOT NULL,
  total_paise INTEGER NOT NULL,
  taxable_paise INTEGER NOT NULL DEFAULT 0,
  cgst_paise INTEGER NOT NULL DEFAULT 0,
  sgst_paise INTEGER NOT NULL DEFAULT 0,
  igst_paise INTEGER NOT NULL DEFAULT 0,
  cost_paise INTEGER NOT NULL DEFAULT 0,
  round_off_paise INTEGER NOT NULL DEFAULT 0,
  due_reduced_paise INTEGER NOT NULL DEFAULT 0,
  credit_kept_paise INTEGER NOT NULL DEFAULT 0,
  refunded_paise INTEGER NOT NULL DEFAULT 0,
  refund_mode INTEGER NOT NULL DEFAULT 0,
  reason TEXT NOT NULL,
  by_name TEXT NOT NULL DEFAULT '',
  idem_key TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  device_id TEXT NOT NULL
)''');
      await db.customStatement('''CREATE UNIQUE INDEX sales_returns_number ON sales_returns(number)''');
      await db.customStatement('''CREATE UNIQUE INDEX sales_returns_idem ON sales_returns(idem_key)''');
      await db.customStatement('''CREATE INDEX sales_returns_bill ON sales_returns(bill_id)''');
      await db.customStatement('''CREATE INDEX sales_returns_at ON sales_returns(returned_at DESC, id DESC)''');
      await db.customStatement('''CREATE INDEX sales_returns_day ON sales_returns(day)''');
      await db.customStatement('''CREATE TABLE sales_return_lines (
  id TEXT NOT NULL PRIMARY KEY,
  return_id TEXT NOT NULL REFERENCES sales_returns(id),
  bill_line_id TEXT NOT NULL REFERENCES bill_lines(id),
  product_id TEXT NOT NULL REFERENCES products(id),
  name TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT 'pcs',
  qty_milli INTEGER NOT NULL,
  amount_paise INTEGER NOT NULL,
  taxable_paise INTEGER NOT NULL,
  tax_paise INTEGER NOT NULL,
  cost_paise INTEGER NOT NULL DEFAULT 0
)''');
      await db.customStatement('''CREATE INDEX sales_return_lines_return ON sales_return_lines(return_id)''');
      await db.customStatement('''CREATE INDEX sales_return_lines_billline ON sales_return_lines(bill_line_id)''');
    },
    4: (m, db) async {
      await db.customStatement("ALTER TABLE products ADD COLUMN code TEXT NOT NULL DEFAULT ''");
      await db.customStatement("ALTER TABLE products ADD COLUMN brand TEXT NOT NULL DEFAULT ''");
      await db.customStatement("CREATE UNIQUE INDEX products_code ON products(code) WHERE code <> ''");
      await backfillProductCodes(db); // every product that is already there gets its code
    },
    5: (m, db) async {
      await db.customStatement('''CREATE TABLE purchases (
  id TEXT NOT NULL PRIMARY KEY,
  number TEXT NOT NULL,
  dealer_id TEXT NOT NULL REFERENCES dealers(id),
  dealer_name TEXT NOT NULL DEFAULT '',
  invoice_no TEXT NOT NULL DEFAULT '',
  purchased_at INTEGER NOT NULL,
  day TEXT NOT NULL,
  total_paise INTEGER NOT NULL,
  taxable_paise INTEGER NOT NULL DEFAULT 0,
  tax_paise INTEGER NOT NULL DEFAULT 0,
  paid_paise INTEGER NOT NULL DEFAULT 0,
  status INTEGER NOT NULL DEFAULT 1,
  received_at INTEGER,
  update_cost INTEGER NOT NULL DEFAULT 1,
  note TEXT NOT NULL DEFAULT '',
  idem_key TEXT NOT NULL,
  by_name TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  device_id TEXT NOT NULL
)''');
      await db.customStatement('''CREATE UNIQUE INDEX purchases_number ON purchases(number)''');
      await db.customStatement('''CREATE UNIQUE INDEX purchases_idem ON purchases(idem_key)''');
      await db.customStatement('''CREATE INDEX purchases_dealer ON purchases(dealer_id, purchased_at DESC, id DESC)''');
      await db.customStatement('''CREATE INDEX purchases_at ON purchases(purchased_at DESC, id DESC)''');
      await db.customStatement('''CREATE TABLE purchase_lines (
  id TEXT NOT NULL PRIMARY KEY,
  purchase_id TEXT NOT NULL REFERENCES purchases(id),
  line_no INTEGER NOT NULL,
  product_id TEXT NOT NULL REFERENCES products(id),
  name TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT 'pcs',
  qty_milli INTEGER NOT NULL,
  rate_paise INTEGER NOT NULL,
  gst_bp INTEGER NOT NULL DEFAULT 0,
  taxable_paise INTEGER NOT NULL,
  tax_paise INTEGER NOT NULL,
  total_paise INTEGER NOT NULL
)''');
      await db.customStatement('''CREATE INDEX purchase_lines_purchase ON purchase_lines(purchase_id, line_no)''');
      await db.customStatement('''CREATE INDEX purchase_lines_product ON purchase_lines(product_id, purchase_id)''');
    },
    6: (m, db) async {
      await db.customStatement('''CREATE TABLE purchase_returns (
  id TEXT NOT NULL PRIMARY KEY,
  number TEXT NOT NULL,
  purchase_id TEXT NOT NULL REFERENCES purchases(id),
  purchase_no TEXT NOT NULL,
  dealer_id TEXT NOT NULL REFERENCES dealers(id),
  dealer_name TEXT NOT NULL DEFAULT '',
  returned_at INTEGER NOT NULL,
  day TEXT NOT NULL,
  total_paise INTEGER NOT NULL,
  taxable_paise INTEGER NOT NULL DEFAULT 0,
  tax_paise INTEGER NOT NULL DEFAULT 0,
  due_reduced_paise INTEGER NOT NULL DEFAULT 0,
  credit_kept_paise INTEGER NOT NULL DEFAULT 0,
  refunded_paise INTEGER NOT NULL DEFAULT 0,
  refund_mode INTEGER NOT NULL DEFAULT 0,
  reason TEXT NOT NULL,
  by_name TEXT NOT NULL DEFAULT '',
  idem_key TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  device_id TEXT NOT NULL
)''');
      await db.customStatement('''CREATE UNIQUE INDEX purchase_returns_number ON purchase_returns(number)''');
      await db.customStatement('''CREATE UNIQUE INDEX purchase_returns_idem ON purchase_returns(idem_key)''');
      await db.customStatement('''CREATE INDEX purchase_returns_purchase ON purchase_returns(purchase_id)''');
      await db.customStatement('''CREATE INDEX purchase_returns_at ON purchase_returns(returned_at DESC, id DESC)''');
      await db.customStatement('''CREATE TABLE purchase_return_lines (
  id TEXT NOT NULL PRIMARY KEY,
  return_id TEXT NOT NULL REFERENCES purchase_returns(id),
  purchase_line_id TEXT NOT NULL REFERENCES purchase_lines(id),
  product_id TEXT NOT NULL REFERENCES products(id),
  name TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT 'pcs',
  qty_milli INTEGER NOT NULL,
  amount_paise INTEGER NOT NULL,
  taxable_paise INTEGER NOT NULL,
  tax_paise INTEGER NOT NULL
)''');
      await db.customStatement('''CREATE INDEX purchase_return_lines_return ON purchase_return_lines(return_id)''');
      await db.customStatement('''CREATE INDEX purchase_return_lines_line ON purchase_return_lines(purchase_line_id)''');
    },
    7: (m, db) async {
      await db.customStatement('ALTER TABLE products ADD COLUMN mrp_paise INTEGER NOT NULL DEFAULT 0');
      await db.customStatement('ALTER TABLE bills ADD COLUMN extra_discount_paise INTEGER NOT NULL DEFAULT 0');
      await db.customStatement('ALTER TABLE bills ADD COLUMN extra_discount_bp INTEGER NOT NULL DEFAULT 0');
      await db.customStatement('ALTER TABLE estimations ADD COLUMN extra_discount_paise INTEGER NOT NULL DEFAULT 0');
      await db.customStatement('ALTER TABLE estimations ADD COLUMN extra_discount_bp INTEGER NOT NULL DEFAULT 0');
    },
    // 8: product search also finds a product by its code, brand and category (it only knew name and barcode). The search index is built again
    // from the products, so every existing product is findable by the new words at once.
    8: (m, db) async {
      await db.customStatement('DROP TRIGGER IF EXISTS products_fts_ai');
      await db.customStatement('DROP TRIGGER IF EXISTS products_fts_ad');
      await db.customStatement('DROP TRIGGER IF EXISTS products_fts_au');
      await db.customStatement('DROP TABLE IF EXISTS product_fts');
      await db.customStatement("CREATE VIRTUAL TABLE product_fts USING fts5(name, barcode, code, brand, category, content='products', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2', prefix='2 3')");
      await db.customStatement('CREATE TRIGGER products_fts_ai AFTER INSERT ON products BEGIN\n  INSERT INTO product_fts(rowid, name, barcode, code, brand, category) VALUES (new.rowid, new.name, new.barcode, new.code, new.brand, new.category);\nEND');
      await db.customStatement("CREATE TRIGGER products_fts_ad AFTER DELETE ON products BEGIN\n  INSERT INTO product_fts(product_fts, rowid, name, barcode, code, brand, category) VALUES ('delete', old.rowid, old.name, old.barcode, old.code, old.brand, old.category);\nEND");
      await db.customStatement("CREATE TRIGGER products_fts_au AFTER UPDATE OF name, barcode, code, brand, category ON products BEGIN\n  INSERT INTO product_fts(product_fts, rowid, name, barcode, code, brand, category) VALUES ('delete', old.rowid, old.name, old.barcode, old.code, old.brand, old.category);\n  INSERT INTO product_fts(rowid, name, barcode, code, brand, category) VALUES (new.rowid, new.name, new.barcode, new.code, new.brand, new.category);\nEND");
      await db.customStatement("INSERT INTO product_fts(product_fts) VALUES('rebuild')");
    },
    // 9: the cloud sync. Documents without their own hlc column get a version stamp table; queued rows get the table names the sync uses
    // (the capture triggers are made every time the database opens, see sync_triggers.dart).
    9: (m, db) async {
      await db.customStatement('CREATE TABLE sync_rev (coll TEXT NOT NULL, doc_id TEXT NOT NULL, hlc TEXT NOT NULL, PRIMARY KEY (coll, doc_id))');
      for (final e in syncCollRenames.entries) {
        await db.customStatement('UPDATE OR IGNORE outbox SET coll = ? WHERE coll = ?', [e.value, e.key]);
        await db.customStatement('DELETE FROM outbox WHERE coll = ?', [e.key]);
      }
    },
    // 10: changes can also be sent straight to the other counters of the shop (shop Wi-Fi). Each destination has its own upload queue
    // (`chan`): the cloud's rows keep chan 'cloud'.
    10: (m, db) async {
      await db.customStatement("ALTER TABLE outbox ADD COLUMN chan TEXT NOT NULL DEFAULT 'cloud'");
      await db.customStatement('DROP INDEX outbox_doc');
      await db.customStatement('CREATE UNIQUE INDEX outbox_doc ON outbox(chan, coll, doc_id)');
      await db.customStatement("CREATE TABLE lan_peers (chan TEXT NOT NULL PRIMARY KEY, host TEXT NOT NULL, port INTEGER NOT NULL, device_id TEXT NOT NULL, name TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL)");
    },
    // 11: a purchase can be edited, so it says how many items it has now (the other computer removes the items that are gone)
    11: (m, db) async {
      await db.customStatement('ALTER TABLE purchases ADD COLUMN line_count INTEGER NOT NULL DEFAULT 0');
      await db.customStatement('UPDATE purchases SET line_count = (SELECT COUNT(*) FROM purchase_lines WHERE purchase_id = purchases.id)');
    },
    // 12: how a purchase was paid (0 cash, 1 UPI, 2 card, 3 bank transfer), so the day's cash book counts only the cash
    12: (m, db) => db.customStatement('ALTER TABLE purchases ADD COLUMN pay_mode INTEGER NOT NULL DEFAULT 0'),
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
          await removeForeignSchemaObjects(this, rewriteOurs: details.versionNow == currentSchemaVersion); // a crafted file cannot bring its own triggers or views
          await ensureSyncTriggers(this);
          if (native) {
            await customStatement('PRAGMA busy_timeout = $busyTimeoutMs');
            await customStatement('PRAGMA journal_mode = WAL');
            await customStatement('PRAGMA synchronous = FULL');
          }
        },
      );
}
