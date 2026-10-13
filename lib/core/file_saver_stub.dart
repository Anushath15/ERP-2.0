import 'dart:typed_data';
import 'file_saver.dart';

FileSaver createSaver() => _NoSaver();

class _NoSaver implements FileSaver {
  @override
  Future<String?> save(String fileName, Uint8List bytes) async => null;
}
