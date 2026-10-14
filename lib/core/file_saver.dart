import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'file_saver_stub.dart'
    if (dart.library.io) 'file_saver_io.dart'
    if (dart.library.js_interop) 'file_saver_web.dart' as impl;

/// Saves a file the person asked for (a PDF). Windows/macOS/Linux/Android: into one fixed folder (Downloads/ASK ERP 2.0), returns the full path.
/// Browser: starts a normal download, returns the file name. Returns null when it could not be saved.
abstract class FileSaver {
  Future<String?> save(String fileName, Uint8List bytes);
}

final fileSaverProvider = Provider<FileSaver>((ref) => impl.createSaver());
