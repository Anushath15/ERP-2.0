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
import 'fake/credit_store.dart';
import 'fake/store.dart';
import 'router.dart';

class ErpApp extends ConsumerStatefulWidget {
  const ErpApp({super.key, this.initialLocation = '/', this.router});
  final String initialLocation;

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
    });
    if (!kDebugMode) {
      // The auto-protect guard only runs in real (profile/release) builds; debug frames are always slow.
      _guard = FrameGuard(onReduce: _reduceMotion);
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    }
  }

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
