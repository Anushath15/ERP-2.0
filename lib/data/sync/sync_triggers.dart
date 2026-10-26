import 'package:drift/drift.dart' show SqlDialect, Trigger, ViewInfo;
import '../db/app_database.dart';

/// How one table is synced to the cloud copy.
///  * [hasHlc]: the table has its own `hlc` column (edited records); otherwise the version stamp lives in `sync_rev`.
///  * [appendOnly]: the row never changes once written, so a copy that is already there is simply kept (insert-or-ignore).
class SyncTable {
  const SyncTable(this.name, {this.hasHlc = false, this.appendOnly = false});
  final String name;
  final bool hasHlc, appendOnly;
}

/// Every table whose rows go to the cloud, parents before children. Derived tables (stock_cache, party_balance, day_totals,
/// product_month, party_bills, counters) are NOT synced: each computer rebuilds them from these (rebuildSummaries).
const syncTables = <SyncTable>[
  SyncTable('categories', hasHlc: true),
  SyncTable('products', hasHlc: true),
  SyncTable('customers', hasHlc: true),
  SyncTable('dealers', hasHlc: true),
  SyncTable('bills'),
  SyncTable('bill_lines', appendOnly: true),
  SyncTable('bill_cancellations', appendOnly: true),
  SyncTable('sales_returns', appendOnly: true),
  SyncTable('sales_return_lines', appendOnly: true),
  SyncTable('purchases'),
  SyncTable('purchase_lines', appendOnly: true),
  SyncTable('purchase_returns', appendOnly: true),
  SyncTable('purchase_return_lines', appendOnly: true),
  SyncTable('estimations', hasHlc: true),
  SyncTable('estimation_lines'),
  SyncTable('stock_movements', appendOnly: true),
  SyncTable('ledger_entries', appendOnly: true),
  SyncTable('payments', appendOnly: true),
  SyncTable('reminders', appendOnly: true),
  SyncTable('records', hasHlc: true),
  SyncTable('audit', appendOnly: true),
];

/// The shared settings (the shop profile...) are rows of `kv`; in the cloud they are the collection `settings`, one document per name.
const settingsColl = 'settings';

/// The `kv` names that are shared between computers (the others, like the shop's id or last-check times, belong to one computer).
const sharedSettingNames = ['shop.profile', 'valuation.rule'];

SyncTable? syncTable(String coll) {
  for (final t in syncTables) {
    if (t.name == coll) return t;
  }
  return null;
}

/// Older builds queued documents under camelCase names; they are now the table names.
const syncCollRenames = {
  'billCancellations': 'bill_cancellations',
  'stockMovements': 'stock_movements',
  'ledgerEntries': 'ledger_entries',
  'purchaseReturns': 'purchase_returns',
  'salesReturns': 'sales_returns',
  'settingsShared': settingsColl,
};

String syncColl(String name) => syncCollRenames[name] ?? name;

const _triggerVersion = '3';

/// While the sync applies documents from the cloud this flag is set (inside that transaction), so what it writes is not queued to
/// be sent back.
const applyingFlag = 'applying';

/// The sync triggers this program makes, name -> the exact CREATE statement. Only fixed names from the constant lists in this file are ever pasted in.
Map<String, String> expectedSyncTriggers() {
  final out = <String, String>{};
  const when = "WHEN NOT EXISTS (SELECT 1 FROM sync_meta WHERE name = '$applyingFlag' AND value = '1')";
  const nowMs = "CAST(strftime('%s','now') AS INTEGER) * 1000";
  const upsert = "ON CONFLICT(chan, coll, doc_id) DO UPDATE SET op = 'set', stamp = '', state = 'pending', attempts = 0, last_error = NULL";
  // one queue row for the cloud, and one for every other counter linked over the shop Wi-Fi (payments and reminders wait 10 s there too, for Undo)
  String queue(String coll, String idExpr) => "INSERT INTO outbox(coll, doc_id, op, stamp, state, attempts, hold_until, created_at, chan) VALUES ('$coll', $idExpr, 'set', '', 'pending', 0, 0, $nowMs, 'cloud') $upsert; "
      "INSERT INTO outbox(coll, doc_id, op, stamp, state, attempts, hold_until, created_at, chan) SELECT '$coll', $idExpr, 'set', '', 'pending', 0, ${coll == 'payments' || coll == 'reminders' ? '$nowMs + 10000' : '0'}, $nowMs, p.chan FROM lan_peers p WHERE true $upsert;";
  for (final t in syncTables) {
    out['sync_${t.name}_ai'] = 'CREATE TRIGGER sync_${t.name}_ai AFTER INSERT ON ${t.name} $when BEGIN ${queue(t.name, 'new.id')} END';
    out['sync_${t.name}_au'] = 'CREATE TRIGGER sync_${t.name}_au AFTER UPDATE ON ${t.name} $when BEGIN ${queue(t.name, 'new.id')} END';
  }
  final names = sharedSettingNames.map((n) => "'$n'").join(',');
  out['sync_kv_ai'] = "CREATE TRIGGER sync_kv_ai AFTER INSERT ON kv WHEN new.name IN ($names) AND ${when.substring(5)} BEGIN ${queue(settingsColl, 'new.name')} END";
  out['sync_kv_au'] = "CREATE TRIGGER sync_kv_au AFTER UPDATE ON kv WHEN new.name IN ($names) AND ${when.substring(5)} BEGIN ${queue(settingsColl, 'new.name')} END";
  return out;
}

