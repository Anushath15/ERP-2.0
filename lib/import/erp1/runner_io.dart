import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '../../data/app_data.dart';
import '../../data/context.dart';
import '../../data/db/open.dart';
import '../../data/importer/erp1_writer.dart';
import '../../data/repo/self_check.dart';
import 'outcome.dart';
import 'plan.dart';
import 'preview.dart';

const bool importSupported = true;

/// Reads and checks the backup text away from the screen (a big file takes seconds), so the app never freezes.
Future<ImportPreview> previewInBackground(String text, String fileName) => Isolate.run(() => previewFromText(text, fileName));

/// Writes a NEW database file from the backup, in its own isolate, reporting the stage it is in ('reading', 'writing', 'checking').
/// The file must not exist yet; if anything fails the half-made file is removed. The live database is never touched here.
Future<ImportOutcome> writeNewShopFile({required String text, required String fileName, required String outPath, void Function(String stage)? onStage}) async {
  if (File(outPath).existsSync()) return ImportOutcome.failed('The new data file already exists. Nothing was changed.');
  final port = ReceivePort();
  final done = Completer<ImportOutcome>();
  final sub = port.listen((m) {
    if (m is String) {
      onStage?.call(m);
    } else if (m is ImportOutcome && !done.isCompleted) {
      done.complete(m);
    }
  });
  try {
    await Isolate.spawn(_worker, [port.sendPort, text, outPath]);
    return await done.future;
  } catch (e) {
    return ImportOutcome.failed('The import could not be started ($e). Nothing was changed.');
  } finally {
    await sub.cancel();
    port.close();
  }
}

Future<void> _worker(List<Object> args) async {
  final send = args[0] as SendPort;
  final text = args[1] as String;
  final out = args[2] as String;
  final sw = Stopwatch()..start();
  void cleanup() {
    for (final s in ['', '-wal', '-shm', '-journal']) {
      final f = File('$out$s');
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  try {
    send.send('reading');
    final plan = Erp1Plan.parse(text);
    send.send('writing');
    final db = await openShopDatabase(out);
    final d = AppData(DataContext(db: db, deviceId: 'import'));
    final res = await writePlan(d, plan, nowMs: DateTime.now().millisecondsSinceEpoch);
    send.send('checking');
    final integ = await sqliteIntegrity(db, full: true);
    final problems = await selfCheck(db);
    final counts = await shopCounts(d);
    await db.close();
    send.send(ImportOutcome(
      ok: true,
      newFile: out,
      verified: res.verified,
      mismatches: res.mismatches,
      selfCheckProblems: [for (final p in problems) '$p'],
      integrity: integ.isEmpty ? 'ok' : integ.join('; '),
      counts: counts,
      millis: sw.elapsedMilliseconds,
    ));
  } on ImportInputError catch (e) {
    cleanup();
    send.send(ImportOutcome.failed(e.message));
  } catch (e) {
    cleanup();
    send.send(ImportOutcome.failed('The import failed and the new file was removed. Nothing else was changed. ($e)'));
  }
}
