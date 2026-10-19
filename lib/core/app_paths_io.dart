import 'dart:io';
import 'app_paths.dart';

/// Windows: `%LOCALAPPDATA%\ASK ERP 2.0` (local to this computer, never the roaming profile). macOS: Application Support. Linux: ~/.local/share.
AppPaths createAppPaths() {
  final env = Platform.environment;
  String? base;
  if (Platform.isWindows && env['LOCALAPPDATA'] != null) base = '${env['LOCALAPPDATA']}\\ASK ERP 2.0';
  if (Platform.isMacOS && env['HOME'] != null) base = '${env['HOME']}/Library/Application Support/ASK ERP 2.0';
  if (Platform.isLinux && env['HOME'] != null) base = '${env['HOME']}/.local/share/ASK ERP 2.0';
  base ??= phoneBaseDir();
  if (base == null) throw UnsupportedError('This computer has no folder the program can keep the shop data in');
  return FileAppPaths(base);
}

/// The program's own private folder on an Android phone or tablet (or an iPhone), found without a plugin: every app gets a cache folder
/// (`Directory.systemTemp`) that sits right beside its private "files" folder, so the folder one level up is the app's own home.
/// Nothing outside the app can open it, and it is wiped only when the app is uninstalled (so the shop keeps backups elsewhere too).
/// [android] and [tempPath] are for tests; the program uses the real values. Null on a computer.
String? phoneBaseDir({bool? android, bool? ios, String? tempPath}) {
  final isAndroid = android ?? Platform.isAndroid;
  final isIos = ios ?? Platform.isIOS;
  if (!isAndroid && !isIos) return null;
  final temp = (tempPath ?? Directory.systemTemp.path).replaceAll(r'\', '/');
  final trimmed = temp.endsWith('/') ? temp.substring(0, temp.length - 1) : temp;
  final cut = trimmed.lastIndexOf('/');
  if (cut <= 0) return null;
  final home = trimmed.substring(0, cut); // /data/user/0/<package>   (Android)   or   <app container>   (iPhone)
  return '$home/${isAndroid ? 'files' : 'Documents'}/ASK ERP 2.0';
}

class FileAppPaths implements AppPaths {
  FileAppPaths(this.base);
  final String base;

  @override
  String get dataDir => '$base${Platform.pathSeparator}data';

  @override
  String? get defaultBackupFolder {
    final env = Platform.environment;
    final home = Platform.isWindows ? env['USERPROFILE'] : env['HOME'];
    if (home == null || Platform.isAndroid || Platform.isIOS) return '$base${Platform.pathSeparator}Backups'; // a phone: inside the app's own folder (a computer's Documents folder does not exist there)
    return [home, 'Documents', 'ASK ERP 2', 'Backups'].join(Platform.pathSeparator);
  }

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
