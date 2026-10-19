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

/// One check: a plain-English description of what would be wrong, and a query that returns the rows that are wrong.
class CheckQuery {
  const CheckQuery(this.what, this.sql);
  final String what, sql;
}

/// The checks of docs/data-model.md "Invariants": every summary is recomputed from the raw rows and compared. [deep] also re-adds every
/// bill line and re-matches every line to its stock movement (minutes on a million bills; the quick form already catches a half-saved bill,
/// because a bill is saved with its lines and movements in one transaction).
List<CheckQuery> selfCheckQueries({bool deep = false}) => [
      const CheckQuery('Stock figure differs from the sum of its movements', 'SELECT p.id FROM products p LEFT JOIN stock_cache s ON s.product_id = p.id WHERE COALESCE(s.qty_milli,0) <> COALESCE((SELECT SUM(qty_milli) FROM stock_movements m WHERE m.product_id = p.id),0)'),
      const CheckQuery('Balance differs from the sum of the ledger', 'SELECT b.party_id FROM party_balance b WHERE b.balance_paise <> COALESCE((SELECT SUM(amount_paise) FROM ledger_entries e WHERE e.party_id = b.party_id),0)'),
      const CheckQuery('Ledger entries without a balance row', 'SELECT DISTINCT e.party_id FROM ledger_entries e LEFT JOIN party_balance b ON b.party_id = e.party_id WHERE b.party_id IS NULL'),
      const CheckQuery("A ledger's last running balance differs from the balance", 'SELECT b.party_id FROM party_balance b WHERE b.entry_count > 0 AND b.balance_paise <> COALESCE((SELECT running_paise FROM ledger_entries e WHERE e.party_id = b.party_id ORDER BY at DESC, rowid DESC LIMIT 1),0)'),
      const CheckQuery('A bill-wise due is paid below zero or above its total', 'SELECT id FROM party_bills WHERE paid_paise < 0 OR paid_paise > total_paise'),
      const CheckQuery('A day total differs from its bills', 'SELECT t.day FROM day_totals t LEFT JOIN (SELECT day, COUNT(*) AS n, SUM(total_paise) AS s FROM bills WHERE cancelled = 0 GROUP BY day) x ON x.day = t.day LEFT JOIN (SELECT day, SUM(total_paise) AS r FROM sales_returns GROUP BY day) y ON y.day = t.day WHERE t.sales_paise <> COALESCE(x.s, 0) - COALESCE(y.r, 0) OR t.bills <> COALESCE(x.n, 0)'),
      const CheckQuery('A bill day is missing from the day totals', 'SELECT DISTINCT b.day FROM bills b LEFT JOIN day_totals t ON t.day = b.day WHERE t.day IS NULL'),
      const CheckQuery('A bill whose lines are missing or incomplete', 'SELECT b.id FROM bills b LEFT JOIN (SELECT bill_id, COUNT(*) AS n FROM bill_lines GROUP BY bill_id) x ON x.bill_id = b.id WHERE b.item_count <> COALESCE(x.n, 0)'),
      const CheckQuery('A bill with credit but no ledger entry', "SELECT b.id FROM bills b WHERE b.balance_paise > 0 AND b.customer_id IS NOT NULL AND b.cancelled = 0 AND NOT EXISTS (SELECT 1 FROM ledger_entries e WHERE e.party_id = b.customer_id AND e.bill_no = b.number AND e.kind = 'billCredit')"),
      const CheckQuery('An invoice counter behind its newest bill', "SELECT c.name FROM counters c WHERE c.name LIKE 'inv.%' AND c.value < COALESCE((SELECT MAX(seq) FROM bills b WHERE 'inv.' || b.series = c.name),0)"),
      const CheckQuery('A received purchase without its stock movements', "SELECT p.id FROM purchases p WHERE p.status = 1 AND EXISTS (SELECT 1 FROM purchase_lines l WHERE l.purchase_id = p.id AND NOT EXISTS (SELECT 1 FROM stock_movements m WHERE m.ref_id = p.id AND m.product_id = l.product_id AND m.kind = 'purchase'))"),
      const CheckQuery('A purchase whose items do not add up to its total', 'SELECT p.id FROM purchases p WHERE p.total_paise <> COALESCE((SELECT SUM(total_paise) FROM purchase_lines l WHERE l.purchase_id = p.id), 0)'),
      const CheckQuery('A purchase return whose settlement does not add up', 'SELECT id FROM purchase_returns WHERE due_reduced_paise + credit_kept_paise + refunded_paise <> total_paise'),
      const CheckQuery('A purchase return without its stock movements', "SELECT r.id FROM purchase_returns r WHERE EXISTS (SELECT 1 FROM purchase_return_lines l WHERE l.return_id = r.id AND NOT EXISTS (SELECT 1 FROM stock_movements m WHERE m.ref_id = r.id AND m.product_id = l.product_id AND m.kind = 'purchase_return'))"),
      const CheckQuery('A sales return whose refund does not add up', 'SELECT id FROM sales_returns WHERE due_reduced_paise + credit_kept_paise + refunded_paise <> total_paise'),
      const CheckQuery('A sales return without its stock movements', "SELECT r.id FROM sales_returns r WHERE EXISTS (SELECT 1 FROM sales_return_lines l WHERE l.return_id = r.id AND NOT EXISTS (SELECT 1 FROM stock_movements m WHERE m.ref_id = r.id AND m.product_id = l.product_id AND m.kind = 'return'))"),
      const CheckQuery('A cancelled bill without its cancellation record', 'SELECT b.id FROM bills b WHERE b.cancelled = 1 AND NOT EXISTS (SELECT 1 FROM bill_cancellations c WHERE c.bill_id = b.id)'),
      const CheckQuery('A payment without its ledger entry', 'SELECT p.id FROM payments p WHERE NOT EXISTS (SELECT 1 FROM ledger_entries e WHERE e.ref_id = p.id)'),
      if (deep) const CheckQuery('A bill line without its stock movement', "SELECT l.id FROM bill_lines l WHERE NOT EXISTS (SELECT 1 FROM stock_movements m WHERE m.ref_id = l.bill_id AND m.product_id = l.product_id AND m.kind = 'sale')"),
      if (deep) const CheckQuery('A product-month total differs from the bill lines', "SELECT m.product_id FROM product_month m WHERE m.qty_milli <> COALESCE((SELECT SUM(l.qty_milli) FROM bill_lines l JOIN bills b ON b.id = l.bill_id WHERE l.product_id = m.product_id AND substr(b.day,1,7) = m.month AND b.cancelled = 0),0) - COALESCE((SELECT SUM(rl.qty_milli) FROM sales_return_lines rl JOIN sales_returns r ON r.id = rl.return_id WHERE rl.product_id = m.product_id AND substr(r.day,1,7) = m.month),0)"),
    ];

/// Runs the self-check on an open database (reads only; nothing is changed).
Future<List<CheckProblem>> selfCheck(AppDatabase db, {bool deep = false, void Function(String what, int ms)? onTime}) async {
  final problems = <CheckProblem>[];
  for (final q in selfCheckQueries(deep: deep)) {
    final sw = Stopwatch()..start();
    final n = await db.scalarInt('SELECT COUNT(*) FROM (${q.sql})');
    onTime?.call(q.what, sw.elapsedMilliseconds);
    if (n > 0) problems.add(CheckProblem(q.what, n));
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
