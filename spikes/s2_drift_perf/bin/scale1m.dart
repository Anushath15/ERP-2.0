// Scale test: ONE MILLION bills (about 5 lines each), 5,000 customers, 50,000 products, on the real schema ideas for ERP 2.0:
//   * keyset (cursor) paging, never OFFSET
//   * summary tables updated in the same transaction as the bill (customer balance, stock, day totals, product-month totals)
//   * indexes on date, customer, bill number, status; FTS5 for products and customers
//   * auto_vacuum=INCREMENTAL so old years can be archived and the file shrunk in small steps
//
//   dart run bin/scale1m.dart D:\erp2-scale\scale1m.sqlite [bills=1000000] [seed|skip]
//
// The database is a test file made by this script and is NEVER committed (it is huge). Results are printed and written next to
// the database as scale1m-results.json; docs/perf-results.md has the numbers of the official run.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

final _u = const Uuid();
final _r = Random(20261013);

const kProducts = 50000;
const kCustomers = 5000;
const kYears = 5;

String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _schema = '''
PRAGMA auto_vacuum = INCREMENTAL;
PRAGMA journal_mode = WAL;
CREATE TABLE products (id TEXT PRIMARY KEY, name TEXT NOT NULL, barcode TEXT, price_paise INTEGER NOT NULL, gst_bp INTEGER NOT NULL, unit TEXT NOT NULL, min_qty_milli INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER);
CREATE VIRTUAL TABLE product_fts USING fts5(name, barcode, content='products', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2', prefix='2 3');
CREATE INDEX idx_products_name ON products(name COLLATE NOCASE, id);
CREATE UNIQUE INDEX idx_products_barcode ON products(barcode) WHERE barcode IS NOT NULL;
CREATE TABLE customers (id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, city TEXT, credit_limit_paise INTEGER NOT NULL, updated_at INTEGER NOT NULL);
CREATE VIRTUAL TABLE customer_fts USING fts5(name, phone, content='customers', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2', prefix='2 3');
CREATE INDEX idx_customers_name ON customers(name COLLATE NOCASE, id);
CREATE TABLE bills (id TEXT PRIMARY KEY, number TEXT NOT NULL, customer_id TEXT, status INTEGER NOT NULL DEFAULT 0, total_paise INTEGER NOT NULL, received_paise INTEGER NOT NULL, balance_paise INTEGER NOT NULL, tax_paise INTEGER NOT NULL, pay_mode INTEGER NOT NULL, billed_at INTEGER NOT NULL, day TEXT NOT NULL, idem_key TEXT NOT NULL, updated_at INTEGER NOT NULL);
CREATE UNIQUE INDEX idx_bills_number ON bills(number);
CREATE UNIQUE INDEX idx_bills_idem ON bills(idem_key);
CREATE INDEX idx_bills_at ON bills(billed_at DESC, id DESC);
CREATE INDEX idx_bills_cust ON bills(customer_id, billed_at DESC, id DESC) WHERE customer_id IS NOT NULL;
CREATE INDEX idx_bills_cancelled ON bills(billed_at DESC, id DESC) WHERE status = 1;
CREATE TABLE bill_lines (id TEXT PRIMARY KEY, bill_id TEXT NOT NULL, product_id TEXT NOT NULL, qty_milli INTEGER NOT NULL, rate_paise INTEGER NOT NULL, amount_paise INTEGER NOT NULL);
CREATE INDEX idx_lines_bill ON bill_lines(bill_id);
CREATE INDEX idx_lines_prod ON bill_lines(product_id, bill_id);
CREATE TABLE stock_movements (id TEXT PRIMARY KEY, product_id TEXT NOT NULL, qty_milli INTEGER NOT NULL, kind TEXT NOT NULL, ref_id TEXT, at INTEGER NOT NULL);
CREATE INDEX idx_mov_prod ON stock_movements(product_id, at);
CREATE TABLE ledger (id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, kind TEXT NOT NULL, amount_paise INTEGER NOT NULL, running_paise INTEGER NOT NULL, at INTEGER NOT NULL, ref_id TEXT);
CREATE INDEX idx_ledger_cust ON ledger(customer_id, at DESC, id DESC);
CREATE TABLE bill_due (bill_id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, due_paise INTEGER NOT NULL, billed_at INTEGER NOT NULL);
CREATE INDEX idx_due_cust ON bill_due(customer_id, billed_at) WHERE due_paise > 0;
CREATE TABLE customer_balance (customer_id TEXT PRIMARY KEY, balance_paise INTEGER NOT NULL, last_bill_at INTEGER, last_payment_at INTEGER);
CREATE INDEX idx_balance_owing ON customer_balance(balance_paise DESC) WHERE balance_paise > 0;
CREATE TABLE stock_cache (product_id TEXT PRIMARY KEY, qty_milli INTEGER NOT NULL);
CREATE INDEX idx_stock_low ON stock_cache(qty_milli);
CREATE TABLE day_totals (day TEXT PRIMARY KEY, bills INTEGER NOT NULL, sales_paise INTEGER NOT NULL, tax_paise INTEGER NOT NULL, cash_paise INTEGER NOT NULL, upi_paise INTEGER NOT NULL, card_paise INTEGER NOT NULL, credit_paise INTEGER NOT NULL);
CREATE TABLE product_month (product_id TEXT NOT NULL, month TEXT NOT NULL, qty_milli INTEGER NOT NULL, amount_paise INTEGER NOT NULL, PRIMARY KEY (product_id, month));
CREATE INDEX idx_pm_month ON product_month(month, amount_paise DESC);
CREATE TABLE counters (series TEXT PRIMARY KEY, next INTEGER NOT NULL);
CREATE TABLE outbox (record_id TEXT PRIMARY KEY, kind TEXT NOT NULL, at INTEGER NOT NULL);
''';

