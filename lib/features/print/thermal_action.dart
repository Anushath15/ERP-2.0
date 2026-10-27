import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/diag/diag_log.dart';
import '../../core/printer_service.dart';
import '../../core/raw_print.dart';
import '../../core/date_fmt.dart';
import '../../design/widgets.dart';
import '../../fake/models.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart';
import '../billing/cart.dart';
import 'escpos.dart';
import 'print_layout.dart';

/// True when a print on [paper] goes straight to the thermal printer (switched on in Settings, and a roll paper).
bool useThermal(AppSettings st, PaperSize paper) => st.thermal != ThermalLink.off && isRoll(paper);

/// Letters per line: the one chosen in Settings, else by the paper (48 on 80 mm, 32 on 58 mm).
int thermalCharsFor(AppSettings st, PaperSize paper) => st.thermalChars > 0 ? st.thermalChars : (paper == PaperSize.mm58 ? thermalChars58 : thermalChars80);

enum ThermalResult { sent, failed, badAddress, noPrinter }

/// Sends ESC/POS bytes the way Settings says: to the bill printer Windows knows (the chosen one, else the default), or to the network address.
Future<ThermalResult> sendThermal(WidgetRef ref, Uint8List bytes, String jobName) async {
  final st = ref.read(settingsProvider);
  final raw = ref.read(rawPrinterProvider);
  final started = DateTime.now();
  ThermalResult r;
  var target = '';
  try {
    if (st.thermal == ThermalLink.network) {
      final a = parsePrinterAddress(st.thermalAddress);
      target = st.thermalAddress;
      r = a == null ? ThermalResult.badAddress : (await raw.toNetwork(a.host, a.port, bytes) ? ThermalResult.sent : ThermalResult.failed);
    } else {
      // the bill printer picked in Settings, by its name even when Windows calls it offline (cheap receipt printers often look offline
      // and still print; a queued job prints when it is switched on). Nothing picked: the Windows default, only when it makes paper.
      // Never a guess among other printers (receipt-printer bytes on an inkjet print junk) and never OneNote (it would open on the desk).
      target = st.printerName;
      if (target.isEmpty) {
        final all = await ref.read(printerServiceProvider).printers();
        target = all.where((p) => p.isDefault && p.isPaper).firstOrNull?.name ?? '';
      }
      r = target.isEmpty ? ThermalResult.noPrinter : (await raw.toWindowsPrinter(target, bytes, jobName: jobName) ? ThermalResult.sent : ThermalResult.failed);
    }
  } catch (_) {
    r = ThermalResult.failed;
  }
  ref.read(diagProvider).event('print', 'thermal', {'result': r.name, 'link': st.thermal.name, 'target': target, 'bytes': bytes.length, 'ms': DateTime.now().difference(started).inMilliseconds});
  return r;
}

/// The bill on the thermal printer. [justSaved]: the print right after Save and print, the only time a cash bill opens the drawer (a reprint
/// never does). False when the printer did not take it: the caller then prints the normal way.
Future<bool> printThermalNow(BuildContext context, WidgetRef ref, PrintDoc doc, PaperSize paper, {bool justSaved = false}) async {
  final l = tr(context);
  final st = ref.read(settingsProvider);
  final lay = buildPrintLayout(doc: doc, shop: ref.read(shopProvider), l: l);
  final drawer = st.thermalDrawer && justSaved && doc.mode == DocMode.invoice && doc.pay == PayMode.cash;
  final bytes = encodeEscPosBill(lay, EscPosOptions(chars: thermalCharsFor(st, paper), cut: st.thermalCut, drawer: drawer, qrSize: paper == PaperSize.mm58 ? 5 : 6), paidText: l.rcPaidInFull);
  toast(context, l.printSending);
  final r = await sendThermal(ref, bytes, '${doc.mode == DocMode.estimation ? l.rcEstimate : l.rcTaxInvoice} ${doc.number}');
  if (r == ThermalResult.sent && context.mounted) toast(context, l.thermalSent);
  return r == ThermalResult.sent;
}

/// Settings > Thermal printer: a short test slip, or only a pulse to the cash drawer. Says in words what happened.
Future<void> thermalTestNow(BuildContext context, WidgetRef ref, {bool drawerOnly = false}) async {
  final l = tr(context);
  final st = ref.read(settingsProvider);
  final paper = isRoll(st.paper) ? st.paper : PaperSize.mm80;
  final o = EscPosOptions(chars: thermalCharsFor(st, paper), cut: st.thermalCut, drawer: drawerOnly, qrSize: paper == PaperSize.mm58 ? 5 : 6);
  final Uint8List bytes;
  if (drawerOnly) {
    bytes = (EscPos()
          ..init()
          ..openDrawer())
        .bytes;
  } else {
    bytes = encodeEscPosTestSlip(shopName: ref.read(shopProvider).name, title: l.thermalTestTitle, message: l.thermalTestLine, when: formatDateTime(ref.read(clockProvider)), o: o);
  }
  final r = await sendThermal(ref, bytes, l.thermalTestTitle);
  if (!context.mounted) return;
  toast(context, switch (r) { ThermalResult.sent => l.thermalSent, ThermalResult.badAddress => l.thermalAddressBad, ThermalResult.noPrinter => l.printNoPrinter, ThermalResult.failed => l.thermalTestFailed });
}
