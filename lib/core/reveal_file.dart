import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reveal_file_stub.dart' if (dart.library.io) 'reveal_file_io.dart' as impl;

/// Shows a saved file in its folder (Windows: the folder opens with the file selected), so a person can drag it into WhatsApp. Does nothing where that is
/// not possible (a browser). Never throws.
abstract class FileRevealer {
  Future<void> reveal(String path);
}

final fileRevealerProvider = Provider<FileRevealer>((ref) => impl.createRevealer());