const brands = ['Havells', 'Anchor', 'Polycab', 'Finolex', 'Astral', 'Supreme', 'Ashirvad', 'Jaquar', 'Cera', 'Orient', 'Crompton', 'Legrand', 'Philips', 'Bosch', 'Asian Paints', 'Fevicol'];
const things = ['wire', 'switch', 'socket', 'MCB', 'pipe', 'elbow', 'tee', 'valve', 'tap', 'bulb', 'tube light', 'fan', 'hammer', 'drill bit', 'screw', 'nut bolt', 'hinge', 'lock', 'paint', 'brush', 'tape', 'cable', 'holder', 'plug', 'adaptor', 'trap', 'coupling', 'clamp', 'sealant', 'cutter'];
const sizes = ['0.5 inch', '1 inch', '1.5 sq mm', '2.5 sq mm', '4 sq mm', '16A', '6A', '32A', '9W', '12W', '20W', '100 mm', '75 mm', '3/4 inch', 'heavy', 'white', 'black', '1 litre', '4 litre'];

class Stats {
  Stats(List<double> ms) {
    ms.sort();
    n = ms.length;
    p50 = ms[ms.length ~/ 2];
    p95 = ms[(ms.length * 0.95).floor().clamp(0, ms.length - 1)];
    max = ms.last;
  }
  late final int n;
  late final double p50, p95, max;
  Map<String, Object> toJson() => {'n': n, 'p50Ms': double.parse(p50.toStringAsFixed(2)), 'p95Ms': double.parse(p95.toStringAsFixed(2)), 'maxMs': double.parse(max.toStringAsFixed(2))};
  @override
  String toString() => 'p50=${p50.toStringAsFixed(2)} p95=${p95.toStringAsFixed(2)} max=${max.toStringAsFixed(2)} ms (n=$n)';
}

final results = <String, Object>{};

List<double> timed(int n, void Function(int i) f) {
  final out = <double>[];
  for (var i = 0; i < n; i++) {
    final sw = Stopwatch()..start();
    f(i);
    out.add(sw.elapsedMicroseconds / 1000.0);
  }
  return out;
}

void report(String name, List<double> ms, {double? budget}) {
  final s = Stats(ms);
  results[name] = {...s.toJson(), if (budget != null) 'budgetMs': budget, if (budget != null) 'pass': s.p95 <= budget};
  stdout.writeln('${budget == null ? '    ' : (s.p95 <= budget ? 'OK  ' : 'SLOW')} $name: $s${budget == null ? '' : '  (budget $budget ms)'}');
}

// ------------------------------------------------------------------ seeding

String pname(int i) => '${brands[_r.nextInt(brands.length)]} ${things[_r.nextInt(things.length)]} ${sizes[_r.nextInt(sizes.length)]} #$i';