/// A name from sqlite_master as a quoted identifier (the name may be anything a crafted file put there).
String _quoted(String name) => '"${name.replaceAll('"', '""')}"';

String _squash(String sql) => sql.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Makes the triggers that put every inserted or changed row of a synced table into the upload queue. Done every time the database
/// opens (cheap when they are already there), so no migration has to repeat them. SECURITY: each one is compared with the exact statement
/// it must be (not only its name), so a trigger with our name but other contents (from a crafted backup) is replaced.
Future<void> ensureSyncTriggers(AppDatabase db) async {
  // an older file being upgraded step by step (tests, or a file not yet at version 9) has no sync tables yet
  if ((await db.customSelect("SELECT 1 AS x FROM sqlite_master WHERE type = 'table' AND name = 'lan_peers'").get()).isEmpty) return;
  final want = expectedSyncTriggers();
  final have = {
    for (final r in await db.customSelect("SELECT name, sql FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'sync\\_%' ESCAPE '\\'").get()) r.read<String>('name'): r.read<String?>('sql') ?? '',
  };
  if (have.length == want.length && want.entries.every((e) => _squash(have[e.key] ?? '') == _squash(e.value))) return;
  for (final n in have.keys) {
    await db.customStatement('DROP TRIGGER IF EXISTS ${_quoted(n)}');
  }
  for (final q in want.values) {
    await db.customStatement(q);
  }
  await db.customStatement("INSERT INTO sync_meta(name, value) VALUES ('trigger_ver', '$_triggerVersion') ON CONFLICT(name) DO UPDATE SET value = excluded.value");
}

/// SECURITY: a shop file can come from outside (a restored backup, a Telegram copy, a file someone hands over). SQLite keeps "triggers" and "views"
/// inside the file, and a crafted one could quietly change or delete data later (say, a trigger that halves every bill or empties the ledger). Every
/// time the database opens, any trigger or view this program did not make is removed, and one of ours whose contents were changed is made again
/// ([rewriteOurs]: only when the file is at this program's schema version; a test that stops an upgrade half way has older triggers on purpose).
Future<int> removeForeignSchemaObjects(AppDatabase db, {bool rewriteOurs = true}) async {
  final ours = <String, String>{
    for (final e in db.allSchemaEntities)
      if (e is Trigger) e.entityName: e.createStatementsByDialect[SqlDialect.sqlite] ?? e.createStatementsByDialect.values.first,
  };
  final views = {for (final e in db.allSchemaEntities) if (e is ViewInfo) e.entityName};
  final sync = expectedSyncTriggers();
  var removed = 0;
  for (final r in await db.customSelect("SELECT type, name, sql FROM sqlite_master WHERE type IN ('trigger','view')").get()) {
    final type = r.read<String>('type'), name = r.read<String>('name'), sql = r.read<String?>('sql') ?? '';
    if (type == 'view') {
      if (!views.contains(name)) {
        await db.customStatement('DROP VIEW IF EXISTS ${_quoted(name)}');
        removed++;
      }
      continue;
    }
    if (sync.containsKey(name)) continue; // checked and remade by ensureSyncTriggers
    final stmt = ours[name];
    if (stmt == null) {
      await db.customStatement('DROP TRIGGER IF EXISTS ${_quoted(name)}');
      removed++;
    } else if (rewriteOurs && _squash(stmt) != _squash(sql) && !_sameTrigger(stmt, sql)) {
      await db.customStatement('DROP TRIGGER IF EXISTS ${_quoted(name)}');
      await db.customStatement(stmt);
      removed++;
    }
  }
  return removed;
}

/// Our own triggers were also made by a migration whose text differs from the schema's only in spacing and an ending semicolon.
bool _sameTrigger(String a, String b) {
  String n(String s) => _squash(s).replaceAll(RegExp(r';\s*END$'), ' END').replaceAll(RegExp(r'\s*;\s*'), ';').replaceAll(' ', '').toLowerCase();
  return n(a) == n(b);
}
