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

/// Makes the triggers that put every inserted or changed row of a synced table into the upload queue. Done every time the database
/// opens (cheap when they are already there), so no migration has to repeat them.
Future<void> ensureSyncTriggers(AppDatabase db) async {
  // an older file being upgraded step by step (tests, or a file not yet at version 9) has no sync tables yet
  if ((await db.customSelect("SELECT 1 AS x FROM sqlite_master WHERE type = 'table' AND name = 'lan_peers'").get()).isEmpty) return;
  final have = await db.customSelect("SELECT COUNT(*) AS n FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'sync\\_%' ESCAPE '\\'").getSingle();
  final ver = await db.customSelect("SELECT value FROM sync_meta WHERE name = 'trigger_ver'").get();
  if (have.read<int>('n') == syncTables.length * 2 + 2 && ver.isNotEmpty && ver.first.read<String>('value') == _triggerVersion) return;
  // Only fixed names from the constant lists in this file are ever pasted into these statements, never text a person typed.
  final statements = <String>[];
  const when = "WHEN NOT EXISTS (SELECT 1 FROM sync_meta WHERE name = '$applyingFlag' AND value = '1')";
  const nowMs = "CAST(strftime('%s','now') AS INTEGER) * 1000";
  const upsert = "ON CONFLICT(chan, coll, doc_id) DO UPDATE SET op = 'set', stamp = '', state = 'pending', attempts = 0, last_error = NULL";
  // one queue row for the cloud, and one for every other counter linked over the shop Wi-Fi (payments and reminders wait 10 s there too, for Undo)
  String queue(String coll, String idExpr) => "INSERT INTO outbox(coll, doc_id, op, stamp, state, attempts, hold_until, created_at, chan) VALUES ('$coll', $idExpr, 'set', '', 'pending', 0, 0, $nowMs, 'cloud') $upsert; "
      "INSERT INTO outbox(coll, doc_id, op, stamp, state, attempts, hold_until, created_at, chan) SELECT '$coll', $idExpr, 'set', '', 'pending', 0, ${coll == 'payments' || coll == 'reminders' ? '$nowMs + 10000' : '0'}, $nowMs, p.chan FROM lan_peers p WHERE true $upsert;";
  for (final t in syncTables) {
    statements.add('DROP TRIGGER IF EXISTS sync_${t.name}_ai');
    statements.add('DROP TRIGGER IF EXISTS sync_${t.name}_au');
    statements.add('CREATE TRIGGER sync_${t.name}_ai AFTER INSERT ON ${t.name} $when BEGIN ${queue(t.name, 'new.id')} END');
    statements.add('CREATE TRIGGER sync_${t.name}_au AFTER UPDATE ON ${t.name} $when BEGIN ${queue(t.name, 'new.id')} END');
  }
  final names = sharedSettingNames.map((n) => "'$n'").join(',');
  statements.add('DROP TRIGGER IF EXISTS sync_kv_ai');
  statements.add('DROP TRIGGER IF EXISTS sync_kv_au');
  statements.add("CREATE TRIGGER sync_kv_ai AFTER INSERT ON kv WHEN new.name IN ($names) AND ${when.substring(5)} BEGIN ${queue(settingsColl, 'new.name')} END");
  statements.add("CREATE TRIGGER sync_kv_au AFTER UPDATE ON kv WHEN new.name IN ($names) AND ${when.substring(5)} BEGIN ${queue(settingsColl, 'new.name')} END");
  for (final q in statements) {
    await db.customStatement(q);
  }
  await db.customStatement("INSERT INTO sync_meta(name, value) VALUES ('trigger_ver', '$_triggerVersion') ON CONFLICT(name) DO UPDATE SET value = excluded.value");
}
