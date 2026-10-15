import 'disk_space_stub.dart' if (dart.library.io) 'disk_space_io.dart' as impl;

/// Free bytes on the drive that holds [path], or null when this platform cannot say (the caller then blocks nothing).
Future<int?> freeDiskBytes(String path) => impl.freeDiskBytes(path);

/// Size of the file at [path] in bytes (null when it is not a file we can see: the browser, or no such file).
Future<int?> fileSizeBytes(String path) => impl.fileSizeBytes(path);

/// What the shop owner is told before something is saved.
enum DiskLevel { ok, low, full, unknown }

const warnFreeBytes = 500 * 1024 * 1024;
const blockFreeBytes = 100 * 1024 * 1024;

DiskLevel diskLevel(int? freeBytes) {
  if (freeBytes == null) return DiskLevel.unknown;
  if (freeBytes < blockFreeBytes) return DiskLevel.full;
  if (freeBytes < warnFreeBytes) return DiskLevel.low;
  return DiskLevel.ok;
}
