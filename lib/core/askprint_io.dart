import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Prints [bytes] (a PDF) with `askprint.exe` beside the program: the way modern Windows apps print (print ticket + XPS pipeline), which works with printers
/// whose "V4" driver refuses a direct job. Returns null when the helper is not there or this is not Windows (the caller then uses its own way), otherwise
/// true when the printer took the job and false when the helper reported a failure.
Future<bool?> printWithHelper(Uint8List bytes, {required String printerName}) async {
  if (!Platform.isWindows) return null;
  final exe = File('${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}askprint.exe');
  if (!exe.existsSync()) return null;
  final tmp = File('${Directory.systemTemp.path}${Platform.pathSeparator}askerp-print-${DateTime.now().microsecondsSinceEpoch}.pdf');
  try {
    await tmp.writeAsBytes(bytes, flush: true);
    final p = await Process.start(exe.path, [tmp.path, if (printerName.isNotEmpty) printerName]);
    unawaited(p.stdout.drain<void>());
    unawaited(p.stderr.drain<void>());
    final code = await p.exitCode.timeout(const Duration(seconds: 120), onTimeout: () {
      p.kill(); // never leave a stuck helper behind
      return -1;
    });
    return code == 0;
  } catch (_) {
    return false;
  } finally {
    try {
      if (tmp.existsSync()) tmp.deleteSync();
    } catch (_) {}
  }
}
