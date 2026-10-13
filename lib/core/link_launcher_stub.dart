import '../domain/credit/reminder.dart';
import 'link_launcher.dart';

LinkLauncher createLauncher() => _NoLauncher();

class _NoLauncher implements LinkLauncher {
  @override
  LinkPlatform get platform => LinkPlatform.linux;
  @override
  Future<bool> open(String url) async => false;
}
