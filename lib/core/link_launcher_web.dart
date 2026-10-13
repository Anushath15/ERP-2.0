import 'package:web/web.dart' as web;
import '../domain/credit/reminder.dart';
import 'link_launcher.dart';

LinkLauncher createLauncher() => _WebLauncher();

class _WebLauncher implements LinkLauncher {
  @override
  LinkPlatform get platform => LinkPlatform.web;

  @override
  Future<bool> open(String url) async {
    if (!url.startsWith('http')) return false; // browsers cannot open whatsapp: links reliably; wa.me is used instead
    web.window.open(url, '_blank');
    return true;
  }
}
