import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/file_saver.dart';
import '../../design/widgets.dart';
import '../../data/repo/export_repo.dart';
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
        bytes = await encodePdf(table, shopName: ref.read(shopProvider).name, now: now);
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
