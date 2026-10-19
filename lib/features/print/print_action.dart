import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/printer_service.dart';
import '../../design/widgets.dart';
import '../../fake/store.dart';

/// The Print button: sends the PDF to the printer chosen in Settings (or the computer's default one) and says in plain words what happened.
Future<void> printPdfNow(BuildContext context, WidgetRef ref, Uint8List bytes, String jobName) async {
  final l = tr(context);
  toast(context, l.printSending);
  final out = await ref.read(printerServiceProvider).printPdf(bytes, jobName: jobName, printerName: ref.read(settingsProvider).printerName);
  if (!context.mounted) return;
  toast(
    context,
    switch (out.status) {
      PrintStatus.sent => out.printer.isEmpty ? l.printSentBrowser : l.printSent(out.printer),
      PrintStatus.noPrinter => l.printNoPrinter,
      PrintStatus.failed => l.printFailed,
    },
  );
}
