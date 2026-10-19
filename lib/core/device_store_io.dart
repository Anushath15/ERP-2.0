import 'dart:convert';
import 'dart:io';
import 'app_paths_io.dart' show phoneBaseDir;
import 'device_store.dart';

/// Settings in a small JSON file in the user's own data folder (not in the install folder, never synced).
DeviceStore createPlatformStore(DeviceStore Function() fallback) {
  final dir = _dir();
  if (dir == null) return fallback();
  return FileDeviceStore(File('$dir${Platform.pathSeparator}device.json'));
}

String? _dir() {
  final env = Platform.environment;
  if (Platform.isWindows && env['APPDATA'] != null) return '${env['APPDATA']}\\SenthilERP2';
  if (Platform.isMacOS && env['HOME'] != null) return '${env['HOME']}/Library/Application Support/SenthilERP2';
  if (Platform.isLinux && env['HOME'] != null) return '${env['HOME']}/.config/SenthilERP2';
  final phone = phoneBaseDir();
  return phone == null ? null : '$phone${Platform.pathSeparator}settings'; // phones: the app's own private folder
}

/// SECURITY: this file holds display preferences only and can be edited by anybody at the computer. It is read defensively: a missing,
/// damaged, wrong-shaped, binary or enormous file means "defaults", never a crash, and nothing in it is ever trusted for permissions.
class FileDeviceStore implements DeviceStore {
  FileDeviceStore(this.file);
  final File file;

  /// A settings file is a few hundred bytes; anything bigger than this is not ours.
  static const maxBytes = 64 * 1024;

  @override
  Map<String, Object?> load() {
    try {
      if (!file.existsSync() || file.lengthSync() > maxBytes) return {};
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
