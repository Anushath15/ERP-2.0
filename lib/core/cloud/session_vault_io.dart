import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import '../app_paths_io.dart' show phoneBaseDir;
import 'session_vault.dart';

/// `%LOCALAPPDATA%\ASK ERP 2.0\session.bin` (macOS / Linux: the same folder the shop data lives in, one level up from `data`).
SessionVault createVault(SessionVault Function() fallback, {String file = 'session.bin'}) {
  final env = Platform.environment;
  String? base;
  if (Platform.isWindows && env['LOCALAPPDATA'] != null) base = '${env['LOCALAPPDATA']}\\ASK ERP 2.0';
  if (Platform.isMacOS && env['HOME'] != null) base = '${env['HOME']}/Library/Application Support/ASK ERP 2.0';
  if (Platform.isLinux && env['HOME'] != null) base = '${env['HOME']}/.local/share/ASK ERP 2.0';
  base ??= phoneBaseDir();
  if (base == null) return fallback();
  return FileSessionVault(File('$base${Platform.pathSeparator}$file'));
}

/// A small file. On Windows its content is encrypted with DPAPI for the signed-in Windows user: another Windows user, or a copy of the
/// file on another computer, cannot read it. Anything damaged or unreadable simply means "not signed in".
class FileSessionVault implements SessionVault {
  FileSessionVault(this.file, {Uint8List Function(Uint8List)? protect, Uint8List? Function(Uint8List)? unprotect})
      : _protect = protect ?? (Platform.isWindows ? dpapiProtect : _plain),
        _unprotect = unprotect ?? (Platform.isWindows ? dpapiUnprotect : _plain);

  final File file;
  final Uint8List Function(Uint8List) _protect;
  final Uint8List? Function(Uint8List) _unprotect;

  static Uint8List _plain(Uint8List b) => b;

  @override
  String? read() {
    try {
      if (!file.existsSync() || file.lengthSync() > 16 * 1024) return null;
      final raw = _unprotect(file.readAsBytesSync());
      return raw == null ? null : utf8.decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  void write(String? value) {
    try {
      if (value == null) {
        if (file.existsSync()) file.deleteSync();
        return;
      }
      file.parent.createSync(recursive: true);
      final tmp = File('${file.path}.tmp');
      tmp.writeAsBytesSync(_protect(Uint8List.fromList(utf8.encode(value))), flush: true);
      tmp.renameSync(file.path);
    } catch (_) {
      // not keeping the sign-in is not worth a crash: the person signs in again next time
    }
  }
}

// ---- Windows DPAPI (crypt32.dll) through dart:ffi: no plugin ----

final class _Blob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}

typedef _ProtectN = Int32 Function(Pointer<_Blob>, Pointer<Utf16>, Pointer<_Blob>, Pointer<Void>, Pointer<Void>, Uint32, Pointer<_Blob>);
typedef _ProtectD = int Function(Pointer<_Blob>, Pointer<Utf16>, Pointer<_Blob>, Pointer<Void>, Pointer<Void>, int, Pointer<_Blob>);
typedef _UnprotectN = Int32 Function(Pointer<_Blob>, Pointer<Pointer<Utf16>>, Pointer<_Blob>, Pointer<Void>, Pointer<Void>, Uint32, Pointer<_Blob>);
typedef _UnprotectD = int Function(Pointer<_Blob>, Pointer<Pointer<Utf16>>, Pointer<_Blob>, Pointer<Void>, Pointer<Void>, int, Pointer<_Blob>);
typedef _FreeN = Pointer<Void> Function(Pointer<Void>);
typedef _FreeD = Pointer<Void> Function(Pointer<Void>);

const _uiForbidden = 0x1; // CRYPTPROTECT_UI_FORBIDDEN: never show a window

Uint8List dpapiProtect(Uint8List plain) {
  final crypt = DynamicLibrary.open('crypt32.dll');
  final free = DynamicLibrary.open('kernel32.dll').lookupFunction<_FreeN, _FreeD>('LocalFree');
  final fn = crypt.lookupFunction<_ProtectN, _ProtectD>('CryptProtectData');
  final inBlob = calloc<_Blob>();
  final outBlob = calloc<_Blob>();
  final buf = calloc<Uint8>(plain.length);
  try {
    buf.asTypedList(plain.length).setAll(0, plain);
    inBlob.ref.cbData = plain.length;
    inBlob.ref.pbData = buf;
    final label = 'ASK ERP 2.0'.toNativeUtf16();
    final ok = fn(inBlob, label, nullptr, nullptr, nullptr, _uiForbidden, outBlob);
    calloc.free(label);
    if (ok == 0) throw const FileSystemException('Could not protect the sign-in');
    final bytes = Uint8List.fromList(outBlob.ref.pbData.asTypedList(outBlob.ref.cbData));
    free(outBlob.ref.pbData.cast());
    return bytes;
  } finally {
    calloc.free(buf);
    calloc.free(inBlob);
    calloc.free(outBlob);
  }
}

/// Null when the bytes cannot be opened by this Windows user.
Uint8List? dpapiUnprotect(Uint8List protectedBytes) {
  final crypt = DynamicLibrary.open('crypt32.dll');
  final free = DynamicLibrary.open('kernel32.dll').lookupFunction<_FreeN, _FreeD>('LocalFree');
  final fn = crypt.lookupFunction<_UnprotectN, _UnprotectD>('CryptUnprotectData');
  final inBlob = calloc<_Blob>();
  final outBlob = calloc<_Blob>();
  final buf = calloc<Uint8>(protectedBytes.length);
  try {
    buf.asTypedList(protectedBytes.length).setAll(0, protectedBytes);
    inBlob.ref.cbData = protectedBytes.length;
    inBlob.ref.pbData = buf;
    final ok = fn(inBlob, nullptr, nullptr, nullptr, nullptr, _uiForbidden, outBlob);
    if (ok == 0) return null;
    final bytes = Uint8List.fromList(outBlob.ref.pbData.asTypedList(outBlob.ref.cbData));
    free(outBlob.ref.pbData.cast());
    return bytes;
  } finally {
    calloc.free(buf);
    calloc.free(inBlob);
    calloc.free(outBlob);
  }
}
