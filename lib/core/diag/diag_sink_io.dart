import 'dart:io';
import 'diag_log.dart';

DiagSink createSink(String folder, int maxBytes) => _FileSink(folder, maxBytes);

/// `diag.log` in [folder], at most about 400 KB; when it is full it becomes `diag.old.log` (one older file is kept) and a new one starts.
class _FileSink implements DiagSink {
  _FileSink(String folder, this._maxBytes) : _file = File('$folder${Platform.pathSeparator}diag.log'), _old = File('$folder${Platform.pathSeparator}diag.old.log') {
    try {
      Directory(folder).createSync(recursive: true);
    } catch (_) {}
  }
  final File _file, _old;
  final int _maxBytes;

  @override
  void write(String line) {
    try {
      if (_file.existsSync() && _file.lengthSync() > _maxBytes) {
        if (_old.existsSync()) _old.deleteSync();
        _file.renameSync(_old.path);
      }
      _file.writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (_) {}
  }

  @override
  List<String> recent(int max) {
    try {
      final lines = <String>[];
      if (_old.existsSync()) lines.addAll(_old.readAsLinesSync());
      if (_file.existsSync()) lines.addAll(_file.readAsLinesSync());
      return lines.length <= max ? lines : lines.sublist(lines.length - max);
    } catch (_) {
      return const [];
    }
  }
}

/// What this computer is (for the diagnostics file).
Map<String, Object?> systemFacts() => {
      'system': Platform.operatingSystem,
      'system version': Platform.operatingSystemVersion,
      'processors': Platform.numberOfProcessors,
      'language': Platform.localeName,
    };
