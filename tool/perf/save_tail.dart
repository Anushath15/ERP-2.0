// Why does one save in a few hundred take far longer than the rest? Measures N bill saves on the big test file and, for every save, whether the main
// database file was written during it (= a WAL checkpoint ran inside that save), the WAL size, and the latency. Compares ways of running checkpoints.
//
//   dart run tool/perf/save_tail.dart [saves=2000] [mode=default|off|every:N|idle:N] [file=build/perf_scale.sqlite]
//
// default  SQLite's automatic checkpoint (every 1000 WAL pages, inside the commit that crosses the limit)
// off      no checkpoint at all while measuring (shows what the saves cost without it; the WAL grows)
// prod     the program's controlled checkpoints with a very short idle time (12 ms gaps)
// real     the program's real policy (300 ms quiet, 500 ms tick), 350 ms gap between saves
// every:N  automatic checkpoint off; PASSIVE checkpoint after every N saves, run by the program between saves (the "idle moment")
import 'dart:io';
import 'dart:math';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/app_database.dart';
import 'package:erp2/data/db/open.dart';
import 'package:erp2/data/ids.dart';
import 'package:erp2/data/repo/bill_repo.dart';

Future<void> main(List<String> args) async {
  final n = args.isNotEmpty ? int.parse(args[0]) : 2000;
  final mode = args.length > 1 ? args[1] : 'default';
  final path = args.length > 2 ? args[2] : 'build/perf_scale.sqlite';
  // mode 'prod' = the program's real behaviour: controlled checkpoints in quiet moments (a 3 ms pause between saves stands in for the people-speed gaps)
  final db = await openShopDatabase(path, checkpoints: mode == 'real' ? const CheckpointPolicy() : (mode == 'prod' ? const CheckpointPolicy(commitsBetween: 15, idleMs: 2, tickMs: 5) : null));
  final d = AppData(DataContext(db: db, deviceId: 'dev-perf'));
  d.bills.series = 'A';
  final products = (await d.catalog.products()).take(2000).toList();
  final customers = (await d.catalog.customers()).take(200).toList();
  if (mode != 'default' && mode != 'prod' && mode != 'real') await db.customStatement('PRAGMA wal_autocheckpoint = 0');
  if (args.length > 3) await db.customStatement('PRAGMA cache_size = -${args[3]}'); // KB of page cache, to test whether the slow saves are cold page reads
  if (args.length > 4) await db.customStatement('PRAGMA synchronous = ${args[4]}'); // test only: NORMAL/OFF show whether the slow saves are waiting for the disk flush
  final every = mode.startsWith('every:') ? int.parse(mode.substring(6)) : 0;
  final main = File(path), wal = File('$path-wal');
  final r = Random(5);
  final lat = <double>[];
  final rows = <(double, bool, int, int)>[];
  var lastMain = main.lastModifiedSync();
  var ckptMs = <double>[];
  for (var i = 0; i < n; i++) {
    final lines = [
      for (var k = 0; k < 1 + r.nextInt(8); k++)
        () {
          final p = products[r.nextInt(products.length)];
          return BillLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: 1000 * (1 + r.nextInt(4)), ratePaise: p.pricePaise, gstBp: p.gstBp, costPaise: p.costPaise);
        }(),
    ];
    final credit = i % 5 == 0;
    final c = customers[r.nextInt(customers.length)];
    final sw = Stopwatch()..start();
    await d.bills.saveBill(SaveBillInput(idemKey: 'tail-$i-${newId()}', at: DateTime.now(), lines: lines, customerId: credit ? c.id : null, customerName: credit ? c.name : '', receivedPaise: credit ? 0 : null));
    final ms = sw.elapsedMicroseconds / 1000.0;
    if (mode == 'prod') await Future<void>.delayed(const Duration(milliseconds: 12));
    if (mode == 'real') await Future<void>.delayed(const Duration(milliseconds: 350)); // the real policy (300 ms quiet, 500 ms tick) with a person-speed gap
    final gap = int.tryParse(Platform.environment['SAVE_GAP_MS'] ?? '') ?? 0; // any mode: wait this long between saves (an idle disk may flush slower)
    if (gap > 0) await Future<void>.delayed(Duration(milliseconds: gap));
    final m = main.lastModifiedSync();
    final wrote = m != lastMain;
    lastMain = m;
    lat.add(ms);
    rows.add((ms, wrote, wal.existsSync() ? wal.lengthSync() : 0, i));
    if (every > 0 && (i + 1) % every == 0) {
      final cs = Stopwatch()..start();
      await db.customSelect('PRAGMA wal_checkpoint(PASSIVE)').get();
      ckptMs.add(cs.elapsedMicroseconds / 1000.0);
      lastMain = main.lastModifiedSync();
    }
  }
  double q(List<double> v, double p) {
    final s = [...v]..sort();
    return s[min(s.length - 1, (s.length * p).floor())];
  }

  stdout.writeln('mode=$mode saves=$n  p50=${q(lat, .5).toStringAsFixed(1)} p95=${q(lat, .95).toStringAsFixed(1)} p99=${q(lat, .99).toStringAsFixed(1)} p99.9=${q(lat, .999).toStringAsFixed(1)} max=${q(lat, 1).toStringAsFixed(1)} ms');
  final slow = rows.where((x) => x.$1 > 50).toList();
  stdout.writeln('saves over 50 ms: ${slow.length}; of those, the main file was written during the save in ${slow.where((x) => x.$2).length}');
  final withWrite = rows.where((x) => x.$2).map((x) => x.$1).toList();
  final without = rows.where((x) => !x.$2).map((x) => x.$1).toList();
  stdout.writeln('saves during which the main file was written (checkpoint inside the save): ${withWrite.length}${withWrite.isEmpty ? '' : '  p50=${q(withWrite, .5).toStringAsFixed(1)} max=${q(withWrite, 1).toStringAsFixed(1)} ms'}');
  stdout.writeln('saves without: ${without.length}  p50=${q(without, .5).toStringAsFixed(1)} p99=${q(without, .99).toStringAsFixed(1)} max=${q(without, 1).toStringAsFixed(1)} ms');
  if (ckptMs.isNotEmpty) stdout.writeln('controlled checkpoints between saves: ${ckptMs.length}  p50=${q(ckptMs, .5).toStringAsFixed(1)} p95=${q(ckptMs, .95).toStringAsFixed(1)} max=${q(ckptMs, 1).toStringAsFixed(1)} ms (done while no save is waiting)');
  final top = [...rows]..sort((a, b) => b.$1.compareTo(a.$1));
  for (final x in top.take(8)) {
    stdout.writeln('  slowest: save #${x.$4} ${x.$1.toStringAsFixed(1)} ms  main-file-written=${x.$2}  wal=${(x.$3 / 1024).round()} KB');
  }
  if (mode == 'prod' || mode == 'real') stdout.writeln('controlled checkpoints run by the program: ${db.controlledCheckpoints}');
  await db.close();
}
