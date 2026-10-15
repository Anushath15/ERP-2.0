/// Keeping an eye on the computer the shop's data lives on: free disk space, and whether the data file is healthy.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/plain_error.dart';
import '../data/platform/disk_space.dart';
import 'data_providers.dart';

/// Reads the free space of the drive that holds the shop's data, and remembers the answer for a short while.
class DiskGuard {
  DiskGuard(this.path, {Future<int?> Function(String)? reader, DateTime Function()? clock})
      : _reader = reader ?? freeDiskBytes,
        _clock = clock ?? DateTime.now;
  final String? path;
  final Future<int?> Function(String) _reader;
  final DateTime Function() _clock;
  int? _free;
  DateTime? _at;

  /// How much room is left (null when unknown). Asks the disk at most every [maxAge].
  Future<int?> freeBytes({Duration maxAge = const Duration(seconds: 20)}) async {
    final p = path;
    if (p == null) return null;
    final now = _clock();
    if (_at != null && now.difference(_at!) < maxAge) return _free;
    _free = await _reader(p);
    _at = now;
    return _free;
  }

  Future<DiskLevel> level({Duration maxAge = const Duration(seconds: 20)}) async => diskLevel(await freeBytes(maxAge: maxAge));

  /// Called before every save: below 100 MB free nothing is written (the person is told why).
  Future<void> checkBeforeWrite() async {
    final free = await freeBytes();
    if (free != null && diskLevel(free) == DiskLevel.full) throw DiskFullException(free);
  }
}

/// The folder the shop data is in; the app sets it. Null (tests, the browser) means "no disk checks".
final dataDirProvider = Provider<String?>((ref) => null);

final diskGuardProvider = Provider<DiskGuard>((ref) => DiskGuard(ref.watch(dataDirProvider)));

class DiskLevelNotifier extends Notifier<DiskLevel> {
  @override
  DiskLevel build() => DiskLevel.unknown;

  Future<void> refresh() async {
    state = await ref.read(diskGuardProvider).level(maxAge: Duration.zero);
  }
}

final diskLevelProvider = NotifierProvider<DiskLevelNotifier, DiskLevel>(DiskLevelNotifier.new);

/// What the start-up and weekly checks of the data file found.
enum FileHealth { unchecked, ok, damaged }

class FileHealthNotifier extends Notifier<FileHealth> {
  @override
  FileHealth build() => FileHealth.unchecked;
  void set(FileHealth h) => state = h;
}

final fileHealthProvider = NotifierProvider<FileHealthNotifier, FileHealth>(FileHealthNotifier.new);

/// What the check of the data file said when it found a problem (shown to whoever helps).
class DamageDetailsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];
  void set(List<String> d) => state = d;
}

final damageDetailsProvider = NotifierProvider<DamageDetailsNotifier, List<String>>(DamageDetailsNotifier.new);

/// What the daily self-check found (figures that do not add up, in plain words). Empty = all fine or not checked yet.
class SelfCheckNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];
  void set(List<String> p) => state = p;
}

final selfCheckProblemsProvider = NotifierProvider<SelfCheckNotifier, List<String>>(SelfCheckNotifier.new);

/// Everything the Health page shows, read fresh each time the page opens.
class HealthInfo {
  const HealthInfo({required this.pendingUploads, required this.needAttention, this.freeBytes, this.fileBytes, this.lastFullCheck, this.lastSelfCheck, this.lastBackup});
  final int pendingUploads, needAttention;
  final int? freeBytes, fileBytes;
  final DateTime? lastFullCheck, lastSelfCheck, lastBackup;
}

DateTime? _ms(String? v) {
  final n = int.tryParse(v ?? '');
  return n == null || n <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(n);
}

final healthInfoProvider = FutureProvider.autoDispose<HealthInfo>((ref) async {
  // everything is read from the providers BEFORE the first await: the page may be left while this is still working
  final d = ref.watch(appDataProvider);
  final dir = ref.watch(dataDirProvider);
  final guard = ref.watch(diskGuardProvider);
  final file = ref.watch(dbFilePathProvider);
  final queue = await d.outbox.counts();
  final free = await guard.freeBytes(maxAge: Duration.zero);
  return HealthInfo(
    pendingUploads: queue.pending,
    needAttention: queue.attention,
    freeBytes: free,
    fileBytes: dir == null || file == null ? null : await fileSizeBytes(file),
    lastFullCheck: _ms(await d.settings.get('integrity.lastFull')),
    lastSelfCheck: _ms(await d.settings.get('selfcheck.last')),
    lastBackup: _ms(await d.settings.get('backup.last')),
  );
});

/// The path of the database file (null in tests and in the browser).
final dbFilePathProvider = Provider<String?>((ref) => null);
