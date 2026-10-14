import 'dart:io';
import 'dart:typed_data';
import 'file_saver.dart';
import 'safe_name.dart';

FileSaver createSaver() => IoFileSaver();

/// Saves into ONE fixed folder (Downloads/ASK ERP 2.0, or [folder] in tests). The name is cleaned by [safeFileName], the final path
/// is checked to be inside the folder, and a file is never overwritten: a second file with the same name gets a number.
class IoFileSaver implements FileSaver {
  IoFileSaver({this.folder});
  final String? folder;

  String? _folder() {
    if (folder != null) return folder;
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home == null) return null;
    return '$home${Platform.pathSeparator}Downloads${Platform.pathSeparator}ASK ERP 2.0';
  }

  @override
  Future<String?> save(String fileName, Uint8List bytes) async {
    try {
      final dirPath = _folder();
      if (dirPath == null) return null;
      final dir = Directory(dirPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final clean = safeFileName(fileName);
      final dot = clean.lastIndexOf('.');
      final stem = dot < 0 ? clean : clean.substring(0, dot), ext = dot < 0 ? '' : clean.substring(dot);
      var path = '${dir.path}${Platform.pathSeparator}$clean';
      for (var i = 2; File(path).existsSync(); i++) {
        path = '${dir.path}${Platform.pathSeparator}$stem ($i)$ext';
      }
      // belt and braces: whatever happened above, the file must land inside the folder
      if (!isInside(dir.absolute.path, File(path).absolute.path)) return null;
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } catch (_) {
      return null;
    }
  }
}
