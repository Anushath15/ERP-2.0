import 'dart:io';
import 'reveal_file.dart';

FileRevealer createRevealer() => _Revealer();

class _Revealer implements FileRevealer {
  @override
  Future<void> reveal(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,$path'], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.start('open', ['-R', path], mode: ProcessStartMode.detached);
      }
    } catch (_) {
      // the file is saved anyway: the message says where
    }
  }
}
