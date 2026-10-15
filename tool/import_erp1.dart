/// Imports a COPY of an ERP 1 backup into a NEW ERP 2.0 database. By default it is a DRY RUN: it reads and checks everything, writes nothing and
/// prints the reconciliation report.
///
///   dart run tool/import_erp1.dart `<backup.json>`                      dry run, report on screen
///   dart run tool/import_erp1.dart `<backup.json>` --report report.txt  also save the report
///   dart run tool/import_erp1.dart `<backup.json>` --write new.sqlite   write a NEW database file (must not exist yet)
///
/// Never point it at ERP 1's own data folder: give it a copy of the backup file. Exit code 0 = done, 2 = the file cannot be used, 1 = failed
/// (a half-written database file is deleted).
library;

import 'dart:io';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/open.dart';
import 'package:erp2/data/repo/self_check.dart';
import 'package:erp2/import/erp1/plan.dart';
import 'package:erp2/import/erp1/report.dart';
import 'package:erp2/data/importer/erp1_writer.dart';

const maxFileBytes = 1500 * 1024 * 1024;

Future<void> main(List<String> args) async {
  final pos = <String>[];
  String? reportPath, writePath;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--report' && i + 1 < args.length) {
      reportPath = args[++i];
    } else if (args[i] == '--write' && i + 1 < args.length) {
      writePath = args[++i];
    } else {
      pos.add(args[i]);
    }
  }
  if (pos.length != 1) {
    stderr.writeln('Usage: dart run tool/import_erp1.dart `<backup.json>` [--report file] [--write new.sqlite]');
    exit(2);
  }
  final file = File(pos[0]);
  if (!file.existsSync()) {
    stderr.writeln('The backup file was not found: ${pos[0]}');
    exit(2);
  }
  if (file.lengthSync() > maxFileBytes) {
    stderr.writeln('The backup file is larger than 1.5 GB; it is not an ERP 1 backup. Nothing was changed.');
    exit(2);
  }
  if (writePath != null && File(writePath).existsSync()) {
    stderr.writeln('$writePath already exists. The import writes only a NEW file, never a live database. Nothing was changed.');
    exit(2);
  }
  final sw = Stopwatch()..start();
  late Erp1Plan plan;
  try {
    plan = Erp1Plan.parse(file.readAsStringSync());
  } on ImportInputError catch (e) {
    stderr.writeln(e.message);
    exit(2);
  } on FileSystemException catch (e) {
    stderr.writeln('The backup file could not be read as text: ${e.message}. Nothing was changed.');
    exit(2);
  }
  final readMs = sw.elapsedMilliseconds;
  var text = buildReport(plan, fileName: file.uri.pathSegments.last, dryRun: writePath == null);
  if (writePath != null) {
    final out = File(writePath);
    try {
      final db = await openShopDatabase(out.path, background: false);
      final d = AppData(DataContext(db: db, deviceId: 'import'));
      final res = await writePlan(d, plan, nowMs: DateTime.now().millisecondsSinceEpoch);
      final problems = await selfCheck(db);
      await db.close();
      text += '\n== 8. Written\n  $writePath\n  Read back and compared with the backup: ${res.verified ? 'EVERY TOTAL AGREES' : 'MISMATCH'}\n  Consistency check of the new database by the program itself: ${problems.isEmpty ? 'no problems' : '${problems.length} problem(s): ${problems.take(5).join('; ')}'}\n';
      for (final m in res.mismatches) {
        text += '    $m\n';
      }
    } catch (e) {
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final f = File('${out.path}$suffix');
        if (f.existsSync()) f.deleteSync();
      }
      stderr.writeln('The import failed and the new file was removed. Nothing else was changed. Reason: $e');
      exit(1);
    }
  }
  text += '\n(read and checked in $readMs ms, total ${sw.elapsedMilliseconds} ms)\n';
  stdout.write(text);
  if (reportPath != null) File(reportPath).writeAsStringSync(text);
}
