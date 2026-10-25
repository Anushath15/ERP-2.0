import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'askprint_stub.dart' if (dart.library.io) 'askprint_io.dart';

/// A printer the computer knows (as Windows lists it).
class PrinterInfo {
  const PrinterInfo({required this.name, required this.isDefault});
  final String name;
  final bool isDefault;
}

enum PrintStatus { sent, noPrinter, failed }

/// What happened when a PDF was sent to a printer: [printer] is the name it went to (empty in the browser, where the person picks).
class PrintOutcome {
  const PrintOutcome(this.status, {this.printer = '', this.viaWindow = false});
  final PrintStatus status;
  final String printer;

  /// The Windows print window did the printing (the direct way was refused or switched off).
  final bool viaWindow;
}

/// Sends a PDF straight to a printer (no dialog) and lists the printers. The app uses the real one; tests use a stand-in that
/// records what would have been printed and never touches a printer.
abstract class PrinterService {
  Future<List<PrinterInfo>> printers();

  /// Prints [bytes] on the printer called [printerName]; empty or not found: the computer's default printer.
  /// [viaDialog]: skip the direct way and open the Windows print window (for printers whose driver refuses direct jobs).
  Future<PrintOutcome> printPdf(Uint8List bytes, {required String jobName, String printerName = '', bool viaDialog = false});
}

final printerServiceProvider = Provider<PrinterService>((ref) => PackagePrinterService());

/// Direct printing with the `printing` package (Windows: the printer's own driver, no print dialog). In a browser there is no
/// direct printing, so the browser's own print window opens instead.
class PackagePrinterService implements PrinterService {
  @override
  Future<List<PrinterInfo>> printers() async {
    if (kIsWeb) return const [];
    try {
      final all = await Printing.listPrinters();
      return [for (final p in all) if (p.isAvailable) PrinterInfo(name: p.name, isDefault: p.isDefault)];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<PrintOutcome> printPdf(Uint8List bytes, {required String jobName, String printerName = '', bool viaDialog = false}) async {
    try {
      if (kIsWeb) {
        final ok = await Printing.layoutPdf(onLayout: (_) async => bytes, name: jobName);
        return PrintOutcome(ok ? PrintStatus.sent : PrintStatus.failed);
      }
      final all = (await Printing.listPrinters()).where((p) => p.isAvailable).toList();
      final chosen = all.where((p) => printerName.isNotEmpty && p.name == printerName).firstOrNull ?? all.where((p) => p.isDefault).firstOrNull ?? all.firstOrNull;
      if (chosen == null) return const PrintOutcome(PrintStatus.noPrinter);
      if (!viaDialog) {
        // first the modern Windows way (print ticket + XPS pipeline, like Word); null = the helper is not installed
        final helped = await printWithHelper(bytes, printerName: chosen.name);
        if (helped == true) return PrintOutcome(PrintStatus.sent, printer: chosen.name);
        try {
          final ok = await Printing.directPrintPdf(printer: chosen, onLayout: (_) async => bytes, name: jobName);
          if (ok) return PrintOutcome(PrintStatus.sent, printer: chosen.name);
        } catch (_) {
          // some drivers (HP "V4" ones) refuse a direct job ("the remote procedure call failed"): the Windows print window below prints it
        }
      }
      final ok = await Printing.layoutPdf(onLayout: (_) async => bytes, name: jobName, usePrinterSettings: true);
      return PrintOutcome(ok ? PrintStatus.sent : PrintStatus.failed, printer: chosen.name, viaWindow: true);
    } catch (_) {
      return const PrintOutcome(PrintStatus.failed);
    }
  }
}
