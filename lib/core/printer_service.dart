import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'askprint_stub.dart' if (dart.library.io) 'askprint_io.dart';

/// A printer the computer knows (as Windows lists it). [driver] is the Windows driver's name (for the diagnostics file and to tell a
/// paper printer from a virtual one).
class PrinterInfo {
  const PrinterInfo({required this.name, required this.isDefault, this.driver = ''});
  final String name;
  final bool isDefault;
  final String driver;

  /// False for printers that make no paper: OneNote, Print to PDF, XPS, Fax and the like. A bill goes to one of them only when the
  /// person picked it by name (sending to OneNote opens OneNote on the desk, Print to PDF asks for a file name).
  bool get isPaper => !looksVirtual(name, driver);
}

/// Names and drivers of the printers that make no paper: OneNote, PDF and XPS writers, remote-support printers (AnyDesk, TeamViewer...)
/// and fax queues. A real fax MACHINE that also prints (Brother FAX-2840) is not a fax queue and still counts as a paper printer.
bool looksVirtual(String name, String driver) {
  final n = name.toLowerCase().trim(), d = driver.toLowerCase().trim(), t = '$n $d';
  const marks = ['onenote', 'print to pdf', 'xps', 'pdf', 'send to', 'virtual print', 'snagit', 'image writer', 'document writer', 'anydesk', 'teamviewer', 'splashtop', 'remote printer', 'remote desktop', 'redirected', 'document converter', 'document loader', 'root print'];
  if (marks.any(t.contains)) return true;
  return n == 'fax' || n.endsWith(' fax') || n.contains('(fax)') || d.contains('fax driver') || d.contains('pc-fax') || n.contains('pc-fax');
}

/// The printer a print goes to: the one picked in Settings when it is there; otherwise the computer's default when it makes paper;
/// otherwise the ONLY paper printer. Null when there is no paper printer, or several and none is the default (the program cannot know
/// which one is for bills): it then says so instead of guessing, or of quietly sending the bill to OneNote or Print to PDF.
PrinterInfo? choosePrinter(List<PrinterInfo> all, String wanted) {
  final picked = wanted.isEmpty ? null : all.where((p) => p.name == wanted).firstOrNull;
  if (picked != null) return picked;
  final paper = all.where((p) => p.isPaper).toList();
  return paper.where((p) => p.isDefault).firstOrNull ?? (paper.length == 1 ? paper.single : null);
}

/// sent; noPrinter (no paper printer connected); pickPrinter (several paper printers and none is the default: choose one in Settings);
/// failed.
enum PrintStatus { sent, noPrinter, pickPrinter, failed }

/// What happened when a PDF was sent to a printer: [printer] is the name it went to (empty in the browser, where the person picks).
class PrintOutcome {
  const PrintOutcome(this.status, {this.printer = '', this.viaWindow = false, this.driver = '', this.paperShort = false});
  final PrintStatus status;
  final String printer;

  /// The printer's paper (from its own settings) is smaller than the page: the bottom or the side may be cut off.
  final bool paperShort;

  /// The Windows print window did the printing (the direct way was refused or switched off).
  final bool viaWindow;

  /// The printer's Windows driver (for the diagnostics file).
  final String driver;
}

/// Sends a PDF straight to a printer (no dialog) and lists the printers. The app uses the real one; tests use a stand-in that
/// records what would have been printed and never touches a printer.
abstract class PrinterService {
  Future<List<PrinterInfo>> printers();

