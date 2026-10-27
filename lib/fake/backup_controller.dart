import 'dart:async';
import 'dart:io' show FileSystemException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../core/android_bridge.dart';
import '../core/app_info.dart';
import '../core/app_paths.dart';
import '../data/backup/backup.dart';
import 'data_providers.dart';
import 'health.dart';

/// On a phone the backup file lies inside the app's own folder, where it vanishes with the app (removed, data cleared, phone reset). The mirror
/// keeps a second copy where the person can find it (Downloads/ASK ERP 2.0, one rolling file per backup name) and can send a copy
/// to Drive, WhatsApp or e-mail. Null on a computer: nothing changes there.
abstract class BackupMirror {
  /// Copies [path] into Downloads and returns the place shown to the person, or null when that could not be done.
  Future<String?> save(String path);

  /// Opens the phone's Share menu with [path]; false when nothing could open.
  Future<bool> send(String path);
}

class AndroidBackupMirror implements BackupMirror {
  const AndroidBackupMirror(this.bridge);
  final AndroidBridge bridge;

  @override
  Future<String?> save(String path) => bridge.copyFileToDownloads(path, name: p.basename(path), mime: 'application/octet-stream');

  @override
  Future<bool> send(String path) async => await bridge.shareFile(path, name: p.basename(path), mime: 'application/octet-stream', text: 'ASK ERP 2.0 backup') != null;
}

final backupMirrorProvider = Provider<BackupMirror?>((ref) {
  final bridge = ref.watch(androidBridgeProvider);
  return bridge.available ? AndroidBackupMirror(bridge) : null;
});

final appPathsProvider = Provider<AppPaths?>((ref) => null);
final deviceIdProvider = Provider<String>((ref) => '00000000');

class BackupState {
  const BackupState({this.folder, this.last, this.lastError, this.running = false, this.closing = false, this.lastFile, this.lastKind, this.copyPlace});
  final String? folder, lastError, lastFile;

  /// Where the phone's second copy of the newest backup lies (e.g. "Downloads/ASK ERP 2.0/..."), null when there is none yet.
  final String? copyPlace;
  final DateTime? last;
  final bool running, closing;

  /// Why the last backup was made (the routine ones all go to the same file, so the file name no longer says).
  final BackupKind? lastKind;

  BackupState copyWith({String? folder, DateTime? last, String? lastError, bool clearError = false, bool? running, bool? closing, String? lastFile, BackupKind? lastKind, String? copyPlace}) => BackupState(
        folder: folder ?? this.folder,
        last: last ?? this.last,
        lastError: clearError ? null : (lastError ?? this.lastError),
        running: running ?? this.running,
        closing: closing ?? this.closing,
        lastFile: lastFile ?? this.lastFile,
        lastKind: lastKind ?? this.lastKind,
        copyPlace: copyPlace ?? this.copyPlace,
      );
}

/// Automatic local backups (they update one file in the backup folder, and keep the copy from just before it beside it): after the day's first bill, every 2 hours while the program is open (only if something changed), when it closes, and on
/// demand. A snapshot is made by SQLite itself in the background, checked, rotated (7 days, 4 weeks, 12 months) and its time remembered on this computer.
class BackupController extends Notifier<BackupState> {
  Timer? _timer;
  int _mark = -1; // the save count when the last backup was started; -1 = unknown, so a backup is due if the schedule says so
  bool _started = false;

  @override
  BackupState build() {
    ref.onDispose(() => _timer?.cancel());
    return const BackupState();
  }

  AppPaths? get _paths => ref.read(appPathsProvider);
  String? get _dbPath => ref.read(dbFilePathProvider);

  /// False in the browser build, in tests and while no data file exists.
  bool get available => backupSupported && _paths != null && _dbPath != null;

  Future<void> start({Duration firstCheck = const Duration(seconds: 20), Duration every = const Duration(minutes: 1)}) async {
    if (_started || !available) return;
    _started = true;
    await load();
    _timer = Timer.periodic(every, (_) => unawaited(tick()));
    Timer(firstCheck, () => unawaited(tick()));
  }

