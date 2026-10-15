// The power-cut test: start the bill writer, kill it at a random moment, open the database again and check it. Repeat.
// A killed process cannot finish a transaction, so what is left on disk is what a power cut leaves behind as far as a program
// can simulate it. (A real power cut can also lose data the operating system had not written yet; SQLite's synchronous=FULL setting
// is what protects against that, and it is on. That part cannot be tested without pulling a plug.)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/open.dart';
import 'package:erp2/data/repo/self_check.dart';

class KillRunResult {
  KillRunResult({required this.runs, required this.problems, required this.billsAtEnd, required this.acknowledged, required this.killedMidTransactionLikely});
  final int runs;
  final List<String> problems;
  final int billsAtEnd;
  final int acknowledged;
  final int killedMidTransactionLikely;
  bool get ok => problems.isEmpty;
}

/// Builds the writer program with its sqlite library (a plain `dart compile exe` leaves the library out). Returns the exe path.
Future<String> buildWriter(String projectDir) async {
  final out = '$projectDir/build/killbundle';
  final exe = File('$out/bundle/bin/writer.exe');
  final exeUnix = File('$out/bundle/bin/writer');
  // rebuild when any source is newer than the built writer (a stale writer from an older schema made every run wait 30 s)
  final built = exe.existsSync() ? exe : (exeUnix.existsSync() ? exeUnix : null);
  if (built != null) {
    final builtAt = built.lastModifiedSync();
    final stale = [for (final d in ['lib', 'tool/kill_test']) ...Directory('$projectDir/$d').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))].any((f) => f.lastModifiedSync().isAfter(builtAt));
    if (!stale) return built.path;
  }
  final r = await Process.run('dart', ['build', 'cli', '-t', 'tool/kill_test/writer.dart', '-o', out], workingDirectory: projectDir, runInShell: true);
  if (r.exitCode != 0) throw StateError('Could not build the writer: ${r.stdout}${r.stderr}');
  return exe.existsSync() ? exe.path : exeUnix.path;
}

Future<KillRunResult> killTest({required String projectDir, required String dbPath, required int runs, int seed = 1, void Function(String)? log}) async {
  final exe = await buildWriter(projectDir);
  for (final s in ['', '-wal', '-shm']) {
    final f = File('$dbPath$s');
    if (f.existsSync()) f.deleteSync();
  }
  final rnd = Random(seed);
  final problems = <String>[];
  var acknowledged = 0;
  var midTransaction = 0;
  for (var i = 1; i <= runs; i++) {
    final p = await Process.start(exe, [dbPath, '${seed * 1000 + i}']);
    var ready = false;
    var lastOk = 0;
    final done = Completer<void>();
    final sub = p.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line == 'READY') ready = true;
      if (line.startsWith('OK ')) lastOk = int.parse(line.substring(3));
    }, onDone: () {
      if (!done.isCompleted) done.complete();
    });
    unawaited(p.stderr.drain<void>());
    // wait for the program to be saving, then kill it a random moment later
    final start = DateTime.now();
    while (!ready && DateTime.now().difference(start).inSeconds < 30) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(Duration(milliseconds: 5 + rnd.nextInt(700)));
    p.kill(ProcessSignal.sigkill);
    await p.exitCode;
    await sub.cancel();
    acknowledged = max(acknowledged, lastOk);

    final db = await openShopDatabase(dbPath);
    try {
      final integrity = await sqliteIntegrity(db, full: true);
      if (integrity.isNotEmpty) problems.add('run $i: integrity_check says $integrity');
      for (final x in await selfCheck(db, deep: true)) {
        problems.add('run $i: $x');
      }
      final bills = await db.scalarInt('SELECT COUNT(*) FROM bills');
      if (bills < lastOk) problems.add('run $i: the program was told $lastOk bills were saved but only $bills exist');
      // a transaction was cut in half when the WAL held an uncommitted tail; we count runs where the number of bills is not what
      // the last acknowledgement says (the next bill was in flight)
      if (bills > lastOk) midTransaction++;
      log?.call('run $i: killed after $lastOk acknowledged bills, $bills bills in the file, ${problems.isEmpty ? 'all checks pass' : 'PROBLEMS'}');
    } finally {
      await db.close();
    }
  }
  final db = await openShopDatabase(dbPath);
  final total = await db.scalarInt('SELECT COUNT(*) FROM bills');
  await db.close();
  return KillRunResult(runs: runs, problems: problems, billsAtEnd: total, acknowledged: acknowledged, killedMidTransactionLikely: midTransaction);
}
