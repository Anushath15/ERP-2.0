// Speed of the REAL repository layer on a big shop: builds a database in the real schema (default 1,000,000 bills over 5 years, 5 lines
// each, 5,000 customers, 50,000 products), then measures what the screens do, through the same repositories the screens use.
//
//   dart run tool/perf/db_scale.dart [bills=1000000] [file=build/perf_scale.sqlite] [--reuse]
//
// The database file is a test file and is never committed. Results go to stdout as a table and to <file>.json.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/integrity.dart';
import 'package:erp2/data/db/open.dart';
import 'package:erp2/data/ids.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/self_check.dart';
import 'package:erp2/domain/credit/account.dart';
import 'package:sqlite3/sqlite3.dart';

const _bills = 'bills';

Future<void> main(List<String> args) async {
  final reuse = args.contains('--reuse');
  final onlyCheck = args.contains('--only-selfcheck');
  final pos = args.where((a) => !a.startsWith('--')).toList();
  final billCount = pos.isNotEmpty ? int.parse(pos[0]) : 1000000;
  final path = pos.length > 1 ? pos[1] : 'build/perf_scale.sqlite';
  final out = <String, Object>{'bills': billCount};

  if (!reuse || !File(path).existsSync()) {
    for (final s in ['', '-wal', '-shm']) {
      final f = File('$path$s');
      if (f.existsSync()) f.deleteSync();
    }
    final sw = Stopwatch()..start();
    await _build(path, billCount);
    out['buildSeconds'] = sw.elapsed.inSeconds;
    stdout.writeln('built $billCount bills in ${sw.elapsed.inSeconds} s, file ${(File(path).lengthSync() / 1048576).round()} MB');
  }
  out['fileMB'] = (File(path).lengthSync() / 1048576).round();

  if (onlyCheck) {
    final raw = sqlite3.open(path);
    raw.execute('DROP INDEX IF EXISTS stock_movements_product');
    raw.execute('CREATE INDEX stock_movements_product ON stock_movements(product_id, at, qty_milli)');
    raw.close();
    final t = Stopwatch()..start();
    final found = await selfCheckFile(path);
    stdout.writeln('self-check in a separate isolate: ${(t.elapsedMilliseconds / 1000).toStringAsFixed(1)} s, problems: $found');
    return;
  }
  final results = <String, List<double>>{};
  Future<T> time<T>(String name, Future<T> Function() f) async {
    final sw = Stopwatch()..start();
    final r = await f();
    results.putIfAbsent(name, () => []).add(sw.elapsedMicroseconds / 1000.0);
    return r;
  }

  // cold start: open the file and read everything the first screens need
  final sw0 = Stopwatch()..start();
  final db = await openShopDatabase(path);
  final d = AppData(DataContext(db: db, deviceId: 'dev-perf'));
  d.bills.series = 'A';
  await d.bills.page(limit: 50);
  await d.reports.day(DateTime.now());
  results['Cold start: open + first bills + today (budget 1000 ms)'] = [sw0.elapsedMicroseconds / 1000.0];
  final swBoot = Stopwatch()..start();
  final products = await d.catalog.products();
  final customers = await d.catalog.customers();
  results['Start-up lists: all ${products.length} products + ${customers.length} customers read into memory'] = [swBoot.elapsedMicroseconds / 1000.0];

  final r = Random(5);
  // product search as typed
  final words = ['hav', 'anc', 'poly', 'fin', 'ast', 'supr', 'ash', 'jaq', 'cera', 'orie', 'crom', 'leg', 'phil', 'bosc', 'asia', 'fevi', 'godr', 'tapa', 'stan', 'sysk', 'lock', 'bolt', 'wire', 'led', 'fan'];
  for (var i = 0; i < 300; i++) {
    final w = words[r.nextInt(words.length)];
    await time('New bill: product search per keystroke, FTS5 (budget 50 ms)', () => d.catalog.searchProducts(w.substring(0, 2 + r.nextInt(w.length - 1))));
  }
  for (var i = 0; i < 300; i++) {
    await time('New bill: barcode scan lookup (budget 50 ms)', () => d.catalog.productByBarcode('890${1000000 + r.nextInt(50000)}'));
  }

  // register pages: newest, deep (keyset), by number, by customer name
  final first = await d.bills.page(limit: 50);
  for (var i = 0; i < 50; i++) {
    await time('Sales register: first page of 50 (budget 300 ms)', () => d.bills.page(limit: 50));
  }
  var cursor = BillRepo.cursorOf(first.last);
  for (var i = 0; i < 200; i++) {
    final p = await time('Sales register: next page, keyset, scrolling down (budget 300 ms)', () => d.bills.page(after: cursor, limit: 50));
    cursor = BillRepo.cursorOf(p.last);
  }
  final deepCursor = BillCursor(DateTime.now().subtract(const Duration(days: 900)).millisecondsSinceEpoch, 'ffffffff');
  for (var i = 0; i < 30; i++) {
    await time('Sales register: page 900 days back (budget 300 ms)', () => d.bills.page(after: deepCursor, limit: 50));
  }
  for (var i = 0; i < 30; i++) {
    final n = 1 + r.nextInt(billCount);
    await time('Sales register: search by bill number (budget 300 ms)', () => d.bills.page(search: 'A-${n.toString().padLeft(6, '0')}', limit: 50));
  }
  for (var i = 0; i < 10; i++) {
    await time('Sales register: search by customer name (budget 300 ms)', () => d.bills.page(search: customers[r.nextInt(customers.length)].name, limit: 50));
  }
  for (var i = 0; i < 10; i++) {
    await time('Sales register: filter "on credit" (budget 300 ms)', () => d.bills.page(status: 3, limit: 50));
  }
  for (var i = 0; i < 5; i++) {
    await time('Sales register: sorted by amount, biggest first (budget 300 ms)', () => d.bills.page(byAmount: true, limit: 50));
  }
  for (var i = 0; i < 5; i++) {
    await time('Home: day totals, last 7 days + today + to collect + low stock (budget 300 ms)', () async {
      await d.reports.days(DateTime.now().subtract(const Duration(days: 6)), DateTime.now());
      await d.reports.toCollect();
      await d.reports.lowStockCount();
    });
  }
  for (var i = 0; i < 5; i++) {
    await time('Reports: a year of sales by day (budget 300 ms)', () => d.reports.days(DateTime.now().subtract(const Duration(days: 365)), DateTime.now()));
    await time('Reports: top products of a year, monthly summary (budget 300 ms)', () => d.reports.topProducts(DateTime.now().subtract(const Duration(days: 365)), DateTime.now()));
    await time('Reports: top products of the last 30 days, from the bill lines (budget 300 ms)', () => d.reports.topProducts(DateTime.now().subtract(const Duration(days: 30)), DateTime.now()));
  }

  // a customer with a long history: the profile
  final busiest = (await d.db.rows('SELECT party_id FROM party_balance WHERE party_kind = ? ORDER BY entry_count DESC LIMIT 3', ['customer'])).map((x) => x.read<String>('party_id')).toList();
  for (final id in busiest) {
    final n = await d.db.scalarInt('SELECT COUNT(*) FROM ledger_entries WHERE party_id = ?', [id]);
    await time('Customer profile: whole account of a customer with $n ledger entries (budget 300 ms)', () => d.ledger.account(id));
  }
  for (var i = 0; i < 10; i++) {
    await time('Money to collect: the 500 biggest balances (budget 300 ms)', () => d.ledger.balances(PartyKind.customer, limit: 500));
  }

  // saving: the budget that matters most
  final prods = products.take(2000).toList();
  final someCustomers = customers.take(200).toList();
  for (var i = 0; i < 400; i++) {
    final lines = [
      for (var k = 0; k < 1 + r.nextInt(8); k++)
        () {
          final p = prods[r.nextInt(prods.length)];
          return BillLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: 1000 * (1 + r.nextInt(4)), ratePaise: p.pricePaise, gstBp: p.gstBp, costPaise: p.costPaise);
        }(),
    ];
    final credit = i % 5 == 0;
    final c = someCustomers[r.nextInt(someCustomers.length)];
    await time('SAVE BILL: one transaction, bill + lines + stock + ledger + summaries + upload row (budget 100 ms)', () => d.bills.saveBill(SaveBillInput(idemKey: 'perf-$i-${newId()}', at: DateTime.now(), lines: lines, customerId: credit ? c.id : null, customerName: credit ? c.name : '', receivedPaise: credit ? 0 : null)));
  }
  for (var i = 0; i < 50; i++) {
    final c = someCustomers[r.nextInt(someCustomers.length)];
    await time('Receive payment: one transaction (budget 100 ms)', () => d.ledger.receivePayment(PartyKind.customer, partyId: c.id, partyName: c.name, amount: 100 + r.nextInt(5000), mode: 'cash', at: DateTime.now()));
  }

  // the checks that run in the background
  final sq = Stopwatch()..start();
  final quick = await checkDatabaseFile(path);
  out['quickCheckSeconds'] = double.parse((sq.elapsedMilliseconds / 1000).toStringAsFixed(1));
  out['quickCheckProblems'] = quick.length;
  final sc = Stopwatch()..start();
  final slow = <String>[];
  final problems = await selfCheck(db, onTime: (what, ms) => slow.add('${(ms / 1000).toStringAsFixed(1)} s  $what'));
  stdout.writeln('self-check, one line per check:');
  slow.forEach(stdout.writeln);
  out['selfCheckSeconds'] = double.parse((sc.elapsedMilliseconds / 1000).toStringAsFixed(1));
  out['selfCheckProblems'] = [for (final p in problems) '$p'];
  await db.close();

  String f(double v) => v.toStringAsFixed(v < 10 ? 2 : 1);
  final table = <Map<String, Object>>[];
  stdout.writeln('\n| Measure | runs | p50 ms | p95 ms | max ms |\n|---|---|---|---|---|');
  for (final e in results.entries) {
    final v = [...e.value]..sort();
    final p50 = v[(v.length * 0.5).floor()], p95 = v[min(v.length - 1, (v.length * 0.95).floor())], mx = v.last;
    stdout.writeln('| ${e.key} | ${v.length} | ${f(p50)} | ${f(p95)} | ${f(mx)} |');
    table.add({'measure': e.key, 'runs': v.length, 'p50': p50, 'p95': p95, 'max': mx});
  }
  stdout.writeln('\nbackground checks: quick_check ${out['quickCheckSeconds']} s (problems ${out['quickCheckProblems']}); self-check ${out['selfCheckSeconds']} s ${out['selfCheckProblems']}');
  out['results'] = table;
  File('$path.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
}

