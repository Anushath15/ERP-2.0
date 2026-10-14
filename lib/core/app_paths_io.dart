import 'dart:io';
import 'app_paths.dart';

/// Windows: `%LOCALAPPDATA%\ASK ERP 2.0` (local to this computer, never the roaming profile). macOS: Application Support. Linux: ~/.local/share.
AppPaths createAppPaths() {
  final env = Platform.environment;
  String? base;
  if (Platform.isWindows && env['LOCALAPPDATA'] != null) base = '${env['LOCALAPPDATA']}\\ASK ERP 2.0';
  if (Platform.isMacOS && env['HOME'] != null) base = '${env['HOME']}/Library/Application Support/ASK ERP 2.0';
  if (Platform.isLinux && env['HOME'] != null) base = '${env['HOME']}/.local/share/ASK ERP 2.0';
  if (base == null) throw UnsupportedError('Phone storage arrives with the Android build');
  return FileAppPaths(base);
}

class FileAppPaths implements AppPaths {
  FileAppPaths(this.base);
  final String base;

  @override
  String get dataDir => '$base${Platform.pathSeparator}data';

  @override
  String dbLocation(String name) => '$dataDir${Platform.pathSeparator}$name.sqlite';

  File _file(String name) => File('$base${Platform.pathSeparator}$name');

  @override
  Future<String?> readText(String name) async {
    try {
      final f = _file(name);
      if (!f.existsSync() || f.lengthSync() > 4096) return null; // these files are a few bytes
      return (await f.readAsString()).trim();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeText(String name, String text) async {
    final f = _file(name);
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(f.path);
  }
}
