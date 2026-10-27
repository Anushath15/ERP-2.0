import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'raw_print_stub.dart' if (dart.library.io) 'raw_print_io.dart' as impl;

/// Sends bytes that are already in the printer's own language (ESC/POS) straight to a receipt printer, with no driver drawing a page:
/// to a printer Windows knows (as a "RAW" job through the Windows print queue) or to a network printer (port 9100). The app uses the real
/// one; tests use a stand-in that records the bytes and never touches a printer.
abstract class RawPrinter {
  /// True when Windows took the job for [printerName].
  Future<bool> toWindowsPrinter(String printerName, Uint8List bytes, {required String jobName});

  /// True when every byte reached the printer at [host]:[port].
  Future<bool> toNetwork(String host, int port, Uint8List bytes);
}

class SystemRawPrinter implements RawPrinter {
  const SystemRawPrinter();
  @override
  Future<bool> toWindowsPrinter(String printerName, Uint8List bytes, {required String jobName}) => impl.rawToWindowsPrinter(printerName, bytes, jobName: jobName);
  @override
  Future<bool> toNetwork(String host, int port, Uint8List bytes) => impl.rawToNetwork(host, port, bytes);
}

final rawPrinterProvider = Provider<RawPrinter>((ref) => const SystemRawPrinter());
