import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'file_saver.dart';
import 'safe_name.dart';

FileSaver createSaver() => _WebSaver();

class _WebSaver implements FileSaver {
  @override
  Future<String?> save(String fileName, Uint8List bytes) async {
    try {
      final name = safeFileName(fileName);
      final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));
      final url = web.URL.createObjectURL(blob);
      final a = web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = name;
      a.click();
      web.URL.revokeObjectURL(url);
      return name;
    } catch (_) {
      return null;
    }
  }
}
