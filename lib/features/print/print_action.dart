import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/diag/diag_log.dart';
import '../../core/printer_service.dart';
import '../../design/widgets.dart';
import '../../fake/store.dart';

/// The Print button: sends the PDF to the printer chosen in Settings (or the computer's default one) and says in plain words what happened.
/// [note] goes before that message (for example why the thermal printer was not used).
Future<void> printPdfNow(BuildContext context, WidgetRef ref, Uint8List bytes, String jobName, {bool forLabels = false, String? note}) async {
  final l = tr(context);
  toast(context, l.printSending);
  final started = DateTime.now();
  final st = ref.read(settingsProvider);
  final wanted = forLabels && st.labelPrinterName.isNotEmpty ? st.labelPrinterName : st.printerName; // stickers go to the label printer when one is chosen
  final svc = ref.read(printerServiceProvider);
  PrintOutcome out;
  var driver = '';
  try {
    // the printer is picked here, before anything is sent: the chosen one, else a PAPER printer (never OneNote, Print to PDF or Fax
    // unless picked by name, so OneNote never opens on the desk). No printer list (the browser) = the service decides.
    final all = await svc.printers();
    final target = all.isEmpty ? null : choosePrinter(all, wanted);
    driver = target?.driver ?? '';
    out = all.isNotEmpty && target == null
        ? PrintOutcome(all.any((p) => p.isPaper) ? PrintStatus.pickPrinter : PrintStatus.noPrinter)
        : await svc.printPdf(bytes, jobName: jobName, printerName: target?.name ?? wanted, viaDialog: st.printViaDialog, asPicture: st.printAsPicture && !forLabels);
  } catch (_) {
    out = const PrintOutcome(PrintStatus.failed);
  }
  ref.read(diagProvider).event('print', 'result', {'status': out.status.name, 'printer': out.printer, 'driver': out.driver.isEmpty ? driver : out.driver, 'viaWindow': out.viaWindow, 'paperShort': out.paperShort, 'viaDialogSetting': st.printViaDialog, 'asPicture': st.printAsPicture, 'ms': DateTime.now().difference(started).inMilliseconds, 'bytes': bytes.length});
  if (!context.mounted) return;
  final said = switch (out.status) {
    PrintStatus.sent => out.printer.isEmpty
        ? l.printSentBrowser
        : out.viaWindow
            ? (st.printViaDialog ? l.printSentWindow : '${l.printSentWindow} ${l.printUsedWindow}') // the window opens on Windows' default printer: the person picked there
            : '${l.printSent(out.printer)}${out.paperShort ? ' ${l.printPaperShort}' : ''}',
    PrintStatus.noPrinter => l.printNoPrinter,
    PrintStatus.pickPrinter => l.printPickPrinter,
    PrintStatus.failed => l.printFailed,
  };
  toast(context, note == null ? said : '$note $said');
}