  /// Prints [bytes] on the printer called [printerName]; empty or not found: see [choosePrinter].
  /// [viaDialog]: skip the direct way and open the Windows print window (for printers whose driver refuses direct jobs).
  /// [asPicture]: each page is sent as one picture (for printer drivers that take the job but print nothing).
  Future<PrintOutcome> printPdf(Uint8List bytes, {required String jobName, String printerName = '', bool viaDialog = false, bool asPicture = false});
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
      return [for (final p in all) if (p.isAvailable) PrinterInfo(name: p.name, isDefault: p.isDefault, driver: p.model ?? '')];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<PrintOutcome> printPdf(Uint8List bytes, {required String jobName, String printerName = '', bool viaDialog = false, bool asPicture = false}) async {
    try {
      if (asPicture) bytes = await pdfAsPictures(bytes);
      if (kIsWeb) {
        final ok = await Printing.layoutPdf(onLayout: (_) async => bytes, name: jobName);
        return PrintOutcome(ok ? PrintStatus.sent : PrintStatus.failed);
      }
      // the caller has already chosen the printer from the list (see printPdfNow): it is used by its name, without listing the
      // printers again (a switched-off network printer can make the list slow)
      Printer chosen;
      var driver = '';
      if (printerName.isNotEmpty) {
        chosen = Printer(url: printerName, name: printerName);
      } else {
        final all = (await Printing.listPrinters()).where((p) => p.isAvailable).toList();
        final infos = [for (final p in all) PrinterInfo(name: p.name, isDefault: p.isDefault, driver: p.model ?? '')];
        final info = choosePrinter(infos, '');
        if (info == null) return PrintOutcome(infos.any((p) => p.isPaper) ? PrintStatus.pickPrinter : PrintStatus.noPrinter);
        chosen = all.firstWhere((p) => p.name == info.name);
        driver = info.driver;
      }
      final page = pdfPageSize(bytes);
      if (!viaDialog) {
        // first the modern Windows way (print ticket + XPS pipeline, like Word); null = the helper is not installed
        final helped = await printWithHelper(bytes, printerName: chosen.name);
        if (helped == true) return PrintOutcome(PrintStatus.sent, printer: chosen.name, driver: driver);
        try {
          // usePrinterSettings: the printer's OWN settings from its driver (its paper, its quality), exactly as the Windows test page,
          // Word and Edge print. Without it the printing package hands the driver a hand-made setting with an empty driver part and
          // a "custom" paper size, which some drivers cannot take: HP's PCL-3 V4 driver crashed on it (divide by zero in
          // hpygiddrv37.dll, the job stays at 0 pages). The page is drawn at its real size from the paper's corner.
          PdfPageFormat? paper;
          final ok = await Future<bool>.sync(() => Printing.directPrintPdf(
                printer: chosen,
                onLayout: (f) async {
                  paper = f; // the printer's own paper, from its driver
                  return bytes;
                },
                name: jobName,
                usePrinterSettings: true,
              )).timeout(const Duration(seconds: 60)); // a printer Windows cannot open never answers: the print window below is used
          if (ok) return PrintOutcome(PrintStatus.sent, printer: chosen.name, driver: driver, paperShort: _short(paper, page));
        } catch (_) {
          // some drivers (HP "V4" ones) refuse a direct job ("the remote procedure call failed"), or it timed out: the print window prints it
        }
      }
      // the Windows print window opens on the computer's default printer (it cannot be preselected): the person picks the printer there
      final ok = await Printing.layoutPdf(onLayout: (_) async => bytes, name: jobName, usePrinterSettings: true);
      return PrintOutcome(ok ? PrintStatus.sent : PrintStatus.failed, printer: chosen.name, viaWindow: true, driver: driver);
    } catch (_) {
      return const PrintOutcome(PrintStatus.failed);
    }
  }
}

/// True when an A4 or A5 page is clearly bigger than the printer's paper (Letter paper set in Windows, for example). Roll pages are not
/// checked: a receipt printer's own page length says nothing about the roll.
bool _short(PdfPageFormat? paper, ({double width, double height})? page) {
  if (paper == null || page == null || page.width < 400) return false;
  return paper.height < page.height - 8 || paper.width < page.width - 8;
}

/// The size of the first page of a PDF in points (from its MediaBox), or null when it cannot be read.
({double width, double height})? pdfPageSize(Uint8List pdf) {
  final head = latin1.decode(pdf.length > 200000 ? pdf.sublist(0, 200000) : pdf, allowInvalid: true);
  final m = RegExp(r'/MediaBox\s*\[\s*([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s*\]').firstMatch(head);
  if (m == null) return null;
  final v = [for (var i = 1; i <= 4; i++) double.tryParse(m.group(i)!) ?? 0];
  return (width: (v[2] - v[0]).abs(), height: (v[3] - v[1]).abs());
}

/// The same pages, each as one solid picture at [dpi] (the same size on paper). A printer driver then only has to place one image per
/// page, which drivers that stumble on text, see-through parts or drawings still print. One page at a time (a long bill does not fill
/// the memory); the see-through background is laid on white, so nothing can come out black.
Future<Uint8List> pdfAsPictures(Uint8List pdf, {double dpi = 200}) async {
  final out = pw.Document(title: 'Print', creator: 'ASK ERP 2.0', producer: 'ASK ERP 2.0');
  for (var n = 0; n < 500; n++) {
    PdfRaster? page;
    await for (final p in Printing.raster(pdf, pages: [n], dpi: dpi)) {
      page = p;
    }
    if (page == null) break; // past the last page
    final rgb = flattenOnWhite(page.pixels, page.width, page.height);
    final image = PdfImage(out.document, image: rgb, width: page.width, height: page.height, alpha: false);
    out.addPage(pw.Page(
      pageFormat: PdfPageFormat(page.width * 72 / dpi, page.height * 72 / dpi, marginAll: 0),
      build: (_) => pw.SizedBox.expand(child: pw.Image(pw.ImageProxy(image), fit: pw.BoxFit.fill)),
    ));
  }
  return out.save(enableEventLoopBalancing: true);
}

/// RGBA pixels (straight alpha) laid on white paper, as RGB.
Uint8List flattenOnWhite(Uint8List rgba, int width, int height) {
  final n = width * height;
  final out = Uint8List(n * 3);
  for (var i = 0; i < n; i++) {
    final a = rgba[i * 4 + 3];
    for (var c = 0; c < 3; c++) {
      out[i * 3 + c] = (rgba[i * 4 + c] * a + 255 * (255 - a)) ~/ 255;
    }
  }
  return out;
}