void seed(Database db, int nBills) {
  final sw = Stopwatch()..start();
  final start = DateTime(2026, 10, 13).subtract(const Duration(days: 365 * kYears));
  final nowMs = DateTime(2026, 10, 13, 18).millisecondsSinceEpoch;

  db.execute('PRAGMA synchronous = OFF');
  db.execute('BEGIN');
  final pids = <String>[];
  final prices = <int>[];
  final pIns = db.prepare('INSERT INTO products(id,name,barcode,price_paise,gst_bp,unit,min_qty_milli,updated_at) VALUES (?,?,?,?,?,?,?,?)');
  for (var i = 0; i < kProducts; i++) {
    final id = _u.v7();
    pids.add(id);
    final price = 1000 + _r.nextInt(500000);
    prices.add(price);
    pIns.execute([id, pname(i), '89012${i.toString().padLeft(8, '0')}', price, 1800, 'pcs', 5000, nowMs]);
  }
  pIns.dispose();
  db.execute("INSERT INTO product_fts(rowid,name,barcode) SELECT rowid,name,barcode FROM products");
  final cids = <String>[];
  final cIns = db.prepare('INSERT INTO customers(id,name,phone,city,credit_limit_paise,updated_at) VALUES (?,?,?,?,?,?)');
  for (var i = 0; i < kCustomers; i++) {
    final id = _u.v7();
    cids.add(id);
    cIns.execute([id, 'Customer ${i.toRadixString(36)} Traders', '98${40000000 + i}', 'Coimbatore', 5000000, nowMs]);
  }
  cIns.dispose();
  db.execute("INSERT INTO customer_fts(rowid,name,phone) SELECT rowid,name,phone FROM customers");
  db.execute('COMMIT');

  final bIns = db.prepare('INSERT INTO bills(id,number,customer_id,status,total_paise,received_paise,balance_paise,tax_paise,pay_mode,billed_at,day,idem_key,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)');
  final lIns = db.prepare('INSERT INTO bill_lines(id,bill_id,product_id,qty_milli,rate_paise,amount_paise) VALUES (?,?,?,?,?,?)');
  final mIns = db.prepare('INSERT INTO stock_movements(id,product_id,qty_milli,kind,ref_id,at) VALUES (?,?,?,?,?,?)');
  final ledIns = db.prepare('INSERT INTO ledger(id,customer_id,kind,amount_paise,running_paise,at,ref_id) VALUES (?,?,?,?,?,?,?)');
  final dueIns = db.prepare('INSERT INTO bill_due(bill_id,customer_id,due_paise,billed_at) VALUES (?,?,?,?)');

  final running = <String, int>{};
  final pending = <int, List<(String, String, int, String)>>{}; // dayIndex -> payments (customer, bill, amount, billId)
  final days = 365 * kYears;
  final perDay = nBills / days;
  var billNo = 0;
  var made = 0;
  int pickProduct() => _r.nextInt(100) < 90 ? _r.nextInt(2500) : _r.nextInt(kProducts);
  String pickCustomer() {
    final roll = _r.nextInt(100);
    if (roll < 3) return cids[0]; // the heavy customer
    if (roll < 40) return cids[1 + _r.nextInt(400)];
    return cids[_r.nextInt(kCustomers)];
  }

  for (var d = 0; d < days && made < nBills; d++) {
    final date = start.add(Duration(days: d));
    final day = ymd(date);
    final count = d == days - 1 ? nBills - made : (perDay * (0.7 + _r.nextDouble() * 0.6)).round();
    db.execute('BEGIN');
    // payments that fall due today
    for (final p in pending.remove(d) ?? const <(String, String, int, String)>[]) {
      final run = (running[p.$1] ?? 0) - p.$3;
      running[p.$1] = run;
      final at = date.add(const Duration(hours: 15)).millisecondsSinceEpoch;
      ledIns.execute([_u.v7(), p.$1, 'payment', -p.$3, run, at, p.$2]);
      db.execute('UPDATE bill_due SET due_paise = 0 WHERE bill_id = ?', [p.$4]);
    }
    for (var i = 0; i < count && made < nBills; i++, made++) {
      final id = _u.v7();
      billNo++;
      final at = date.add(Duration(hours: 9, minutes: (i * 600 ~/ max(count, 1)))).millisecondsSinceEpoch;
      final lines = 3 + _r.nextInt(6); // 3..8, about 5 on average
      var total = 0;
      for (var l = 0; l < lines; l++) {
        final pi = pickProduct();
        final qty = 1000 * (1 + _r.nextInt(4));
        final amt = prices[pi] * qty ~/ 1000;
        total += amt;
        lIns.execute([_u.v7(), id, pids[pi], qty, prices[pi], amt]);
        mIns.execute([_u.v7(), pids[pi], -qty, 'sale', id, at]);
      }
      final tax = total * 18 ~/ 118;
      var customer = _r.nextInt(100) < 55 ? null : pickCustomer();
      var received = total;
      var balance = 0;
      if (customer != null && _r.nextInt(100) < 22) {
        balance = max(100, total * (30 + _r.nextInt(70)) ~/ 100);
        received = total - balance;
      }
      final number = 'A-${billNo.toString().padLeft(7, '0')}';
      bIns.execute([id, number, customer, 0, total, received, balance, tax, _r.nextInt(3), at, day, id, at]);
      if (balance > 0 && customer != null) {
        final run = (running[customer] ?? 0) + balance;
        running[customer] = run;
        ledIns.execute([_u.v7(), customer, 'bill_credit', balance, run, at, id]);
        final paidAfter = d + 3 + _r.nextInt(60);
        // most credit is paid later; the newest stays unpaid (this is what "Money to collect" lists)
        if (paidAfter < days - 20 && _r.nextInt(100) < 92) {
          dueIns.execute([id, customer, balance, at]);
          (pending[paidAfter] ??= []).add((customer, number, balance, id));
        } else {
          dueIns.execute([id, customer, balance, at]);
        }
      }
    }
    db.execute('COMMIT');
    if (d % 180 == 0) stdout.writeln('  seeded day $d of $days: $made bills (${sw.elapsed.inSeconds} s)');
  }

  stdout.writeln('  bills=$made; building summary tables...');
  db.execute('BEGIN');
  db.execute("INSERT INTO day_totals SELECT day, COUNT(*), SUM(total_paise), SUM(tax_paise), SUM(CASE pay_mode WHEN 0 THEN received_paise ELSE 0 END), SUM(CASE pay_mode WHEN 1 THEN received_paise ELSE 0 END), SUM(CASE pay_mode WHEN 2 THEN received_paise ELSE 0 END), SUM(balance_paise) FROM bills GROUP BY day");
  db.execute("INSERT INTO stock_cache SELECT p.id, 100000000 + COALESCE((SELECT SUM(qty_milli) FROM stock_movements m WHERE m.product_id = p.id), 0) FROM products p");
  db.execute("INSERT INTO customer_balance SELECT c.id, COALESCE((SELECT running_paise FROM ledger l WHERE l.customer_id = c.id ORDER BY at DESC, id DESC LIMIT 1), 0), (SELECT MAX(billed_at) FROM bills b WHERE b.customer_id = c.id), (SELECT MAX(at) FROM ledger l WHERE l.customer_id = c.id AND l.kind = 'payment') FROM customers c");
  db.execute("INSERT INTO product_month SELECT l.product_id, substr(b.day,1,7), SUM(l.qty_milli), SUM(l.amount_paise) FROM bill_lines l JOIN bills b ON b.id = l.bill_id GROUP BY l.product_id, substr(b.day,1,7)");
  db.execute("INSERT INTO counters VALUES ('A-', $billNo)");
  db.execute('COMMIT');
  db.execute('PRAGMA synchronous = FULL');
  db.execute('ANALYZE');
  db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  stdout.writeln('  seed finished in ${sw.elapsed.inSeconds} s');
  results['seedSeconds'] = sw.elapsed.inSeconds;
}

