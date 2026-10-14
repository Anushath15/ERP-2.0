// dart run tool/kill_test/run.dart [runs] [database file]
import 'dart:io';
import 'driver.dart';

Future<void> main(List<String> args) async {
  final runs = args.isNotEmpty ? int.parse(args[0]) : 200;
  final db = args.length > 1 ? args[1] : '${Directory.systemTemp.path}/erp2_kill_test.sqlite';
  final r = await killTest(projectDir: Directory.current.path, dbPath: db, runs: runs, log: stdout.writeln);
  stdout.writeln('${r.runs} kills, ${r.billsAtEnd} bills in the file, ${r.problems.length} problems');
  for (final p in r.problems) {
    stdout.writeln(p);
  }
  exit(r.ok ? 0 : 1);
}
