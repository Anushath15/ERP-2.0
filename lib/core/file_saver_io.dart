import 'dart:io';
import 'dart:typed_data';
import 'file_saver.dart';

FileSaver createSaver() => _IoSaver();

class _IoSaver implements FileSaver {
  @override
  Future<String?> save(String fileName, Uint8List bytes) async {
    try {
      final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (home == null) return null;
      final dir = Directory('$home${Platform.pathSeparator}Downloads');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      var path = '${dir.path}${Platform.pathSeparator}$fileName';
      // never overwrite an earlier file: add a number instead
      final dot = fileName.lastIndexOf('.');
      final stem = dot < 0 ? fileName : fileName.substring(0, dot), ext = dot < 0 ? '' : fileName.substring(dot);
      for (var i = 2; File(path).existsSync(); i++) {
        path = '${dir.path}${Platform.pathSeparator}$stem ($i)$ext';
      }
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } catch (_) {
      return null;
    }
  }
}
