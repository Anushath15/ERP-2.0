import 'dart:async';
import 'dart:io' show FileSystemException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_info.dart';
import '../core/app_paths.dart';
import '../data/backup/backup.dart';
import 'data_providers.dart';
import 'health.dart';

final appPathsProvider = Provider<AppPaths?>((ref) => null);
final deviceIdProvider = Provider<String>((ref) => '00000000');

class BackupState {
  const BackupState({this.folder, this.last, this.lastError, this.running = false, this.closing = false, this.lastFile});
  final String? folder, lastError, lastFile;
  final DateTime? last;
  final bool running, closing;

  BackupState copyWith({String? folder, DateTime? last, String? lastError, bool clearError = false, bool? running, bool? closing, String? lastFile}) => BackupState(
        folder: folder ?? this.folder,
        last: last ?? this.last,
        lastError: clearError ? null : (lastError ?? this.lastError),
        running: running ?? this.running,
        closing: closing ?? this.closing,
        lastFile: lastFile ?? this.lastFile,
      );
}

/// Automatic local backups: after the day's first bill, every 2 hours while the program is open (only if something changed), when it closes, and on
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
      final info = await createBackup(livePath: _dbPath!, folder: folder, deviceId: ref.read(deviceIdProvider), appVersion: appVersionLabel, kind: kind, fy: fy);
      await _paths!.writeText('backup.last', '${info.at.millisecondsSinceEpoch}');
      _mark = mark;
      state = state.copyWith(running: false, last: info.at, lastFile: info.path, clearError: true);
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
