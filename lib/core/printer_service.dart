import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// A printer the computer knows (as Windows lists it).
class PrinterInfo {
  const PrinterInfo({required this.name, required this.isDefault});
  final String name;
  final bool isDefault;
}

enum PrintStatus { sent, noPrinter, failed }

/// What happened when a PDF was sent to a printer: [printer] is the name it went to (empty in the browser, where the person picks).
class PrintOutcome {
  const PrintOutcome(this.status, {this.printer = ''});
  final PrintStatus status;
  final String printer;
}

/// Sends a PDF straight to a printer (no dialog) and lists the printers. The app uses the real one; tests use a stand-in that
/// records what would have been printed and never touches a printer.
abstract class PrinterService {
  Future<List<PrinterInfo>> printers();

  /// Prints [bytes] on the printer called [printerName]; empty or not found: the computer's default printer.
  Future<PrintOutcome> printPdf(Uint8List bytes, {required String jobName, String printerName = ''});
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
  Future<PrintOutcome> printPdf(Uint8List bytes, {required String jobName, String printerName = ''}) async {
    try {
      if (kIsWeb) {
        final ok = await Printing.layoutPdf(onLayout: (_) async => bytes, name: jobName);
        return PrintOutcome(ok ? PrintStatus.sent : PrintStatus.failed);
      }
      final all = (await Printing.listPrinters()).where((p) => p.isAvailable).toList();
      final chosen = all.where((p) => printerName.isNotEmpty && p.name == printerName).firstOrNull ?? all.where((p) => p.isDefault).firstOrNull ?? all.firstOrNull;
      if (chosen == null) return const PrintOutcome(PrintStatus.noPrinter);
      final ok = await Printing.directPrintPdf(printer: chosen, onLayout: (_) async => bytes, name: jobName);
      return PrintOutcome(ok ? PrintStatus.sent : PrintStatus.failed, printer: chosen.name);
    } catch (_) {
      return const PrintOutcome(PrintStatus.failed);
    }
  }
}
