import 'app_paths_stub.dart'
    if (dart.library.io) 'app_paths_io.dart'
    if (dart.library.js_interop) 'app_paths_web.dart' as impl;

/// Where this computer keeps the shop's data and its own small per-device files. Per-device files (the device id, the demo-mode choice)
/// live OUTSIDE the data folder, so restoring or replacing the shop data never changes them.
abstract class AppPaths {
  /// The folder (or, in the browser, the name) of the shop databases.
  String get dataDir;

  /// The database for [name] (`shop` or `demo`): a file path on the desktop, a database name in the browser.
  String dbLocation(String name);

  /// A small text value kept on this device only (null when not set yet).
  Future<String?> readText(String name);
  Future<void> writeText(String name, String text);
}

AppPaths createAppPaths() => impl.createAppPaths();
