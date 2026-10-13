import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'design/theme.dart';
import 'design/text_zoom.dart';
import 'fake/store.dart';
import 'router.dart';

class ErpApp extends ConsumerStatefulWidget {
  const ErpApp({super.key, this.initialLocation = '/'});
  final String initialLocation;
  @override
  ConsumerState<ErpApp> createState() => _ErpAppState();
}

class _ErpAppState extends ConsumerState<ErpApp> {
  late final GoRouter _router = buildRouter(initialLocation: widget.initialLocation);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
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
    ThemeData theme(Brightness b) => buildTheme(b, accent: s.accent, highContrast: s.highContrast, font: s.font, density: s.density);
    return MaterialApp.router(
      title: 'Senthil Enterprises ERP 2.0',
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
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
