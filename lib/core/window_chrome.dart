import 'package:flutter/material.dart';
import 'window_chrome_stub.dart' if (dart.library.io) 'window_chrome_io.dart' as impl;

/// Paints the Windows title bar (the strip with the minimize / maximize / close buttons) in the same colours as the program's top bar, light or
/// dark, so it no longer shows as a white strip above a dark screen. Does nothing on other systems or on old Windows.
class WindowChromeSync extends StatefulWidget {
  const WindowChromeSync({super.key, required this.child});
  final Widget child;
  @override
  State<WindowChromeSync> createState() => _WindowChromeSyncState();
}

class _WindowChromeSyncState extends State<WindowChromeSync> {
  Color? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = Theme.of(context);
    final color = t.colorScheme.surface;
    if (color == _last) return;
    _last = color;
    final dark = t.brightness == Brightness.dark;
    WidgetsBinding.instance.addPostFrameCallback((_) => impl.paintTitleBar(dark: dark, background: color.toARGB32() & 0xFFFFFF, text: (dark ? Colors.white : Colors.black).toARGB32() & 0xFFFFFF));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
