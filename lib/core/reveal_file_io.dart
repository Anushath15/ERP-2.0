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

  @override
  Future<bool> copyFile(String path) async {
    if (!Platform.isWindows) return false;
    try {
      // the file goes on the clipboard the way Explorer's Copy puts it there, so Ctrl+V in a WhatsApp chat attaches it. The path travels in an
      // environment variable, never inside the command text.
      final r = await Process.run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', r'Set-Clipboard -LiteralPath $env:ASK_ERP_FILE'], environment: {'ASK_ERP_FILE': path}).timeout(const Duration(seconds: 15));
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
