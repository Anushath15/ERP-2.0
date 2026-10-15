// Same question as save_tail.dart, but for reads only: random cold lookups in the big file (no writes, no fsync). If rare 100+ ms reads
// show up here too, the slow saves are cold-page reads from disk (or a virus scanner looking at the file), not the commit itself.
//   dart run tool/perf/read_tail.dart [count=3000] [cacheKB=2000] [file=build/perf_scale.sqlite]
import 'dart:io';
import 'dart:math';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/open.dart';

Future<void> main(List<String> args) async {
  final n = args.isNotEmpty ? int.parse(args[0]) : 3000;
  final cache = args.length > 1 ? args[1] : '2000';
  final path = args.length > 2 ? args[2] : 'build/perf_scale.sqlite';
  final db = await openShopDatabase(path);
  await db.customStatement('PRAGMA cache_size = -$cache');
  final maxRow = await db.scalarInt('SELECT MAX(rowid) FROM bills');
  final r = Random(11);
  final lat = <double>[];
  for (var i = 0; i < n; i++) {
    final sw = Stopwatch()..start();
    final id = r.nextInt(maxRow) + 1;
    final b = await db.row('SELECT id, customer_id FROM bills WHERE rowid = ?', [id]);
    if (b != null) {
      await db.rows('SELECT * FROM bill_lines WHERE bill_id = ?', [b.read<String>('id')]);
      await db.rows('SELECT * FROM stock_movements WHERE ref_id = ? LIMIT 10', [b.read<String>('id')]);
    }
    lat.add(sw.elapsedMicroseconds / 1000.0);
  }
  final s = [...lat]..sort();
  double q(double p) => s[(s.length * p).floor().clamp(0, s.length - 1)];
  stdout.writeln('cold reads x $n (cache ${cache}KB): p50=${q(.5).toStringAsFixed(2)} p95=${q(.95).toStringAsFixed(2)} p99=${q(.99).toStringAsFixed(2)} p99.9=${q(.999).toStringAsFixed(1)} max=${s.last.toStringAsFixed(1)} ms; over 50 ms: ${s.where((x) => x > 50).length}');
  await db.close();
  exit(0);
}
