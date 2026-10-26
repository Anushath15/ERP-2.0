import 'dart:ffi';
import 'dart:io';
import 'cloud/session_vault_io.dart' show systemDll;
import 'package:ffi/ffi.dart';

/// Windows 10 (1809+) understands the dark title bar switch; Windows 11 also takes an exact caption and text colour. A call that Windows
/// does not know simply fails and is ignored. Colours are 0xRRGGBB here; Windows wants 0x00BBGGRR.
void paintTitleBar({required bool dark, required int background, required int text}) {
  if (!Platform.isWindows || Platform.environment.containsKey('FLUTTER_TEST')) return;
  try {
    final user32 = DynamicLibrary.open('user32.dll');
    final dwm = DynamicLibrary.open(systemDll('dwmapi.dll'));
    final findWindow = user32.lookupFunction<IntPtr Function(Pointer<Utf16>, Pointer<Utf16>), int Function(Pointer<Utf16>, Pointer<Utf16>)>('FindWindowW');
    final set = dwm.lookupFunction<Int32 Function(IntPtr, Uint32, Pointer<Uint32>, Uint32), int Function(int, int, Pointer<Uint32>, int)>('DwmSetWindowAttribute');
    final cls = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
    final hwnd = findWindow(cls, nullptr);
    calloc.free(cls);
    if (hwnd == 0) return;
    int bgr(int rgb) => ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF);
    final v = calloc<Uint32>();
    try {
      for (final (attr, value) in [(20, dark ? 1 : 0), (35, bgr(background)), (36, bgr(text))]) {
        v.value = value;
        set(hwnd, attr, v, 4);
      }
    } finally {
      calloc.free(v);
    }
  } catch (_) {}
}
