import 'package:web/web.dart' as web;
import 'app_paths.dart';

AppPaths createAppPaths() => _WebPaths();

class _WebPaths implements AppPaths {
  @override
  String get dataDir => '';

  @override
  String? get defaultBackupFolder => null;

  @override
  String dbLocation(String name) => 'ask_erp2_$name';

  @override
  Future<String?> readText(String name) async {
    try {
      final s = web.window.localStorage.getItem('ask_erp2_$name');
      return s == null || s.length > 4096 ? null : s.trim();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeText(String name, String text) async {
    web.window.localStorage.setItem('ask_erp2_$name', text);
  }
}
