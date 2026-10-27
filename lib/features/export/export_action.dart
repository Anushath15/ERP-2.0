import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/file_saver.dart';
import '../../design/widgets.dart';
import '../../data/repo/export_repo.dart';
import '../../data/repo/gst_return_repo.dart';
import '../../domain/export/export_table.dart';
import '../../fake/data_providers.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart' show clockProvider;
import 'export_pdf.dart';

enum ExportFormat { excel, csv, pdf }

/// Builds one table from the shop database, writes it as Excel, CSV or PDF and saves it (Downloads/ASK ERP 2.0 on a computer, a
/// normal download in the browser). Returns the saved path or file name; null when nothing was saved. Tells the person either way.
Future<String?> runExport(BuildContext context, WidgetRef ref, ExportKind kind, ExportFormat format) async {
  final l = tr(context);
  try {
    final table = await buildExport(ref.read(appDataProvider), kind);
    if (!context.mounted) return null;
    if (table.rows.isEmpty) {
      toast(context, l.exportEmpty);
      return null;
    }
    final now = ref.read(clockProvider);
    final Uint8List bytes;
    final String ext;
    switch (format) {
      case ExportFormat.excel:
        bytes = encodeXlsx(table);
        ext = 'xlsx';
      case ExportFormat.csv:
        bytes = encodeCsv(table);
        ext = 'csv';
      case ExportFormat.pdf:
        bytes = await encodePdf(table, shopName: ref.read(shopProvider).name, now: now, shop: ref.read(shopProvider));
        ext = 'pdf';
    }
    final where = await ref.read(fileSaverProvider).save(exportFileName(table, ext, now), bytes);
    if (!context.mounted) return where;
    if (where == null) {
      toast(context, l.exportFailed);
      return null;
    }
    toast(context, format == ExportFormat.pdf && table.rows.length > maxPdfRows ? '${l.exportSaved(ext.toUpperCase(), where)} ${l.exportCapped(maxPdfRows.toString())}' : l.exportSaved(ext.toUpperCase(), where));
    return where;
  } catch (_) {
    if (context.mounted) toast(context, l.exportFailed);
    return null;
  }
}

/// The auditor pack of a period ([from] inclusive to [to] exclusive): every bill and its items, GST by rate, HSN summary, credit notes, cancelled
/// bills, purchases and a bill-number check. Excel: one sheet each; PDF: all in one file.
Future<String?> runAuditExport(BuildContext context, WidgetRef ref, DateTime from, DateTime to, String label, ExportFormat format) async {
  final l = tr(context);
  try {
    final shop = ref.read(shopProvider);
    toast(context, l.auditWorking);
    final pack = await ref.read(appDataProvider).audit.pack(from, to, label: label, shopName: shop.name, shopGstin: shop.gstin);
    if (!context.mounted) return null;
    final now = ref.read(clockProvider);
    final Uint8List bytes;
    final String ext;
    if (format == ExportFormat.pdf) {
      bytes = await encodePdfBook(pack.tables, title: 'Auditor pack  -  $label', shopName: shop.name, now: now, shop: shop, sectionTitles: true, headerLines: pack.headerLines);
      ext = 'pdf';
    } else {
      bytes = encodeXlsxBook(pack.tables);
      ext = 'xlsx';
    }
    final safe = label.replaceAll(RegExp(r'[^A-Za-z0-9-]+'), ' ').trim();
    final where = await ref.read(fileSaverProvider).save('Auditor pack $safe.$ext', bytes);
    if (!context.mounted) return where;
    toast(context, where == null ? l.exportFailed : l.exportSaved(ext.toUpperCase(), where));
    return where;
  } catch (_) {
    if (context.mounted) toast(context, l.exportFailed);
    return null;
  }
}

enum GstReturnKind { gstr1, gstr3b, hsn }

/// A month's GST return (GSTR-1 with its parts, GSTR-3B, or the HSN summary) as Excel (one sheet for each part) or PDF (all parts in one file), saved like the other exports.
Future<String?> runGstExport(BuildContext context, WidgetRef ref, DateTime month, GstReturnKind kind, ExportFormat format) async {
  final l = tr(context);
  try {
    final shop = ref.read(shopProvider);
    final data = await ref.read(appDataProvider).gst.month(month, shopGstin: shop.gstin);
    if (!context.mounted) return null;
    final tables = switch (kind) { GstReturnKind.gstr1 => gstr1Tables(data), GstReturnKind.gstr3b => [gstr3bTable(data)], GstReturnKind.hsn => [hsnTable(data)] };
    final title = switch (kind) { GstReturnKind.gstr1 => 'GSTR-1', GstReturnKind.gstr3b => 'GSTR-3B', GstReturnKind.hsn => 'HSN summary' };
    final now = ref.read(clockProvider);
    final stamp = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final Uint8List bytes;
    final String ext;
    if (format == ExportFormat.pdf) {
      bytes = await encodePdfBook(tables, title: '$title  -  ${data.label}', shopName: shop.name, now: now, shop: shop, sectionTitles: tables.length > 1, headerLines: ['Return period: ${data.label}']);
      ext = 'pdf';
    } else {
      bytes = encodeXlsxBook(tables);
      ext = 'xlsx';
    }
    final where = await ref.read(fileSaverProvider).save('$title $stamp.$ext', bytes);
    if (!context.mounted) return where;
    toast(context, where == null ? l.exportFailed : l.exportSaved(ext.toUpperCase(), where));
    return where;
  } catch (_) {
    if (context.mounted) toast(context, l.exportFailed);
    return null;
  }
}