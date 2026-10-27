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
  final printer = forLabels && st.labelPrinterName.isNotEmpty ? st.labelPrinterName : st.printerName; // stickers go to the label printer when one is chosen
  PrintOutcome out;
  try {
    out = await ref.read(printerServiceProvider).printPdf(bytes, jobName: jobName, printerName: printer, viaDialog: st.printViaDialog);
  } catch (_) {
    out = const PrintOutcome(PrintStatus.failed);
  }
  ref.read(diagProvider).event('print', 'result', {'status': out.status.name, 'printer': out.printer, 'viaWindow': out.viaWindow, 'viaDialogSetting': st.printViaDialog, 'ms': DateTime.now().difference(started).inMilliseconds, 'bytes': bytes.length});
  if (!context.mounted) return;
  final said = switch (out.status) {
    PrintStatus.sent => out.printer.isEmpty ? l.printSentBrowser : (out.viaWindow && !st.printViaDialog ? '${l.printSent(out.printer)} ${l.printUsedWindow}' : l.printSent(out.printer)),
    PrintStatus.noPrinter => l.printNoPrinter,
    PrintStatus.failed => l.printFailed,
  };
  toast(context, note == null ? said : '$note $said');
}
