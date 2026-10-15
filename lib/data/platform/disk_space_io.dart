import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Free bytes on the drive that holds [path], or null when this platform cannot say (the caller then does not block anything).
Future<int?> freeDiskBytes(String path) async {
  try {
    if (Platform.isWindows) return _windows(path);
    if (Platform.isMacOS || Platform.isLinux) return await _df(path);
  } catch (_) {
    return null;
  }
  return null;
}

typedef _GetDiskFreeSpaceExNative = Int32 Function(Pointer<Utf16> dir, Pointer<Uint64> avail, Pointer<Uint64> total, Pointer<Uint64> free);
typedef _GetDiskFreeSpaceEx = int Function(Pointer<Utf16> dir, Pointer<Uint64> avail, Pointer<Uint64> total, Pointer<Uint64> free);

int? _windows(String path) {
  final lib = DynamicLibrary.open('kernel32.dll');
  final fn = lib.lookupFunction<_GetDiskFreeSpaceExNative, _GetDiskFreeSpaceEx>('GetDiskFreeSpaceExW');
  // the folder may not exist yet: walk up to one that does
  var dir = Directory(path);
  while (!dir.existsSync() && dir.parent.path != dir.path) {
    dir = dir.parent;
  }
  final p = dir.path.toNativeUtf16();
  final avail = calloc<Uint64>();
  final total = calloc<Uint64>();
  final free = calloc<Uint64>();
  try {
    if (fn(p, avail, total, free) == 0) return null;
    return avail.value;
  } finally {
    calloc.free(p);
    calloc.free(avail);
    calloc.free(total);
    calloc.free(free);
  }
}

Future<int?> _df(String path) async {
  var dir = Directory(path);
  while (!dir.existsSync() && dir.parent.path != dir.path) {
    dir = dir.parent;
  }
  final r = await Process.run('df', ['-Pk', dir.path]);
  if (r.exitCode != 0) return null;
  final lines = (r.stdout as String).trim().split('\n');
  if (lines.length < 2) return null;
  final cols = lines.last.trim().split(RegExp(r'\s+'));
  final kb = int.tryParse(cols.length > 3 ? cols[3] : '');
  return kb == null ? null : kb * 1024;
}


Future<int?> fileSizeBytes(String path) async {
  try {
    final f = File(path);
    return f.existsSync() ? f.lengthSync() : null;
  } catch (_) {
    return null;
  }
}
