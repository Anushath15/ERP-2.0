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

    // the product search index, built again from the products (the repair if search ever misses a product)
    await run("INSERT INTO product_fts(product_fts) VALUES('rebuild')");

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
    // sales returns reduce the totals of the day they were made (a day with only returns gets its own row)
    await run(
      'INSERT INTO day_totals(day, bills, sales_paise, taxable_paise, cost_paise, tax_paise, cash_paise, upi_paise, card_paise, credit_paise) '
      'SELECT day, 0, -SUM(total_paise), -SUM(taxable_paise), -SUM(cost_paise), -SUM(total_paise - round_off_paise - taxable_paise), '
      '-SUM(CASE WHEN refund_mode IN (0, 3) THEN refunded_paise ELSE 0 END), -SUM(CASE WHEN refund_mode = 1 THEN refunded_paise ELSE 0 END), '
      '-SUM(CASE WHEN refund_mode = 2 THEN refunded_paise ELSE 0 END), -SUM(due_reduced_paise) FROM sales_returns GROUP BY day '
      'ON CONFLICT(day) DO UPDATE SET sales_paise = sales_paise + excluded.sales_paise, taxable_paise = taxable_paise + excluded.taxable_paise, '
      'cost_paise = cost_paise + excluded.cost_paise, tax_paise = tax_paise + excluded.tax_paise, cash_paise = cash_paise + excluded.cash_paise, '
      'upi_paise = upi_paise + excluded.upi_paise, card_paise = card_paise + excluded.card_paise, credit_paise = credit_paise + excluded.credit_paise',
    );
    n += await db.scalarInt('SELECT COUNT(*) FROM day_totals');
    await run('DELETE FROM product_month');
    await run('INSERT INTO product_month(product_id, month, qty_milli, amount_paise) SELECT l.product_id, substr(b.day, 1, 7), SUM(l.qty_milli), SUM(l.total_paise) FROM bill_lines l JOIN bills b ON b.id = l.bill_id WHERE b.cancelled = 0 GROUP BY l.product_id, substr(b.day, 1, 7)');
    await run(
      'INSERT INTO product_month(product_id, month, qty_milli, amount_paise) SELECT l.product_id, substr(r.day, 1, 7), -SUM(l.qty_milli), -SUM(l.amount_paise) '
      'FROM sales_return_lines l JOIN sales_returns r ON r.id = l.return_id GROUP BY l.product_id, substr(r.day, 1, 7) '
      'ON CONFLICT(product_id, month) DO UPDATE SET qty_milli = qty_milli + excluded.qty_milli, amount_paise = amount_paise + excluded.amount_paise',
    );
    n += await db.scalarInt('SELECT COUNT(*) FROM product_month');

    // an invoice counter never stays behind its newest bill
    await run("INSERT INTO counters(name, value) SELECT 'inv.' || series, MAX(seq) FROM bills GROUP BY series ON CONFLICT(name) DO UPDATE SET value = MAX(value, excluded.value)");
    // the other counters never stay behind the newest number on their documents either (a pulled or imported document can be ahead of this computer)
    await run("INSERT INTO counters(name, value) SELECT 'est', MAX(CAST(SUBSTR(number, 5) AS INTEGER)) FROM estimations WHERE number GLOB 'EST-[0-9]*' HAVING COUNT(*) > 0 ON CONFLICT(name) DO UPDATE SET value = MAX(value, excluded.value)");
    await run("INSERT INTO counters(name, value) SELECT 'est.' || SUBSTR(number, 5, 1), MAX(CAST(SUBSTR(number, 7) AS INTEGER)) FROM estimations WHERE number GLOB 'EST-[A-Z]-[0-9]*' GROUP BY SUBSTR(number, 5, 1) ON CONFLICT(name) DO UPDATE SET value = MAX(value, excluded.value)");
    await run("INSERT INTO counters(name, value) SELECT 'rec.purchases', MAX(CAST(SUBSTR(number, 5) AS INTEGER)) FROM purchases WHERE number LIKE 'PUR-%' HAVING COUNT(*) > 0 ON CONFLICT(name) DO UPDATE SET value = MAX(value, excluded.value)");
    await run("INSERT INTO counters(name, value) SELECT 'rec.purchaseReturns', MAX(CAST(SUBSTR(number, 5) AS INTEGER)) FROM purchase_returns WHERE number LIKE 'PRT-%' HAVING COUNT(*) > 0 ON CONFLICT(name) DO UPDATE SET value = MAX(value, excluded.value)");
    await run("INSERT INTO counters(name, value) SELECT 'rec.salesReturns', MAX(CAST(SUBSTR(number, 5) AS INTEGER)) FROM sales_returns WHERE number LIKE 'SRT-%' HAVING COUNT(*) > 0 ON CONFLICT(name) DO UPDATE SET value = MAX(value, excluded.value)");
    return n;
  });
}
