import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'cloud/session_vault_io.dart' show systemDll;

/// DOC_INFO_1W: the job's name, no output file, and the "RAW" data type (the bytes go to the printer as they are).
final class _DocInfo1 extends Struct {
  external Pointer<Utf16> docName;
  external Pointer<Utf16> outputFile;
  external Pointer<Utf16> dataType;
}

typedef _OpenN = Int32 Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>);
typedef _OpenD = int Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>);
typedef _StartDocN = Uint32 Function(IntPtr, Uint32, Pointer<_DocInfo1>);
typedef _StartDocD = int Function(int, int, Pointer<_DocInfo1>);
typedef _WriteN = Int32 Function(IntPtr, Pointer<Void>, Uint32, Pointer<Uint32>);
typedef _WriteD = int Function(int, Pointer<Void>, int, Pointer<Uint32>);
typedef _HandleN = Int32 Function(IntPtr);
typedef _HandleD = int Function(int);

/// The Windows print queue, RAW: OpenPrinter, StartDocPrinter, StartPagePrinter, WritePrinter, EndPagePrinter, EndDocPrinter, ClosePrinter.
/// Runs on its own thread (a printer shared over the network can take a while to answer) so the program never freezes.
Future<bool> rawToWindowsPrinter(String printerName, Uint8List bytes, {required String jobName}) async {
  if (!Platform.isWindows || printerName.isEmpty || bytes.isEmpty) return false;
  try {
    return await Isolate.run(() => _spool(printerName, bytes, jobName)).timeout(const Duration(seconds: 30), onTimeout: () => false);
  } catch (_) {
    return false;
  }
}

bool _spool(String printerName, Uint8List bytes, String jobName) {
  final ws = DynamicLibrary.open(systemDll('winspool.drv'));
  final open = ws.lookupFunction<_OpenN, _OpenD>('OpenPrinterW');
  final startDoc = ws.lookupFunction<_StartDocN, _StartDocD>('StartDocPrinterW');
  final startPage = ws.lookupFunction<_HandleN, _HandleD>('StartPagePrinter');
  final write = ws.lookupFunction<_WriteN, _WriteD>('WritePrinter');
  final endPage = ws.lookupFunction<_HandleN, _HandleD>('EndPagePrinter');
  final endDoc = ws.lookupFunction<_HandleN, _HandleD>('EndDocPrinter');
  final close = ws.lookupFunction<_HandleN, _HandleD>('ClosePrinter');
  return using((arena) {
    final handle = arena<IntPtr>();
    if (open(printerName.toNativeUtf16(allocator: arena), handle, nullptr) == 0) return false;
    final h = handle.value;
    try {
      final info = arena<_DocInfo1>();
      info.ref
        ..docName = (jobName.isEmpty ? 'ASK ERP bill' : jobName).toNativeUtf16(allocator: arena)
        ..outputFile = nullptr
        ..dataType = 'RAW'.toNativeUtf16(allocator: arena);
      if (startDoc(h, 1, info) == 0) return false;
      var ok = false;
      try {
        if (startPage(h) != 0) {
          final buf = arena<Uint8>(bytes.length);
          buf.asTypedList(bytes.length).setAll(0, bytes);
          final written = arena<Uint32>();
          ok = write(h, buf.cast(), bytes.length, written) != 0 && written.value == bytes.length;
          endPage(h);
        }
      } finally {
        endDoc(h);
      }
      return ok;
    } finally {
      close(h);
    }
  });
}

/// A network receipt printer (most listen on port 9100): connect, send every byte, close. Gives up after a few seconds.
Future<bool> rawToNetwork(String host, int port, Uint8List bytes) async {
  Socket? s;
  try {
    s = await Socket.connect(host, port, timeout: const Duration(seconds: 4));
    s.add(bytes);
    await s.flush().timeout(const Duration(seconds: 8));
    await s.close().timeout(const Duration(seconds: 4));
    return true;
  } catch (_) {
    s?.destroy();
    return false;
  }
}
