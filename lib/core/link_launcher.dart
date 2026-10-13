import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/credit/reminder.dart';
import 'link_launcher_stub.dart'
    if (dart.library.io) 'link_launcher_io.dart'
    if (dart.library.js_interop) 'link_launcher_web.dart' as impl;

/// Opens a link in another app or the browser. Phase 1 uses small built-in code for Windows, macOS, Linux and the web, so
/// the prototype builds without any plugin. Phase 2 swaps this one class for `url_launcher` (needed on Android) once
/// Windows Developer Mode is on or the build runs on CI. Nothing else in the app changes.
abstract class LinkLauncher {
  LinkPlatform get platform;

  /// Tries to open [url]. Returns false when nothing could handle it (for example the WhatsApp app is not installed).
  Future<bool> open(String url);
}

/// Tries each link in order and stops at the first one that opens.
Future<bool> openFirst(LinkLauncher l, List<String> urls) async {
  for (final u in urls) {
    if (await l.open(u)) return true;
  }
  return false;
}

final linkLauncherProvider = Provider<LinkLauncher>((ref) => impl.createLauncher());
