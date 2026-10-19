import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/app_data.dart';
import '../../data/sync/sync_api.dart';
import '../../data/sync/sync_engine.dart';
import '../../fake/data_providers.dart';
import '../../fake/store.dart' show SyncState, settingsProvider;
import '../data_mode.dart';
import 'auth_api.dart';
import 'auth_controller.dart';
import 'cloud_config.dart';
import 'http_sync_api.dart';

enum SyncPhase { off, idle, syncing, offline, attention, signedOut }

class SyncStatus {
  const SyncStatus({this.phase = SyncPhase.off, this.pending = 0, this.attention = 0, this.last, this.problem = '', this.newFromCloud = false});

  /// [SyncPhase.off]: no cloud in this build, demo shop, or not signed in - the program works on this computer only.
  final SyncPhase phase;
  final int pending, attention;
  final DateTime? last;
  final String problem;

  /// Other computers sent changes: the lists on screen are older than the database until the program is reloaded.
  final bool newFromCloud;

  bool get active => phase != SyncPhase.off;

  SyncStatus copyWith({SyncPhase? phase, int? pending, int? attention, DateTime? last, String? problem, bool? newFromCloud}) => SyncStatus(
      phase: phase ?? this.phase, pending: pending ?? this.pending, attention: attention ?? this.attention, last: last ?? this.last, problem: problem ?? this.problem, newFromCloud: newFromCloud ?? this.newFromCloud);
}

/// Runs the sync engine on a timer for the real shop once this computer is signed in to the shop's cloud account, and tells the screens
/// where it stands. Without a cloud address in the build, in the demo shop, or signed out, it does nothing at all.
class SyncController extends Notifier<SyncStatus> {
  Timer? _timer;
  SyncEngine? _engine;
  AppData? _data;
  bool _running = false;

  /// How often the program talks to the cloud while it is open (the cloud call is tiny when nothing changed).
  static const interval = Duration(seconds: 20);

  @override
  SyncStatus build() {
    ref.onDispose(() => _timer?.cancel());
    return const SyncStatus();
  }

  /// Starts (or stops) the sync to match the situation: real shop + cloud configured + signed in. Safe to call again at any time.
  void refreshWiring() {
    final cfg = ref.read(cloudConfigProvider);
    final signedIn = ref.read(authProvider).status == AuthStatus.signedIn;
    final real = ref.read(appModeProvider) == DataMode.real;
    if (!cfg.configured || !real) return stop();
    if (!signedIn) {
      stop();
      if (_data != null || state.phase == SyncPhase.off) state = state.copyWith(phase: ref.read(authProvider).status == AuthStatus.loading ? SyncPhase.off : SyncPhase.signedOut);
      return;
    }
    if (_engine != null) return;
    final data = ref.read(appDataProvider);
    final auth = ref.read(authProvider.notifier);
    final api = HttpSyncApi(
      cfg,
      data.cx.deviceId,
      () async {
        try {
          final c = await auth.credentials();
          return c == null ? null : (token: c.token, shopId: c.shopId);
        } on AuthFailure catch (e) {
          throw e.problem == AuthProblem.network ? const SyncOffline('no internet') : SyncAuthFailed('${e.problem}');
        }
      },
      onUnauthorized: auth.expireToken,
    );
    startWith(data, api);
  }

  /// Starts the engine over [data] with [api] (the app passes the HTTP one; tests pass a pretend cloud).
  void startWith(AppData data, SyncApi api, {bool timer = true}) {
    _timer?.cancel();
    _data = data;
    _engine = SyncEngine(data.cx, api, onChanged: () => state = state.copyWith(newFromCloud: true));
    state = state.copyWith(phase: SyncPhase.idle);
    if (timer) {
      _timer = Timer.periodic(interval, (_) => unawaited(syncNow()));
      unawaited(syncNow());
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _engine = null;
    _data = null;
    if (state.phase != SyncPhase.off && state.phase != SyncPhase.signedOut) state = state.copyWith(phase: SyncPhase.off);
  }

  Future<void> _counts() async {
    final d = _data;
    if (d == null) return;
    final c = await d.outbox.counts();
    state = state.copyWith(pending: c.pending, attention: c.attention);
  }

  /// One round now (the "Sync now" button and every tick of the timer). Never throws; the outcome is in [state].
  Future<void> syncNow() async {
    final e = _engine;
    if (e == null || _running) return;
    _running = true;
    state = state.copyWith(phase: SyncPhase.syncing);
    try {
      await e.run();
      await _counts();
      state = state.copyWith(phase: state.attention > 0 ? SyncPhase.attention : SyncPhase.idle, last: DateTime.now(), problem: '');
    } on SyncOffline catch (x) {
      await _counts();
      state = state.copyWith(phase: SyncPhase.offline, problem: x.message);
    } on SyncAuthFailed catch (x) {
      await _counts();
      state = state.copyWith(phase: SyncPhase.signedOut, problem: x.message);
    } catch (x) {
      await _counts();
      state = state.copyWith(phase: SyncPhase.attention, problem: '$x');
    } finally {
      _running = false;
    }
  }
}

final syncProvider = NotifierProvider<SyncController, SyncStatus>(SyncController.new);

/// The status the chip and the settings card show: the real sync's when it is running, otherwise the preview value of the demo.
SyncState effectiveSyncState(WidgetRef ref) {
  final s = ref.watch(syncProvider);
  if (!s.active) return ref.watch(settingsProvider).sync;
  return switch (s.phase) {
    SyncPhase.syncing => SyncState.syncing,
    SyncPhase.offline => SyncState.offline,
    SyncPhase.attention || SyncPhase.signedOut => SyncState.attention,
    _ => s.pending > 0 ? SyncState.syncing : SyncState.synced,
  };
}
