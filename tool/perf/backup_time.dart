// How long do a backup, its check and a restore take on the big (about 4.5 GB, 1,000,000 bills) test database?
//   dart run tool/perf/backup_time.dart [file=build/perf_fresh.sqlite]
// Works in a temporary folder next to the file; the test database itself is only read.
import 'dart:io';
import 'package:erp2/data/backup/backup.dart';
import 'package:erp2/data/importer/swap.dart';
import 'package:path/path.dart' as p;

String mb(int b) => '${(b / (1024 * 1024)).round()} MB';

Future<void> main(List<String> args) async {
  final src = args.isNotEmpty ? args[0] : 'build/perf_fresh.sqlite';
  final work = Directory('build/backup_time_work')..createSync(recursive: true);
  final live = p.join(work.path, 'data', 'shop.sqlite');
  Directory(p.dirname(live)).createSync(recursive: true);
  stdout.writeln('database: ${mb(File(src).lengthSync())}');
  var sw = Stopwatch()..start();
  File(src).copySync(live);
  stdout.writeln('copied the test database into the work folder: ${sw.elapsed.inSeconds} s');
  sw = Stopwatch()..start();
  final info = await createBackup(livePath: live, folder: p.join(work.path, 'Backups'), deviceId: 'abcdef12', appVersion: '2.0.0-proto.3');
  stdout.writeln('BACKUP (snapshot + prepare + check + name): ${sw.elapsed.inSeconds} s, file ${mb(info.bytes)}');
  sw = Stopwatch()..start();
  final ins = await inspectBackup(info.path, expectedShopId: '');
  stdout.writeln('CHECK before restore (quick check, counts): ${sw.elapsed.inSeconds} s -> ${ins.problem.name}, ${ins.contents?.bills} bills');
  sw = Stopwatch()..start();
  await requestRestore(dataDir: p.dirname(live), backupFile: info.path, source: 'timing');
  final copyS = sw.elapsed.inSeconds;
  sw = Stopwatch()..start();
  final r = await applyPendingSwap(p.dirname(live));
  stdout.writeln('RESTORE: copy into the data folder $copyS s, then switch at start-up ${sw.elapsed.inSeconds} s -> ok=${r?.ok} ${r?.message}');
  work.deleteSync(recursive: true);
}
