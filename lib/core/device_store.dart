import 'device_store_stub.dart'
    if (dart.library.io) 'device_store_io.dart'
    if (dart.library.js_interop) 'device_store_web.dart' as impl;

/// Per-device settings storage (text size, theme, printer...). NEVER synced and never touched by a restore.
abstract class DeviceStore {
  Map<String, Object?> load();
  void save(Map<String, Object?> data);
}

class MemoryDeviceStore implements DeviceStore {
  MemoryDeviceStore([Map<String, Object?>? initial]) : data = {...?initial};
  Map<String, Object?> data;
  @override
  Map<String, Object?> load() => {...data};
  @override
  void save(Map<String, Object?> d) => data = {...d};
}

/// The real store for this platform (a small JSON file on desktop, local storage on the web).
DeviceStore createDeviceStore() => impl.createPlatformStore(MemoryDeviceStore.new);