// ------------------------------------------------------------------ measurements

Database openDb(String path) {
  final db = sqlite3.open(path);
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('PRAGMA synchronous = FULL'); // safest setting
  db.execute('PRAGMA foreign_keys = ON');
  db.execute('PRAGMA cache_size = -32768'); // 32 MB of cache: a small shop PC, not this machine
  db.execute('PRAGMA mmap_size = 0');
  return db;
}

String ftsQuery(String q) => q.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((s) => '"${s.replaceAll('"', '')}"*').join(' ');

void measure(String path, int nBills) {
  // ---- cold start: open, set up, load what the first screen needs (the check runs later, in the background)
  final sw = Stopwatch()..start();
  var db = openDb(path);
  db.select('SELECT COUNT(*) FROM counters');
  db.select('SELECT * FROM day_totals ORDER BY day DESC LIMIT 7');
  final coldMs = sw.elapsedMicroseconds / 1000.0;
  results['coldStartOpenMs'] = double.parse(coldMs.toStringAsFixed(1));
  stdout.writeln('${coldMs <= 1000 ? 'OK  ' : 'SLOW'} cold start (open + first data): ${coldMs.toStringAsFixed(1)} ms  (budget 1000)');
  sw
    ..reset()
    ..start();
  db.select('PRAGMA quick_check(1)');
  results['quickCheckSeconds'] = double.parse((sw.elapsedMilliseconds / 1000).toStringAsFixed(1));
  stdout.writeln('     quick_check on the whole file (run in the background after start): ${sw.elapsed.inSeconds} s');

  final sizeBytes = File(path).lengthSync();
  results['dbBytes'] = sizeBytes;
  results['bytesPerBill'] = (sizeBytes / nBills).round();
  stdout.writeln('     database file: ${(sizeBytes / 1048576).toStringAsFixed(0)} MB = ${(sizeBytes / nBills).round()} bytes per bill (with lines, movements, ledger and every index)');

  // where the bytes go (per table and index), largest first
  try {
    final sizes = db.select("SELECT name, SUM(pgsize) b FROM dbstat GROUP BY name ORDER BY b DESC LIMIT 14");
    results['largestObjectsMB'] = {for (final r in sizes) r['name'] as String: ((r['b'] as int) / 1048576).round()};
    stdout.writeln('     biggest tables and indexes (MB): ${sizes.map((r) => '${r['name']}=${((r['b'] as int) / 1048576).round()}').join(', ')}');
  } catch (_) {
    stdout.writeln('     (table sizes are not available in this SQLite build)');
  }

  final someBills = db.select('SELECT id, number, customer_id, billed_at FROM bills WHERE customer_id IS NOT NULL ORDER BY RANDOM() LIMIT 400');
  final someProducts = db.select('SELECT id, name, barcode FROM products ORDER BY RANDOM() LIMIT 400');
  final bigCust = db.select("SELECT customer_id, COUNT(*) c FROM ledger GROUP BY customer_id ORDER BY c DESC LIMIT 1").first;
  results['heaviestCustomerLedgerRows'] = bigCust['c'] as int;
  stdout.writeln('     heaviest customer has ${bigCust['c']} ledger rows');

  // ---- New bill: product search per keystroke (FTS5 prefix over 50,000), barcode scan, add an item
  final search = <double>[];
  for (var k = 0; k < 120; k++) {
    final n = (someProducts[k % someProducts.length]['name'] as String).toLowerCase();
    final typed = n.substring(0, min(n.length, 12));
    for (var c = 2; c <= typed.length; c++) {
      final q = ftsQuery(typed.substring(0, c).trim());
      if (q.isEmpty) continue;
      final t = Stopwatch()..start();
      db.select('SELECT p.id,p.name,p.price_paise FROM product_fts f JOIN products p ON p.rowid=f.rowid WHERE product_fts MATCH ? AND p.deleted_at IS NULL ORDER BY rank LIMIT 50', [q]);
      search.add(t.elapsedMicroseconds / 1000.0);
    }
  }
  report('New bill: product search per keystroke (FTS5, 50,000 products)', search, budget: 50);
  report('New bill: barcode scan lookup', timed(300, (i) => db.select('SELECT id,name,price_paise FROM products WHERE barcode = ?', [someProducts[i % 400]['barcode']])), budget: 50);
  report('New bill: add item (price + stock from the cache)', timed(300, (i) => db.select('SELECT p.id,p.name,p.price_paise,p.gst_bp,s.qty_milli FROM products p JOIN stock_cache s ON s.product_id=p.id WHERE p.id = ?', [someProducts[i % 400]['id']])), budget: 50);
  report('New bill: first 50 products by name (list opens)', timed(40, (_) => db.select('SELECT id,name,price_paise FROM products ORDER BY name COLLATE NOCASE, id LIMIT 50')), budget: 300);
  // scrolling the 50,000-product list: keyset pages, each 50 rows, deep into the list
  var after = '';
  var afterId = '';
  final scroll = <double>[];
  for (var i = 0; i < 400; i++) {
    final t = Stopwatch()..start();
    final rows = db.select("SELECT id,name,price_paise FROM products WHERE (name COLLATE NOCASE, id) > (?, ?) ORDER BY name COLLATE NOCASE, id LIMIT 50", [after, afterId]);
    scroll.add(t.elapsedMicroseconds / 1000.0);
    if (rows.isEmpty) break;
    after = rows.last['name'] as String;
    afterId = rows.last['id'] as String;
  }
  report('Product list scrolling: next 50 rows by cursor (400 pages = 20,000 rows deep)', scroll, budget: 50);

  // ---- Save bill: the real transaction incl. every summary table
  final saveSelectProd = db.prepare('SELECT price_paise FROM products WHERE id = ?');
  final ins = {
    'bill': db.prepare('INSERT INTO bills(id,number,customer_id,status,total_paise,received_paise,balance_paise,tax_paise,pay_mode,billed_at,day,idem_key,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)'),
    'line': db.prepare('INSERT INTO bill_lines(id,bill_id,product_id,qty_milli,rate_paise,amount_paise) VALUES (?,?,?,?,?,?)'),
    'mov': db.prepare('INSERT INTO stock_movements(id,product_id,qty_milli,kind,ref_id,at) VALUES (?,?,?,?,?,?)'),
    'stock': db.prepare('UPDATE stock_cache SET qty_milli = qty_milli + ? WHERE product_id = ?'),
    'pm': db.prepare('INSERT INTO product_month(product_id,month,qty_milli,amount_paise) VALUES (?,?,?,?) ON CONFLICT(product_id,month) DO UPDATE SET qty_milli=qty_milli+excluded.qty_milli, amount_paise=amount_paise+excluded.amount_paise'),
    'day': db.prepare('INSERT INTO day_totals(day,bills,sales_paise,tax_paise,cash_paise,upi_paise,card_paise,credit_paise) VALUES (?,1,?,?,?,0,0,?) ON CONFLICT(day) DO UPDATE SET bills=bills+1, sales_paise=sales_paise+excluded.sales_paise, tax_paise=tax_paise+excluded.tax_paise, cash_paise=cash_paise+excluded.cash_paise, credit_paise=credit_paise+excluded.credit_paise'),
    'ctr': db.prepare("UPDATE counters SET next = next + 1 WHERE series = 'A-' RETURNING next"),
    'led': db.prepare('INSERT INTO ledger(id,customer_id,kind,amount_paise,running_paise,at,ref_id) VALUES (?,?,?,?,?,?,?)'),
    'bal': db.prepare('INSERT INTO customer_balance(customer_id,balance_paise,last_bill_at) VALUES (?,?,?) ON CONFLICT(customer_id) DO UPDATE SET balance_paise=balance_paise+excluded.balance_paise, last_bill_at=excluded.last_bill_at'),
    'due': db.prepare('INSERT INTO bill_due(bill_id,customer_id,due_paise,billed_at) VALUES (?,?,?,?)'),
    'out': db.prepare('INSERT INTO outbox(record_id,kind,at) VALUES (?,?,?)'),
  };
  final nowMs = DateTime(2026, 10, 14, 10).millisecondsSinceEpoch;
  final saveCust = someBills.map((r) => r['customer_id'] as String).toList();
  final save = <double>[];
  for (var i = 0; i < 400; i++) {
    final t = Stopwatch()..start();
    db.execute('BEGIN');
    final id = _u.v7();
    final no = ins['ctr']!.select([]).first['next'] as int;
    var total = 0;
    final lines = 3 + i % 6;
    final month = '2026-10', day = '2026-10-14';
    for (var l = 0; l < lines; l++) {
      final pid = someProducts[(i * 7 + l) % 400]['id'];
      final price = saveSelectProd.select([pid]).first['price_paise'] as int;
      total += price * 2;
      ins['line']!.execute([_u.v7(), id, pid, 2000, price, price * 2]);
      ins['mov']!.execute([_u.v7(), pid, -2000, 'sale', id, nowMs]);
      ins['stock']!.execute([-2000, pid]);
      ins['pm']!.execute([pid, month, 2000, price * 2]);
    }
    final credit = i % 4 == 0;
    final cust = credit ? saveCust[i % saveCust.length] : null;
    final bal = credit ? total ~/ 2 : 0;
    ins['bill']!.execute([id, 'A-${no.toString().padLeft(7, '0')}', cust, 0, total, total - bal, bal, total * 18 ~/ 118, 0, nowMs + i, day, id, nowMs]);
    ins['day']!.execute([day, total, total * 18 ~/ 118, total - bal, bal]);
    if (credit) {
      final run = (db.select('SELECT balance_paise FROM customer_balance WHERE customer_id = ?', [cust]).firstOrNull?['balance_paise'] as int? ?? 0) + bal;
      ins['led']!.execute([_u.v7(), cust, 'bill_credit', bal, run, nowMs + i, id]);
      ins['bal']!.execute([cust, bal, nowMs + i]);
      ins['due']!.execute([id, cust, bal, nowMs + i]);
    }
    ins['out']!.execute([id, 'bill', nowMs + i]);
    db.execute('COMMIT');
    save.add(t.elapsedMicroseconds / 1000.0);
  }
  for (final s in ins.values) {
    s.dispose();
  }
  saveSelectProd.dispose();
  report('Save bill (1 transaction: bill, lines, stock movements, stock cache, ledger, balance, day and product totals, outbox)', save, budget: 100);

  // ---- pages: first screen of each
  final recent = db.select('SELECT billed_at, id FROM bills ORDER BY billed_at DESC, id DESC LIMIT 1').first;
  report('Sales register: first 50 bills (with customer name)', timed(60, (_) => db.select('SELECT b.id,b.number,b.billed_at,b.total_paise,b.balance_paise,b.status,c.name FROM bills b LEFT JOIN customers c ON c.id=b.customer_id ORDER BY b.billed_at DESC, b.id DESC LIMIT 50')), budget: 300);
  // deep paging by cursor: start from a bill 3 years ago
  final deep = db.select("SELECT billed_at, id FROM bills WHERE day = '2023-10-13' LIMIT 1").first;
  report('Sales register: page 50 rows by cursor, 3 years back (not OFFSET)', timed(60, (_) => db.select('SELECT b.id,b.number,b.billed_at,b.total_paise,c.name FROM bills b LEFT JOIN customers c ON c.id=b.customer_id WHERE (b.billed_at, b.id) < (?, ?) ORDER BY b.billed_at DESC, b.id DESC LIMIT 50', [deep['billed_at'], deep['id']])), budget: 300);
  report('Bill history search: by bill number prefix', timed(200, (i) => db.select("SELECT id,number,billed_at,total_paise FROM bills WHERE number >= ? AND number < ? ORDER BY number LIMIT 50", [(someBills[i % 400]['number'] as String).substring(0, 6), '${(someBills[i % 400]['number'] as String).substring(0, 5)}~'])), budget: 50);
  report('Bill history search: exact bill number', timed(300, (i) => db.select('SELECT id,number,total_paise FROM bills WHERE number = ?', [someBills[i % 400]['number']])), budget: 50);
  report('Bill history: one customer, newest 50 bills', timed(200, (i) => db.select('SELECT id,number,billed_at,total_paise FROM bills WHERE customer_id = ? ORDER BY billed_at DESC, id DESC LIMIT 50', [someBills[i % 400]['customer_id']])), budget: 300);
  report('Bill history: one day (date range, indexed), 50 rows', timed(100, (i) => db.select("SELECT id,number,total_paise FROM bills WHERE billed_at >= ? AND billed_at < ? ORDER BY billed_at DESC LIMIT 50", [DateTime(2024, 3, 1 + i % 25).millisecondsSinceEpoch, DateTime(2024, 3, 2 + i % 25).millisecondsSinceEpoch])), budget: 300);
  report('Bill history: cancelled bills only (partial index)', timed(60, (_) => db.select('SELECT id,number FROM bills WHERE status = 1 ORDER BY billed_at DESC, id DESC LIMIT 50')), budget: 300);
  report('Customers: search by name or phone (FTS5 prefix, 5,000)', timed(300, (i) => db.select('SELECT c.id,c.name,c.phone FROM customer_fts f JOIN customers c ON c.rowid=f.rowid WHERE customer_fts MATCH ? LIMIT 50', [ftsQuery('customer ${(i % 4000).toRadixString(36)}')])), budget: 50);
  report('Customers: first 50 with balances', timed(60, (_) => db.select('SELECT c.id,c.name,c.phone,COALESCE(b.balance_paise,0) bal FROM customers c LEFT JOIN customer_balance b ON b.customer_id=c.id ORDER BY c.name COLLATE NOCASE, c.id LIMIT 50')), budget: 300);
  report('Money to collect: who owes (partial index), top 50 by amount', timed(100, (_) => db.select('SELECT c.id,c.name,b.balance_paise FROM customer_balance b JOIN customers c ON c.id=b.customer_id WHERE b.balance_paise > 0 ORDER BY b.balance_paise DESC LIMIT 50')), budget: 300);
  report('Money to collect: totals (sum of what is owed)', timed(100, (_) => db.select('SELECT COUNT(*), SUM(balance_paise) FROM customer_balance WHERE balance_paise > 0')), budget: 300);
  final heavy = bigCust['customer_id'];
  report('Customer profile: heaviest customer, header + unpaid bills + newest 50 ledger rows', timed(60, (_) {
    db.select('SELECT * FROM customer_balance WHERE customer_id = ?', [heavy]);
    db.select('SELECT bill_id,due_paise,billed_at FROM bill_due WHERE customer_id = ? AND due_paise > 0 ORDER BY billed_at', [heavy]);
    db.select('SELECT id,kind,amount_paise,running_paise,at FROM ledger WHERE customer_id = ? ORDER BY at DESC, id DESC LIMIT 50', [heavy]);
  }), budget: 300);
  report('Customer profile: ALL ${bigCust['c']} ledger rows read at once (statement of the whole history)', timed(10, (_) => db.select('SELECT id,kind,amount_paise,running_paise,at FROM ledger WHERE customer_id = ? ORDER BY at, id', [heavy])), budget: 300);
  report('Dashboard: today, last 7 days, this month, this year (from day totals)', timed(100, (_) {
    db.select("SELECT * FROM day_totals WHERE day >= '2026-10-07'");
    db.select("SELECT SUM(sales_paise),SUM(bills) FROM day_totals WHERE day >= '2026-10-01'");
    db.select("SELECT SUM(sales_paise),SUM(bills) FROM day_totals WHERE day >= '2026-01-01'");
    db.select("SELECT COUNT(*) FROM stock_cache WHERE qty_milli <= 100000000 - 99999000 + 5000");
  }), budget: 300);
  report('Stock left page: first 50 with stock', timed(60, (_) => db.select('SELECT p.id,p.name,s.qty_milli FROM stock_cache s JOIN products p ON p.id=s.product_id ORDER BY s.qty_milli LIMIT 50')), budget: 300);
  report('Reports: sales by day for 12 months (from day totals)', timed(60, (_) => db.select("SELECT day,sales_paise,tax_paise FROM day_totals WHERE day >= '2025-10-01' ORDER BY day")), budget: 300);
  report('Reports: top 20 products in a year (from product-month totals)', timed(60, (_) => db.select("SELECT product_id,SUM(amount_paise) a FROM product_month WHERE month >= '2025-10' GROUP BY product_id ORDER BY a DESC LIMIT 20")), budget: 300);
  // the same questions answered by scanning the raw data: this is what the summary tables avoid (run in a background isolate with progress)
  final raw1 = timed(3, (_) => db.select("SELECT SUM(total_paise),COUNT(*) FROM bills WHERE billed_at >= ? AND billed_at < ?", [DateTime(2025, 10, 1).millisecondsSinceEpoch, DateTime(2026, 10, 1).millisecondsSinceEpoch]));
  report('For comparison (NOT used by the screens): sum of a whole year scanning 200,000 bills', raw1);
  final raw2 = timed(2, (_) => db.select('SELECT product_id, SUM(amount_paise) a FROM bill_lines GROUP BY product_id ORDER BY a DESC LIMIT 20'));
  report('For comparison (NOT used by the screens): top 20 products scanning all 5 million lines', raw2);
  report('Report: one product over 5 years from raw lines (indexed by product)', timed(60, (i) => db.select('SELECT b.day, SUM(l.qty_milli) FROM bill_lines l JOIN bills b ON b.id=l.bill_id WHERE l.product_id = ? GROUP BY b.day', [someProducts[i % 400]['id']])), budget: 1000);

  // ---- backup and restore
  final dir = File(path).parent.path;
  db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  final bkp = '$dir${Platform.pathSeparator}backup-test.sqlite';
  if (File(bkp).existsSync()) File(bkp).deleteSync();
  sw
    ..reset()
    ..start();
  db.execute("VACUUM INTO '${bkp.replaceAll("'", "''")}'");
  results['backupVacuumIntoSeconds'] = double.parse((sw.elapsedMilliseconds / 1000).toStringAsFixed(1));
  stdout.writeln('     backup (VACUUM INTO, compacts and checks as it copies): ${sw.elapsed.inSeconds} s -> ${(File(bkp).lengthSync() / 1048576).toStringAsFixed(0)} MB');
  final copyTo = '$dir${Platform.pathSeparator}backup-copy.sqlite';
  sw
    ..reset()
    ..start();
  File(path).copySync(copyTo);
  results['backupFileCopySeconds'] = double.parse((sw.elapsedMilliseconds / 1000).toStringAsFixed(1));
  stdout.writeln('     backup (plain file copy after checkpoint): ${sw.elapsed.inSeconds} s');
  db.dispose();
  sw
    ..reset()
    ..start();
  final restored = sqlite3.open(bkp);
  final q = restored.select('PRAGMA quick_check(1)').first.values.first;
  final cnt = restored.select('SELECT COUNT(*) c FROM bills').first['c'];
  restored.dispose();
  results['restoreVerifySeconds'] = double.parse((sw.elapsedMilliseconds / 1000).toStringAsFixed(1));
  stdout.writeln('     restore check (open the backup, quick_check=$q, $cnt bills): ${sw.elapsed.inSeconds} s');
  for (final f in [bkp, copyTo]) {
    if (File(f).existsSync()) File(f).deleteSync();
  }

  // ---- archive the oldest year in small steps and shrink the file, without freezing the screen
  db = openDb(path);
  final cutoff = DateTime(2021, 10, 14).add(const Duration(days: 365)).millisecondsSinceEpoch; // the oldest year
  final oldBills = db.select('SELECT COUNT(*) c FROM bills WHERE billed_at < ?', [cutoff]).first['c'] as int;
  final archivePath = '$dir${Platform.pathSeparator}archive-oldest-year.sqlite';
  if (File(archivePath).existsSync()) File(archivePath).deleteSync();
  db.execute("ATTACH DATABASE '${archivePath.replaceAll("'", "''")}' AS arch");
  db.execute('CREATE TABLE arch.bills AS SELECT * FROM main.bills WHERE 0');
  db.execute('CREATE TABLE arch.bill_lines AS SELECT * FROM main.bill_lines WHERE 0');
  db.execute('CREATE TABLE arch.stock_movements AS SELECT * FROM main.stock_movements WHERE 0');
  final chunk = <double>[];
  final totalSw = Stopwatch()..start();
  var moved = 0;
  while (true) {
    final t = Stopwatch()..start();
    db.execute('BEGIN');
    final ids = db.select('SELECT id FROM bills WHERE billed_at < ? ORDER BY billed_at, id LIMIT 300', [cutoff]).map((r) => r['id'] as String).toList();
    if (ids.isEmpty) {
      db.execute('COMMIT');
      break;
    }
    final list = ids.map((e) => "'$e'").join(',');
    db.execute('INSERT INTO arch.bills SELECT * FROM main.bills WHERE id IN ($list)');
    db.execute('INSERT INTO arch.bill_lines SELECT * FROM main.bill_lines WHERE bill_id IN ($list)');
    db.execute('INSERT INTO arch.stock_movements SELECT * FROM main.stock_movements WHERE ref_id IN ($list)');
    db.execute('DELETE FROM main.stock_movements WHERE ref_id IN ($list)');
    db.execute('DELETE FROM main.bill_lines WHERE bill_id IN ($list)');
    db.execute('DELETE FROM main.bill_due WHERE bill_id IN ($list)');
    db.execute('DELETE FROM main.bills WHERE id IN ($list)');
    db.execute('COMMIT');
    chunk.add(t.elapsedMicroseconds / 1000.0);
    moved += ids.length;
  }
  results['archivedBills'] = moved;
  results['archiveTotalSeconds'] = double.parse((totalSw.elapsedMilliseconds / 1000).toStringAsFixed(1));
  stdout.writeln('     archived the oldest year: $moved of $oldBills bills in ${totalSw.elapsed.inSeconds} s, in ${chunk.length} steps of 300 bills');
  report('Archive: each step of 300 bills (the screen is free between steps)', chunk, budget: 250);
  final before = File(path).lengthSync();
  final vac = <double>[];
  final vsw = Stopwatch()..start();
  while (true) {
    final t = Stopwatch()..start();
    final free = db.select('PRAGMA freelist_count').first.values.first as int;
    if (free < 100) break;
    db.execute('PRAGMA incremental_vacuum(2000)');
    vac.add(t.elapsedMicroseconds / 1000.0);
  }
  db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  results['compactTotalSeconds'] = double.parse((vsw.elapsedMilliseconds / 1000).toStringAsFixed(1));
  stdout.writeln('     compact (incremental vacuum): ${vsw.elapsed.inSeconds} s, file ${(before / 1048576).toStringAsFixed(0)} MB -> ${(File(path).lengthSync() / 1048576).toStringAsFixed(0)} MB; archive file ${(File(archivePath).lengthSync() / 1048576).toStringAsFixed(0)} MB');
  if (vac.isNotEmpty) report('Compact: each step of 2,000 pages (about 8 MB)', vac, budget: 250);
  results['dbBytesAfterArchive'] = File(path).lengthSync();
  results['archiveBytes'] = File(archivePath).lengthSync();
  db.execute('DETACH DATABASE arch');
  db.dispose();

  stdout.writeln('\nFree disk on this drive: ${Directory(dir).statSync().type == FileSystemEntityType.directory ? 'see Windows' : ''}');
}

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : 'D:\\erp2-scale\\scale1m.sqlite';
  final nBills = args.length > 1 ? int.parse(args[1]) : 1000000;
  final mode = args.length > 2 ? args[2] : 'seed';
  Directory(File(path).parent.path).createSync(recursive: true);
  if (mode == 'seed') {
    for (final s in ['', '-wal', '-shm']) {
      final f = File('$path$s');
      if (f.existsSync()) f.deleteSync();
    }
    final db = sqlite3.open(path);
    for (final stmt in _schema.split(';\n').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
      db.execute(stmt);
    }
    stdout.writeln('seeding $nBills bills...');
    seed(db, nBills);
    db.dispose();
  }
  results['bills'] = nBills;
  measure(path, nBills);
  File('${File(path).parent.path}${Platform.pathSeparator}scale1m-results.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  stdout.writeln('results written to scale1m-results.json');
}
