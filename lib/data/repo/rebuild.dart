import '../context.dart';
import '../db/app_database.dart';

/// "Rebuild totals" (Health page): recomputes every summary from the raw rows, in ONE transaction. The raw rows (bills, lines, stock
/// movements, ledger entries) are never touched, so this can only make the figures agree with what really happened. Also the repair after a
/// restore from an older backup or an import. Returns how many summary rows were written.
Future<int> rebuildSummaries(AppDatabase db) {
  return db.transaction(() async {
    var n = 0;
    Future<void> run(String sql) async {
      await db.exec(sql);
    }

    // stock figure per product = sum of its movements (a product with none has 0)
    await run('DELETE FROM stock_cache');
    await run('INSERT INTO stock_cache(product_id, qty_milli) SELECT id, COALESCE((SELECT SUM(qty_milli) FROM stock_movements m WHERE m.product_id = products.id), 0) FROM products');
    n += await db.scalarInt('SELECT COUNT(*) FROM stock_cache');

    // the running balance after each ledger entry, then the balance summary
    await run('CREATE TEMP TABLE rb_run AS SELECT rowid AS rid, SUM(amount_paise) OVER (PARTITION BY party_id ORDER BY at, rowid) AS run FROM ledger_entries');
    await run('UPDATE ledger_entries SET running_paise = (SELECT run FROM rb_run WHERE rid = ledger_entries.rowid)');
    await run('DROP TABLE rb_run');
    await run('DELETE FROM party_balance');
    await run(
      "INSERT INTO party_balance(party_id, party_kind, balance_paise, last_bill_at, last_payment_at, entry_count) "
      "SELECT e.party_id, e.party_kind, SUM(e.amount_paise), (SELECT MAX(b.billed_at) FROM bills b WHERE b.customer_id = e.party_id), "
      "MAX(CASE WHEN e.kind IN ('payment','advance') THEN e.at END), COUNT(*) FROM ledger_entries e GROUP BY e.party_id, e.party_kind",
    );
    n += await db.scalarInt('SELECT COUNT(*) FROM party_balance');

    // the day totals and the product-month totals from the bills that count (not cancelled)
    await run('DELETE FROM day_totals');
    await run(
      'INSERT INTO day_totals(day, bills, sales_paise, taxable_paise, cost_paise, tax_paise, cash_paise, upi_paise, card_paise, credit_paise, cancelled_bills, cancelled_paise) '
      'SELECT d.day, COALESCE(x.n, 0), COALESCE(x.sales, 0), COALESCE(x.taxable, 0), COALESCE(c.cost, 0), COALESCE(x.tax, 0), COALESCE(x.cash, 0), COALESCE(x.upi, 0), COALESCE(x.card, 0), COALESCE(x.credit, 0), COALESCE(y.n, 0), COALESCE(y.total, 0) '
      'FROM (SELECT DISTINCT day FROM bills) d '
      'LEFT JOIN (SELECT day, COUNT(*) AS n, SUM(total_paise) AS sales, SUM(taxable_paise) AS taxable, SUM(cgst_paise + sgst_paise + igst_paise) AS tax, '
      'SUM(CASE WHEN pay_mode IN (0, 3) THEN total_paise - balance_paise ELSE 0 END) AS cash, SUM(CASE WHEN pay_mode = 1 THEN total_paise - balance_paise ELSE 0 END) AS upi, '
      'SUM(CASE WHEN pay_mode = 2 THEN total_paise - balance_paise ELSE 0 END) AS card, SUM(balance_paise) AS credit FROM bills WHERE cancelled = 0 GROUP BY day) x ON x.day = d.day '
      'LEFT JOIN (SELECT day, COUNT(*) AS n, SUM(total_paise) AS total FROM bills WHERE cancelled = 1 GROUP BY day) y ON y.day = d.day '
      'LEFT JOIN (SELECT b.day AS day, SUM((l.cost_paise * l.qty_milli * 2 + 1000) / 2000) AS cost FROM bill_lines l JOIN bills b ON b.id = l.bill_id WHERE b.cancelled = 0 GROUP BY b.day) c ON c.day = d.day',
    );
    n += await db.scalarInt('SELECT COUNT(*) FROM day_totals');
    await run('DELETE FROM product_month');
    await run('INSERT INTO product_month(product_id, month, qty_milli, amount_paise) SELECT l.product_id, substr(b.day, 1, 7), SUM(l.qty_milli), SUM(l.total_paise) FROM bill_lines l JOIN bills b ON b.id = l.bill_id WHERE b.cancelled = 0 GROUP BY l.product_id, substr(b.day, 1, 7)');
    n += await db.scalarInt('SELECT COUNT(*) FROM product_month');

    // an invoice counter never stays behind its newest bill
    await run("INSERT INTO counters(name, value) SELECT 'inv.' || series, MAX(seq) FROM bills GROUP BY series ON CONFLICT(name) DO UPDATE SET value = MAX(value, excluded.value)");
    return n;
  });
}
