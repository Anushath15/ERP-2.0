import 'dart:convert';
import 'package:web/web.dart' as web;
import 'device_store.dart';

DeviceStore createPlatformStore(DeviceStore Function() fallback) => _WebStore();

class _WebStore implements DeviceStore {
  static const _key = 'senthil_erp2_device';

  @override
  Map<String, Object?> load() {
    try {
      final s = web.window.localStorage.getItem(_key);
      if (s == null || s.length > 64 * 1024) return {}; // settings are tiny; anything bigger is not ours
      final j = jsonDecode(s);
      return j is Map ? j.cast<String, Object?>() : {};
    } catch (_) {
      return {};
    }
  }

  @override
  void save(Map<String, Object?> data) {
    try {
      web.window.localStorage.setItem(_key, jsonEncode(data));
    } catch (_) {}
  }
}