  /// Reads this computer's folder choice and the time of its last backup.
  Future<void> load() async {
    final paths = _paths;
    if (paths == null) return;
    final saved = await paths.readText('backup.folder');
    final folder = (saved == null || saved.isEmpty) ? paths.defaultBackupFolder : saved;
    final ms = int.tryParse(await paths.readText('backup.last') ?? '');
    state = state.copyWith(folder: folder, last: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms));
  }

  bool get _changed => ref.read(appDataProvider).db.commitCount != _mark;

  /// The schedule. Called every minute: the first backup of a day with bills, then at most one every 2 hours, and only when something was saved since the last one.
  Future<void> tick({DateTime? now}) async {
    if (!available || state.running || state.closing) return;
    final t = now ?? DateTime.now();
    final last = state.last;
    final d = ref.read(appDataProvider);
    final lastBill = (await d.reports.shopCounts()).lastBill;
    final billToday = lastBill != null && lastBill.year == t.year && lastBill.month == t.month && lastBill.day == t.day;
    final noBackupToday = last == null || last.year != t.year || last.month != t.month || last.day != t.day;
    final due2h = last == null || t.difference(last) >= const Duration(hours: 2);
    if ((billToday && noBackupToday) || (due2h && _changed && (lastBill != null || last != null))) {
      await run(BackupKind.auto);
    }
  }

  Future<bool> run(BackupKind kind, {String fy = ''}) async {
    if (!available) return false;
    if (state.running) return false;
    final folder = state.folder ?? _paths!.defaultBackupFolder;
    if (folder == null) {
      state = state.copyWith(lastError: 'No backup folder is set. Choose one on the Backups page.');
      return false;
    }
    state = state.copyWith(running: true, clearError: true, folder: folder);
    final mark = ref.read(appDataProvider).db.commitCount;
    try {
      final info = await createBackup(livePath: _dbPath!, folder: folder, deviceId: ref.read(deviceIdProvider), appVersion: appVersionLabel, kind: kind, fy: fy, rolling: true);
      await _paths!.writeText('backup.last', '${info.at.millisecondsSinceEpoch}');
      _mark = mark;
      state = state.copyWith(running: false, last: info.at, lastFile: info.path, lastKind: kind, clearError: true);
      await _mirror(info.path);
      if (kind == BackupKind.auto || kind == BackupKind.manual || kind == BackupKind.closing) {
        try {
          await rotateBackups(folder);
        } catch (_) {
          // clearing old backups is housekeeping; a failure here never hides the good backup that was just made
        }
      }
      return true;
    } on BackupException catch (e) {
      state = state.copyWith(running: false, lastError: e.message);
      return false;
    } on FileSystemException catch (e) {
      state = state.copyWith(running: false, lastError: 'The backup could not be saved (${e.message}). Your data is safe.');
      return false;
    }
  }

  /// A phone keeps a second copy of every backup in Downloads (see [BackupMirror]). Never fails the backup that was just made.
  Future<void> _mirror(String path) async {
    final m = ref.read(backupMirrorProvider);
    if (m == null) return;
    try {
      final place = await m.save(path);
      if (place != null) state = state.copyWith(copyPlace: place);
    } catch (_) {
      // the copy is an extra; the backup inside the app is already safe
    }
  }

  /// The newest backup (a fresh manual one when there is none yet).
  Future<BackupInfo> _newestOrMake() async {
    final folder = state.folder;
    if (folder == null) throw BackupException('No backup folder is set.');
    var newest = listBackups(folder).where((b) => b.kind != BackupKind.safety).firstOrNull;
    if (newest == null) {
      if (!await run(BackupKind.manual)) throw BackupException(state.lastError ?? 'No backup could be made.');
      newest = listBackups(folder).first;
    }
    return newest;
  }

  /// Phone: puts the newest backup in Downloads now and returns the place shown to the person. Throws [BackupException] when it could not be done.
  Future<String> saveCopyToDownloads() async {
    final m = ref.read(backupMirrorProvider);
    if (m == null) throw BackupException('This needs the phone program.');
    final newest = await _newestOrMake();
    final place = await m.save(newest.path);
    if (place == null) throw BackupException('The copy could not be saved. Your backup inside the program is safe.');
    state = state.copyWith(copyPlace: place);
    return place;
  }

  /// Phone: opens the Share menu with the newest backup (Drive, WhatsApp, e-mail...). False when nothing could open.
  Future<bool> sendNewestCopy() async {
    final m = ref.read(backupMirrorProvider);
    if (m == null) throw BackupException('This needs the phone program.');
    final newest = await _newestOrMake();
    return m.send(newest.path);
  }

  /// When the program is closed: one last backup if anything was saved since the previous one. Gives up after a minute so closing is never stuck.
  Future<void> backupOnClose() async {
    if (!available || state.running) return;
    final last = state.last;
    if (!_changed || (last != null && DateTime.now().difference(last) < const Duration(minutes: 3))) return;
    state = state.copyWith(closing: true);
    try {
      await run(BackupKind.closing).timeout(const Duration(minutes: 1), onTimeout: () => false);
    } finally {
      state = state.copyWith(closing: false);
    }
  }

  /// Chooses where backups go. The folder is tried first (made, and a small file written and removed); only a usable folder is saved.
  Future<String?> setFolder(String path) async {
    final paths = _paths;
    if (paths == null) return 'Backups need the Windows or Mac program.';
    try {
      await tryFolder(path);
    } on BackupException catch (e) {
      return e.message;
    }
    await paths.writeText('backup.folder', path);
    state = state.copyWith(folder: path, clearError: true);
    return null;
  }

  Future<void> useDefaultFolder() async {
    final paths = _paths;
    if (paths == null) return;
    await paths.writeText('backup.folder', '');
    state = state.copyWith(folder: paths.defaultBackupFolder, clearError: true);
  }

  /// The newest backup copied to [dest] (a pen drive or another folder) and proved identical. Makes a fresh backup first when there is none.
  Future<String> copyNewestTo(String dest) async {
    final folder = state.folder;
    if (folder == null) throw BackupException('No backup folder is set.');
    var newest = listBackups(folder).where((b) => b.kind != BackupKind.safety).firstOrNull;
    if (newest == null) {
      if (!await run(BackupKind.manual)) throw BackupException(state.lastError ?? 'No backup could be made.');
      newest = listBackups(folder).first;
    }
    return copyBackupTo(newest.path, dest);
  }

  bool hasArchive(String fy) {
    final folder = state.folder;
    return folder != null && listBackups(folder).any((b) => b.kind == BackupKind.archive && b.fy == fy);
  }

  /// Dismisses the failure message (the next scheduled try may succeed).
  void dismissError() => state = state.copyWith(clearError: true);
}

final backupControllerProvider = NotifierProvider<BackupController, BackupState>(BackupController.new);

/// The files in the backup folder, newest first, refreshed whenever a backup finishes.
final backupListProvider = Provider.autoDispose<List<BackupInfo>>((ref) {
  final s = ref.watch(backupControllerProvider);
  final folder = s.folder;
  if (folder == null || !backupSupported) return const [];
  ref.watch(backupControllerProvider.select((x) => x.last));
  return listBackups(folder);
});