// ------------------------------------------------------------------------------------------------------------------ building the big file

Future<void> _build(String path, int billCount) async {
  // 1. the real schema, created by the real code
  final db = await openShopDatabase(path);
  await db.close();

  final raw = sqlite3.open(path);
  raw.execute('PRAGMA journal_mode = WAL');
  raw.execute('PRAGMA synchronous = OFF'); // building a test file only; the measurements below run with the real, safe settings
  raw.execute('PRAGMA cache_size = -400000');
  final r = Random(11);
  final t0 = DateTime.now().millisecondsSinceEpoch;
  const dev = 'dev-perf';

  // products with barcodes, customers
  const brands = ['HAVELLS', 'ANCHOR', 'POLYCAB', 'FINOLEX', 'ASTRAL', 'SUPREME', 'ASHIRVAD', 'JAQUAR', 'CERA', 'ORIENT', 'CROMPTON', 'LEGRAND', 'PHILIPS', 'BOSCH', 'TAPARIA', 'STANLEY'];
  const things = ['SWITCH', 'SOCKET', 'WIRE', 'MCB', 'LED BULB', 'FAN', 'ELBOW', 'TEE', 'PIPE', 'BIB COCK', 'VALVE', 'LOCK', 'BOLT', 'SCREW', 'DRILL BIT', 'SPANNER', 'BRUSH', 'TAPE'];
  final productIds = <String>[];
  raw.execute('BEGIN');
  final ps = raw.prepare('INSERT INTO products(id, name, category, unit, price_paise, cost_paise, gst_bp, hsn, barcode, min_stock_milli, created_at, updated_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)');
  final prices = <int>[];
  final costs = <int>[];
  for (var i = 0; i < 50000; i++) {
    final id = newId();
    productIds.add(id);
    final price = 1500 + r.nextInt(200000);
    prices.add(price);
    costs.add(price * 70 ~/ 100);
    ps.execute([id, '${brands[r.nextInt(brands.length)]} ${1 + r.nextInt(40)} ${things[r.nextInt(things.length)]} ${1 + r.nextInt(500)}', 'Hardware', 'pcs', price, price * 70 ~/ 100, 1800, '8302', '890${1000000 + i}', 5000, t0 - i, t0 - i, dev]);
  }
  ps.close();
  raw.execute('COMMIT');
  final customerIds = <String>[];
  raw.execute('BEGIN');
  final cs = raw.prepare('INSERT INTO customers(id, name, phone, city, credit_limit_paise, created_at, updated_at, device_id) VALUES (?,?,?,?,?,?,?,?)');
  for (var i = 0; i < 5000; i++) {
    final id = newId();
    customerIds.add(id);
    cs.execute([id, 'CUSTOMER ${i + 1} ${brands[r.nextInt(brands.length)]} TRADERS', '98${40000000 + r.nextInt(59999999)}', 'Coimbatore', 5000000, t0 - i, t0 - i, dev]);
  }
  cs.close();
  raw.execute('COMMIT');

  // 2. the bills, lines, movements and the credit entries, in big transactions
  const days = 5 * 365;
  final dayMs = const Duration(days: 1).inMilliseconds;
  final startMs = t0 - days * dayMs;
  String dayText(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  final bs = raw.prepare('INSERT INTO bills(id, number, series, seq, billed_at, day, customer_id, customer_name, total_paise, received_paise, balance_paise, taxable_paise, cgst_paise, sgst_paise, pay_mode, item_count, idem_key, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
  final ls = raw.prepare('INSERT INTO bill_lines(id, bill_id, line_no, product_id, name, unit, qty_milli, rate_paise, cost_paise, gst_bp, gross_paise, taxable_paise, tax_paise, total_paise) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
  final ms = raw.prepare('INSERT INTO stock_movements(id, product_id, qty_milli, kind, ref_id, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?)');
  final es = raw.prepare('INSERT INTO ledger_entries(id, party_kind, party_id, kind, amount_paise, at, bill_no, by_name, running_paise, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?,?)');
  final dues = raw.prepare('INSERT INTO party_bills(id, party_kind, party_id, bill_no, date, total_paise, paid_paise) VALUES (?,?,?,?,?,?,?)');
  final running = <String, int>{};
  const chunk = 25000;
  var done = 0;
  while (done < billCount) {
    raw.execute('BEGIN');
    for (var k = 0; k < chunk && done < billCount; k++, done++) {
      final seq = done + 1;
      final at = startMs + (done * days * dayMs ~/ billCount) + r.nextInt(60000);
      final id = newId();
      final n = 3 + r.nextInt(6);
      var total = 0;
      final lines = <List<Object?>>[];
      for (var j = 0; j < n; j++) {
        final pi = r.nextInt(productIds.length);
        final qty = 1000 * (1 + r.nextInt(4));
        final gross = prices[pi] * qty ~/ 1000;
        total += gross;
        lines.add([newId(), id, j + 1, productIds[pi], 'ITEM', 'pcs', qty, prices[pi], costs[pi], 1800, gross, gross * 100 ~/ 118, gross - gross * 100 ~/ 118, gross]);
        ms.execute([newId(), productIds[pi], -qty, 'sale', id, at, at, dev]);
      }
      final credit = r.nextInt(100) < 10;
      final cust = credit ? customerIds[r.nextInt(customerIds.length)] : null;
      final number = 'A-${seq.toString().padLeft(6, '0')}';
      final balance = credit ? total : 0;
      bs.execute([id, number, 'A', seq, at, dayText(at), cust, cust == null ? '' : 'CUSTOMER', total, credit ? 0 : total, balance, total * 100 ~/ 118, total * 9 ~/ 118, total * 9 ~/ 118, r.nextInt(3), n, 'perf-$seq', at, dev]);
      for (final l in lines) {
        ls.execute(l);
      }
      if (credit) {
        final run = (running[cust!] ?? 0) + total;
        running[cust] = run;
        es.execute([newId(), 'customer', cust, 'billCredit', total, at, number, 'perf', run, at, dev]);
        dues.execute(['$cust|$number', 'customer', cust, number, at, total, 0]);
      }
    }
    raw.execute('COMMIT');
    stdout.writeln('  inserted $done / $billCount bills');
  }
  for (final s in [bs, ls, ms, es, dues]) {
    s.close();
  }

  // 3. the summaries, from the rows (the same figures the app keeps up to date with each bill)
  stdout.writeln('  summaries...');
  raw.execute("INSERT INTO stock_movements(id, product_id, qty_milli, kind, at, created_at, device_id) SELECT 'open-' || id, id, 100000000, 'opening', 0, 0, 'dev-perf' FROM products");
  raw.execute("INSERT INTO stock_cache(product_id, qty_milli) SELECT product_id, SUM(qty_milli) FROM stock_movements GROUP BY product_id");
  raw.execute("INSERT INTO day_totals(day, bills, sales_paise, taxable_paise, tax_paise, cash_paise, credit_paise) SELECT day, COUNT(*), SUM(total_paise), SUM(taxable_paise), SUM(cgst_paise + sgst_paise), SUM(CASE WHEN balance_paise = 0 THEN total_paise ELSE 0 END), SUM(balance_paise) FROM $_bills GROUP BY day");
  raw.execute("INSERT INTO product_month(product_id, month, qty_milli, amount_paise) SELECT l.product_id, substr(b.day, 1, 7), SUM(l.qty_milli), SUM(l.total_paise) FROM bill_lines l JOIN bills b ON b.id = l.bill_id GROUP BY l.product_id, substr(b.day, 1, 7)");
  raw.execute("INSERT INTO party_balance(party_id, party_kind, balance_paise, last_bill_at, entry_count) SELECT party_id, 'customer', SUM(amount_paise), MAX(at), COUNT(*) FROM ledger_entries GROUP BY party_id");
  raw.execute("INSERT INTO counters(name, value) VALUES ('inv.A', $billCount)");
  raw.execute('ANALYZE');
  raw.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  raw.close();
}
