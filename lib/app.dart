import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'design/frame_guard.dart';
import 'design/motion.dart';
import 'design/motion_level.dart';
import 'design/theme.dart';
import 'design/text_zoom.dart';
import 'features/credit/credit_screens.dart' show creditRowsProvider;
import 'boot_root.dart' show DamagedFileScreen;
import 'data/db/integrity.dart';
import 'fake/credit_store.dart';
import 'fake/data_providers.dart';
import 'fake/health.dart';
import 'fake/store.dart';
import 'router.dart';

class ErpApp extends ConsumerStatefulWidget {
  const ErpApp({super.key, this.initialLocation = '/', this.router, this.dbLocation, this.runChecks = false});
  final String initialLocation;

  /// Where the database file is (for the health checks); null in tests.
  final String? dbLocation;

  /// Whether to check the data file after start-up (the real shop only).
  final bool runChecks;

  /// Lets a test or the performance tool drive navigation itself.
  final GoRouter? router;
  @override
  ConsumerState<ErpApp> createState() => _ErpAppState();
}

class _ErpAppState extends ConsumerState<ErpApp> with WidgetsBindingObserver {
  FrameGuard? _guard;
  final _clock = Stopwatch()..start();
  late final GoRouter _router = widget.router ?? buildRouter(initialLocation: widget.initialLocation);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addObserver(this);
    // Build the (sample) credit data right after the first frame, while nobody is waiting, so the first visit to a credit page is not the slow frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(creditProvider);
      ref.read(reminderLogProvider);
      ref.read(creditRowsProvider); // the Money to collect list (134 rows with ageing), so its first visit only has to draw it
    });
    if (widget.runChecks && widget.dbLocation != null) unawaited(_startChecks());
    if (!kDebugMode) {
      // The auto-protect guard only runs in real (profile/release) builds; debug frames are always slow.
      _guard = FrameGuard(onReduce: _reduceMotion);
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    }
  }

  /// After the first screen is up: SQLite's quick check of the data file (separate connection, billing carries on), then once a week
  /// the full check. A problem puts up the "your data needs repair" screen. Free disk space is looked at every minute.
  Future<void> _startChecks() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final quick = await checkDatabaseFile(widget.dbLocation!);
    if (!mounted) return;
    if (quick.isNotEmpty) {
      ref.read(damageDetailsProvider.notifier).set(quick);
      ref.read(fileHealthProvider.notifier).set(FileHealth.damaged);
      return;
    }
    ref.read(fileHealthProvider.notifier).set(FileHealth.ok);
    final d = ref.read(appDataProvider);
    final last = int.tryParse(await d.settings.get('integrity.lastFull') ?? '') ?? 0;
    if (d.cx.nowMs() - last > const Duration(days: 7).inMilliseconds) {
      final full = await checkDatabaseFile(widget.dbLocation!, full: true);
      if (!mounted) return;
      if (full.isNotEmpty) {
        ref.read(damageDetailsProvider.notifier).set(full);
        ref.read(fileHealthProvider.notifier).set(FileHealth.damaged);
        return;
      }
      await d.settings.put('integrity.lastFull', '${d.cx.nowMs()}');
    }
    unawaited(ref.read(diskLevelProvider.notifier).refresh());
    _diskTimer = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(ref.read(diskLevelProvider.notifier).refresh()));
  }

  Timer? _diskTimer;

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _guard?.onFrame(_clock.elapsedMilliseconds, t.totalSpan.inMicroseconds / 1000.0);
    }
  }

  /// Too slow for a few seconds: drop one motion level on this device and tell the owner calmly in Settings.
  void _reduceMotion() {
    final s = ref.read(settingsProvider);
    final lower = FrameGuard.lower(s.motion);
    if (lower != null) ref.read(settingsProvider.notifier).set((x) => x.copyWith(motion: lower, motionAutoReduced: true));
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  void dispose() {
    _diskTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    if (!kDebugMode) SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  /// Ctrl+Plus, Ctrl+Minus and Ctrl+0 change the text size from anywhere (no clash with F-keys, Ctrl+S, Ctrl+Shift+N).
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || !HardwareKeyboard.instance.isControlPressed) return false;
    final k = e.logicalKey;
    final n = ref.read(settingsProvider.notifier);
    final cur = ref.read(settingsProvider).textScale;
    if (k == LogicalKeyboardKey.equal || k == LogicalKeyboardKey.add || k == LogicalKeyboardKey.numpadAdd) {
      n.set((s) => s.copyWith(textScale: TextZoom.up(cur)));
      return true;
    }
    if (k == LogicalKeyboardKey.minus || k == LogicalKeyboardKey.numpadSubtract) {
      n.set((s) => s.copyWith(textScale: TextZoom.down(cur)));
      return true;
    }
    if (k == LogicalKeyboardKey.digit0 || k == LogicalKeyboardKey.numpad0) {
      n.set((s) => s.copyWith(textScale: 1.0));
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final level = Motion.resolve(chosen: s.motion, followSystem: s.followSystemMotion, systemReduces: WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations);
    ThemeData theme(Brightness b) => buildTheme(b, accent: s.accent, highContrast: s.highContrast, font: s.font, density: s.density, ripple: level != MotionLevel.off);
    return MaterialApp.router(
      title: 'ASK ERP 2.0',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: s.theme,
      builder: (context, child) {
        if (ref.watch(fileHealthProvider) == FileHealth.damaged) return DamagedFileScreen(details: ref.watch(damageDetailsProvider));
        // Our text size is multiplied with the operating system's own text size, never replacing it.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * s.textScale)),
          child: MotionScope(motion: Motion(level), child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
