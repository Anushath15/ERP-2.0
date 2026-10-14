import '../context.dart';
import '../db/app_database.dart';

/// One thing the self-check found wrong, in plain words plus the numbers.
class CheckProblem {
  const CheckProblem(this.what, this.count);
  final String what;
  final int count;
  @override
  String toString() => '$what ($count)';
}

/// Recomputes every summary from the raw rows and compares (docs/data-model.md "Invariants"). It reads only; nothing is changed.
/// Run nightly in the background, from the Health page, and after a restore or an import. [deep] also re-adds every bill line
/// (slow on a million bills; the quick form already catches a half-saved bill).
Future<List<CheckProblem>> selfCheck(AppDatabase db, {bool deep = false}) async {
  final problems = <CheckProblem>[];
  Future<void> check(String what, String sql) async {
    final n = await db.scalarInt('SELECT COUNT(*) FROM ($sql)');
    if (n > 0) problems.add(CheckProblem(what, n));
  }

  await check('Stock figure differs from the sum of its movements', 'SELECT p.id FROM products p LEFT JOIN stock_cache s ON s.product_id = p.id WHERE COALESCE(s.qty_milli,0) <> COALESCE((SELECT SUM(qty_milli) FROM stock_movements m WHERE m.product_id = p.id),0)');
  await check('Balance differs from the sum of the ledger', 'SELECT b.party_id FROM party_balance b WHERE b.balance_paise <> COALESCE((SELECT SUM(amount_paise) FROM ledger_entries e WHERE e.party_id = b.party_id),0)');
  await check('Ledger entries without a balance row', 'SELECT DISTINCT e.party_id FROM ledger_entries e LEFT JOIN party_balance b ON b.party_id = e.party_id WHERE b.party_id IS NULL');
  await check("A ledger's last running balance differs from the balance", 'SELECT b.party_id FROM party_balance b WHERE b.entry_count > 0 AND b.balance_paise <> COALESCE((SELECT running_paise FROM ledger_entries e WHERE e.party_id = b.party_id ORDER BY at DESC, rowid DESC LIMIT 1),0)');
  await check('A bill-wise due is paid below zero or above its total', 'SELECT id FROM party_bills WHERE paid_paise < 0 OR paid_paise > total_paise');
  await check('A day total differs from its bills', 'SELECT t.day FROM day_totals t WHERE t.sales_paise <> COALESCE((SELECT SUM(total_paise) FROM bills b WHERE b.day = t.day AND b.cancelled = 0),0) OR t.bills <> (SELECT COUNT(*) FROM bills b WHERE b.day = t.day AND b.cancelled = 0)');
  await check('A bill day is missing from the day totals', 'SELECT DISTINCT b.day FROM bills b LEFT JOIN day_totals t ON t.day = b.day WHERE t.day IS NULL');
  await check('A bill whose lines are missing or incomplete', 'SELECT b.id FROM bills b WHERE b.item_count <> (SELECT COUNT(*) FROM bill_lines l WHERE l.bill_id = b.id)');
  await check('A bill line without its stock movement', "SELECT l.id FROM bill_lines l WHERE NOT EXISTS (SELECT 1 FROM stock_movements m WHERE m.ref_id = l.bill_id AND m.product_id = l.product_id AND m.kind = 'sale')");
  await check('A bill with credit but no ledger entry', "SELECT b.id FROM bills b WHERE b.balance_paise > 0 AND b.customer_id IS NOT NULL AND b.cancelled = 0 AND NOT EXISTS (SELECT 1 FROM ledger_entries e WHERE e.party_id = b.customer_id AND e.bill_no = b.number AND e.kind = 'billCredit')");
  await check('An invoice counter behind its newest bill', "SELECT c.name FROM counters c WHERE c.name LIKE 'inv.%' AND c.value < COALESCE((SELECT MAX(seq) FROM bills b WHERE 'inv.' || b.series = c.name),0)");
  await check('A cancelled bill without its cancellation record', 'SELECT b.id FROM bills b WHERE b.cancelled = 1 AND NOT EXISTS (SELECT 1 FROM bill_cancellations c WHERE c.bill_id = b.id)');
  await check('A payment without its ledger entry', 'SELECT p.id FROM payments p WHERE NOT EXISTS (SELECT 1 FROM ledger_entries e WHERE e.ref_id = p.id)');
  if (deep) {
    await check('A product-month total differs from the bill lines', "SELECT m.product_id FROM product_month m WHERE m.qty_milli <> COALESCE((SELECT SUM(l.qty_milli) FROM bill_lines l JOIN bills b ON b.id = l.bill_id WHERE l.product_id = m.product_id AND substr(b.day,1,7) = m.month AND b.cancelled = 0),0)");
  }
  final fk = await db.rows('PRAGMA foreign_key_check');
  if (fk.isNotEmpty) problems.add(CheckProblem('Records that point at something that is missing', fk.length));
  return problems;
}

/// SQLite's own check of the file. [full] reads every page (minutes on a big file); the quick form is for start-up.
Future<List<String>> sqliteIntegrity(AppDatabase db, {bool full = false}) async {
  final r = await db.rows(full ? 'PRAGMA integrity_check' : 'PRAGMA quick_check');
  final out = [for (final x in r) x.data.values.first.toString()];
  return out.length == 1 && out.first == 'ok' ? const [] : out;
}
