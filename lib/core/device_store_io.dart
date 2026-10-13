import 'dart:convert';
import 'dart:io';
import 'device_store.dart';

/// Settings in a small JSON file in the user's own data folder (not in the install folder, never synced).
DeviceStore createPlatformStore(DeviceStore Function() fallback) {
  final dir = _dir();
  if (dir == null) return fallback();
  return _FileStore(File('$dir${Platform.pathSeparator}device.json'));
}

String? _dir() {
  final env = Platform.environment;
  if (Platform.isWindows && env['APPDATA'] != null) return '${env['APPDATA']}\\SenthilERP2';
  if (Platform.isMacOS && env['HOME'] != null) return '${env['HOME']}/Library/Application Support/SenthilERP2';
  if (Platform.isLinux && env['HOME'] != null) return '${env['HOME']}/.config/SenthilERP2';
  return null; // phones: the real per-device settings table arrives with the database (Phase 2)
}

class _FileStore implements DeviceStore {
  _FileStore(this.file);
  final File file;

  @override
  Map<String, Object?> load() {
    try {
      if (!file.existsSync()) return {};
      final j = jsonDecode(file.readAsStringSync());
      return j is Map ? j.cast<String, Object?>() : {};
    } catch (_) {
      return {}; // a damaged settings file must never stop the app: start with defaults
    }
  }

  @override
  void save(Map<String, Object?> data) {
    try {
      file.parent.createSync(recursive: true);
      final tmp = File('${file.path}.tmp');
      tmp.writeAsStringSync(jsonEncode(data), flush: true);
      tmp.renameSync(file.path);
    } catch (_) {
      // not saving settings is not worth a crash
    }
  }
}
