import 'dart:io';
import '../domain/credit/reminder.dart';
import 'android_bridge.dart';
import 'link_launcher.dart';

LinkLauncher createLauncher() => _IoLauncher();

class _IoLauncher implements LinkLauncher {
  @override
  LinkPlatform get platform => Platform.isWindows
      ? LinkPlatform.windows
      : Platform.isAndroid
          ? LinkPlatform.android
          : Platform.isMacOS
              ? LinkPlatform.macos
              : Platform.isIOS
                  ? LinkPlatform.ios
                  : LinkPlatform.linux;

  @override
  Future<bool> open(String url) async {
    // SECURITY: Windows' "open this" handler would also start a program or open a file if it were given a path; only web and WhatsApp links pass
    if (!RegExp(r'^(https://|http://|whatsapp://)[^\s"<>]+$').hasMatch(url)) return false;
    try {
      if (Platform.isWindows) {
        // The WhatsApp app registers the "whatsapp:" link type. If it is not registered, report false so the caller falls back to wa.me.
        if (url.startsWith('whatsapp:')) {
          final q = await Process.run('reg', ['query', r'HKCR\whatsapp']);
          if (q.exitCode != 0) return false;
        }
        final r = await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
        return r.exitCode == 0;
      }
      if (Platform.isMacOS) return (await Process.run('open', [url])).exitCode == 0;
      if (Platform.isLinux) return (await Process.run('xdg-open', [url])).exitCode == 0;
      if (Platform.isAndroid) return await const ChannelAndroidBridge().openUrl(url); // the program's own Android code (MainActivity.kt)
      return false; // iPhone: not made yet
    } catch (_) {
      return false;
    }
  }
}
