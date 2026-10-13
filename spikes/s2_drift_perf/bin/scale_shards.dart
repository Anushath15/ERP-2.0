// Follow-up to scale1m.dart: archiving a year INSIDE the big database (delete + vacuum) takes the write lock for about 1.6 s per
// step, which would break the 100 ms "save bill" budget. This tests the alternative: one database FILE per year for bills, bill
// lines and stock movements ("year shards"). A finished year is copied out in order (sequential reads and writes into a
// separate file, so the live database is never locked), and old years are attached only when someone looks at them.
//
//   dart run bin/scale_shards.dart D:\erp2-scale\scale1m.sqlite
import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

final results = <String, Object>{};

double ms(Stopwatch s) => s.elapsedMicroseconds / 1000.0;

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : 'D:\\erp2-scale\\scale1m.sqlite';
  final dir = File(path).parent.path;
  final shardPath = '$dir${Platform.pathSeparator}shard-2023.sqlite';
  for (final s in ['', '-wal', '-shm', '-journal']) {
    final f = File('$shardPath$s');
    if (f.existsSync()) f.deleteSync();
  }
  final db = sqlite3.open(path);
  db.execute('PRAGMA cache_size = -32768');
  db.execute('PRAGMA mmap_size = 0');
  db.execute("ATTACH DATABASE '${shardPath.replaceAll("'", "''")}' AS s");
  db.execute('PRAGMA s.journal_mode = WAL');
  db.execute('PRAGMA s.synchronous = NORMAL');

  final a = DateTime(2023, 10, 14).millisecondsSinceEpoch, b = DateTime(2024, 10, 14).millisecondsSinceEpoch;
  db.execute('CREATE TABLE s.bills AS SELECT * FROM main.bills WHERE 0');
  db.execute('CREATE TABLE s.bill_lines AS SELECT * FROM main.bill_lines WHERE 0');
  db.execute('CREATE TABLE s.stock_movements AS SELECT * FROM main.stock_movements WHERE 0');

  // bills, lines and movements were written in time order, so their row numbers run in time order too: copy by row-number ranges
  final rows = db.select('SELECT rowid r FROM bills WHERE billed_at >= ? AND billed_at < ? ORDER BY rowid', [a, b]).map((r) => r['r'] as int).toList();
  final ids = rows;
  stdout.writeln('copying ${rows.length} bills of one year into a separate file, 2,000 bills per step (the live database only READS)');
  final steps = <double>[];
  final total = Stopwatch()..start();
  for (var i = 0; i < ids.length; i += 2000) {
    final r1 = rows[i], r2 = rows[(i + 2000 < rows.length ? i + 2000 : rows.length) - 1];
    final id1 = db.select('SELECT id FROM bills WHERE rowid = ?', [r1]).first['id'], id2 = db.select('SELECT id FROM bills WHERE rowid = ?', [r2]).first['id'];
    final l1 = db.select('SELECT MIN(rowid) m FROM bill_lines WHERE bill_id = ?', [id1]).first['m'], l2 = db.select('SELECT MAX(rowid) m FROM bill_lines WHERE bill_id = ?', [id2]).first['m'];
    final m1 = db.select('SELECT MIN(rowid) m FROM stock_movements WHERE ref_id = ?', [id1]).first['m'], m2 = db.select('SELECT MAX(rowid) m FROM stock_movements WHERE ref_id = ?', [id2]).first['m'];
    final t = Stopwatch()..start();
    db.execute('BEGIN');
    db.execute('INSERT INTO s.bills SELECT * FROM main.bills WHERE rowid BETWEEN ? AND ?', [r1, r2]);
    db.execute('INSERT INTO s.bill_lines SELECT * FROM main.bill_lines WHERE rowid BETWEEN ? AND ?', [l1, l2]);
    db.execute('INSERT INTO s.stock_movements SELECT * FROM main.stock_movements WHERE rowid BETWEEN ? AND ?', [m1, m2]);
    db.execute('COMMIT');
    steps.add(ms(t));
  }
  steps.sort();
  results['copySeconds'] = double.parse((total.elapsedMilliseconds / 1000).toStringAsFixed(1));
  results['copyStepP50Ms'] = double.parse(steps[steps.length ~/ 2].toStringAsFixed(1));
  results['copyStepMaxMs'] = double.parse(steps.last.toStringAsFixed(1));
  stdout.writeln('  copied in ${total.elapsed.inSeconds} s; one step p50=${steps[steps.length ~/ 2].toStringAsFixed(0)} ms, max=${steps.last.toStringAsFixed(0)} ms');

  final idx = Stopwatch()..start();
  for (final sql in [
    'CREATE UNIQUE INDEX s.sh_bills_id ON bills(id)',
    'CREATE UNIQUE INDEX s.sh_bills_number ON bills(number)',
    'CREATE INDEX s.sh_bills_at ON bills(billed_at DESC, id DESC)',
    'CREATE INDEX s.sh_bills_cust ON bills(customer_id, billed_at DESC, id DESC) WHERE customer_id IS NOT NULL',
    'CREATE UNIQUE INDEX s.sh_lines_id ON bill_lines(id)',
    'CREATE INDEX s.sh_lines_bill ON bill_lines(bill_id)',
    'CREATE INDEX s.sh_lines_prod ON bill_lines(product_id, bill_id)',
    'CREATE INDEX s.sh_mov_prod ON stock_movements(product_id, at)',
  ]) {
    db.execute(sql);
  }
  results['indexSeconds'] = double.parse((idx.elapsedMilliseconds / 1000).toStringAsFixed(1));
  stdout.writeln('  indexes built in ${idx.elapsed.inSeconds} s (done once, in the new file, not in the live database)');
  db.execute('PRAGMA s.wal_checkpoint(TRUNCATE)');
  results['shardBytes'] = File(shardPath).lengthSync();
  stdout.writeln('  year file: ${(File(shardPath).lengthSync() / 1048576).toStringAsFixed(0)} MB for ${ids.length} bills = ${(File(shardPath).lengthSync() / ids.length).round()} bytes per bill');

  // queries that cross the live database and the attached year file
  List<double> timed(int n, void Function(int) f) {
    final out = <double>[];
    for (var i = 0; i < n; i++) {
      final t = Stopwatch()..start();
      f(i);
      out.add(ms(t));
    }
    out.sort();
    return out;
  }

  void report(String name, List<double> v, double budget) {
    final p50 = v[v.length ~/ 2], p95 = v[(v.length * 0.95).floor().clamp(0, v.length - 1)];
    results[name] = {'p50Ms': p50, 'p95Ms': p95, 'maxMs': v.last, 'budgetMs': budget, 'pass': p95 <= budget};
    stdout.writeln('${p95 <= budget ? 'OK  ' : 'SLOW'} $name: p50=${p50.toStringAsFixed(2)} p95=${p95.toStringAsFixed(2)} max=${v.last.toStringAsFixed(2)} ms (budget $budget)');
  }

  final cursor = db.select("SELECT billed_at, id FROM s.bills WHERE billed_at < ? ORDER BY billed_at DESC LIMIT 1 OFFSET 100", [b]).first;
  report('Year file: sales register page by cursor (attached file)', timed(100, (_) => db.select('SELECT id,number,billed_at,total_paise FROM s.bills WHERE (billed_at, id) < (?, ?) ORDER BY billed_at DESC, id DESC LIMIT 50', [cursor['billed_at'], cursor['id']])), 300);
  report('Year file: find a bill by number', timed(200, (i) => db.select('SELECT id,total_paise FROM s.bills WHERE number = ?', ['A-${(400000 + i * 977).toString().padLeft(7, '0')}'])), 50);
  report('Across live + year file: newest 50 bills by cursor (UNION ALL, merged)', timed(100, (_) => db.select('SELECT * FROM (SELECT id,number,billed_at FROM main.bills WHERE (billed_at, id) < (?, ?) ORDER BY billed_at DESC, id DESC LIMIT 50) UNION ALL SELECT * FROM (SELECT id,number,billed_at FROM s.bills WHERE (billed_at, id) < (?, ?) ORDER BY billed_at DESC, id DESC LIMIT 50) ORDER BY billed_at DESC LIMIT 50', [b, 'z', b, 'z'])), 300);
  report('Across live + year file: one customer newest 50 bills', timed(100, (i) {
    final c = db.select('SELECT customer_id FROM s.bills WHERE customer_id IS NOT NULL LIMIT 1 OFFSET ?', [i * 37]).first['customer_id'];
    db.select('SELECT * FROM (SELECT id,number,billed_at FROM main.bills WHERE customer_id = ? ORDER BY billed_at DESC, id DESC LIMIT 50) UNION ALL SELECT * FROM (SELECT id,number,billed_at FROM s.bills WHERE customer_id = ? ORDER BY billed_at DESC, id DESC LIMIT 50) ORDER BY billed_at DESC LIMIT 50', [c, c]);
  }), 300);
  final at = Stopwatch()..start();
  db.execute('DETACH DATABASE s');
  db.execute("ATTACH DATABASE '${shardPath.replaceAll("'", "''")}' AS s2");
  results['attachMs'] = double.parse(ms(at).toStringAsFixed(2));
  stdout.writeln('     attach an old year file when someone opens it: ${ms(at).toStringAsFixed(1)} ms');
  db.close();
  File('$dir${Platform.pathSeparator}scale-shards-results.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  stdout.writeln('written scale-shards-results.json');
}
