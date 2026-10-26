import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/file_saver.dart';
import '../../data/ids.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain/export/export_table.dart';
import '../../domain/product_sheet/product_sheet.dart';
import '../../domain/product_sheet/sheet_reader.dart';
import '../../fake/data_providers.dart';
import '../../fake/stats.dart';
import '../../fake/store.dart';

/// A sheet the person chose: its name and its bytes.
class PickedSheet {
  PickedSheet(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

Future<PickedSheet?> pickSheetFile() async {
  const types = XTypeGroup(label: 'Excel or CSV', extensions: ['xlsx', 'csv']);
  final f = await openFile(acceptedTypeGroups: [types]);
  if (f == null) return null;
  if (await f.length() > maxSheetFileBytes) throw const SheetReadException('This file is too big to read (more than 25 MB).');
  return PickedSheet(f.name, await f.readAsBytes());
}

/// Overridden in tests so no real file dialog opens.
final sheetPickerProvider = Provider<Future<PickedSheet?> Function()>((ref) => pickSheetFile);

/// The rows of a picked file, from Excel (.xlsx) or CSV text.
List<List<String>> readPickedSheet(PickedSheet s) => s.bytes.length > maxSheetFileBytes ? throw const SheetReadException('This file is too big to read (more than 25 MB).') : s.name.toLowerCase().endsWith('.csv') ? readCsvRows(utf8.decode(s.bytes, allowMalformed: true)) : readXlsxRows(s.bytes);

/// Products page > Excel: download the sheet, upload it filled, see what will change, apply.
Future<void> showProductExcel(BuildContext context) => showDialog<void>(context: context, animationStyle: dialogStyle(context), builder: (_) => const _ExcelDialog());

class _ExcelDialog extends ConsumerStatefulWidget {
  const _ExcelDialog();
  @override
  ConsumerState<_ExcelDialog> createState() => _ExcelDialogState();
}

class _ExcelDialogState extends ConsumerState<_ExcelDialog> {
  String? _saved, _error;
  ProductSheetPlan? _plan;
  String _fileName = '';
  bool _busy = false;

  Future<void> _download() async {
    final l = tr(context);
    final now = ref.read(clockProvider);
    String two(int n) => n.toString().padLeft(2, '0');
    final bytes = encodeXlsx(buildProductSheet(ref.read(productsProvider)));
    final where = await ref.read(fileSaverProvider).save('ASK-ERP-Products-${now.year}-${two(now.month)}-${two(now.day)}.xlsx', bytes);
    if (!mounted) return;
    setState(() {
      _saved = where == null ? null : l.xlSaved(where);
      _error = where == null ? l.xlSaveFailed : null;
    });
  }

  Future<void> _upload() async {
    final l = tr(context);
    final PickedSheet? chosen;
    try {
      chosen = await ref.read(sheetPickerProvider)();
    } on SheetReadException catch (e) {
      if (mounted) setState(() => _error = l.xlReadFailed(e.message));
      return;
    }
    if (chosen == null || !mounted) return;
    final PickedSheet picked = chosen;
    try {
      final rows = readPickedSheet(picked);
      final all = await ref.read(appDataProvider).catalog.products();
      final plan = planProductSheet(rows, all, newId: newId);
      setState(() {
        _plan = plan;
        _fileName = picked.name;
        _error = plan.fatal.isEmpty ? null : plan.fatal;
        _saved = null;
      });
    } on SheetReadException catch (e) {
      setState(() => _error = l.xlReadFailed(e.message));
    } catch (e) {
      setState(() => _error = l.xlReadFailed('$e'));
    }
  }

  Future<void> _apply() async {
    final l = tr(context);
    final plan = _plan;
    if (plan == null || _busy) return;
    setState(() => _busy = true);
    try {
      final d = ref.read(appDataProvider);
      await ref.read(writeQueueProvider).flush(); // anything typed a moment ago is saved first
      await d.catalog.applyProductSheet(plan, at: ref.read(clockProvider), source: 'Excel $_fileName');
      await ref.read(productsProvider.notifier).reloadAll();
      await ref.read(statsProvider.notifier).refresh();
      if (!mounted) return;
      final msg = l.xlDone(plan.updates.toString(), plan.creates.toString(), plan.stockChanges.toString());
      Navigator.pop(context);
      toast(context, msg);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l.xlApplyFailed('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final c = context.c;
    final plan = _plan;
    final changed = plan?.rows.where((r) => r.status == SheetRowStatus.update || r.status == SheetRowStatus.create).toList() ?? const [];
    final bad = plan?.rows.where((r) => r.status == SheetRowStatus.error).toList() ?? const [];
    final warn = plan?.rows.where((r) => r.warnings.isNotEmpty && r.status != SheetRowStatus.error).toList() ?? const [];
    Widget line(String text, {Color? color}) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(text, style: th.bodySmall?.copyWith(color: color)));
    return AlertDialog(
      title: Text(l.xlTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.xlIntro, style: th.bodyMedium),
            const SizedBox(height: 8),
            Text(l.xlHow, style: th.bodySmall),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(key: const ValueKey('xlDownload'), onPressed: _busy ? null : _download, icon: const Icon(Icons.file_download_rounded), label: Text(l.xlDownload)),
              FilledButton.icon(key: const ValueKey('xlUpload'), onPressed: _busy ? null : _upload, icon: const Icon(Icons.upload_file_rounded), label: Text(l.xlUpload)),
            ]),
            if (_saved != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_saved!, key: const ValueKey('xlSaved'), style: th.bodySmall?.copyWith(color: c.success))),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const ValueKey('xlError'), style: th.bodyMedium?.copyWith(color: c.danger))),
            if (plan != null && plan.fatal.isEmpty) ...[
              const Divider(height: 24),
              Text('${l.xlPreview}  -  $_fileName', style: th.titleSmall),
              const SizedBox(height: 4),
              Text(l.xlCounts(plan.updates.toString(), plan.creates.toString(), plan.unchanged.toString(), plan.errors.toString()), key: const ValueKey('xlCounts'), style: th.bodyMedium),
              if (plan.stockChanges > 0) Text(l.xlStockCounts(plan.stockChanges.toString()), style: th.bodySmall),
              if (!plan.hasWork) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.xlNothing, style: th.bodyMedium)),
              const SizedBox(height: 8),
              for (final r in changed.take(8)) line('${l.xlRow(r.rowNo.toString())}: ${r.label}: ${r.changes.join(', ')}'),
              if (changed.length > 8) line(l.xlMore((changed.length - 8).toString())),
              if (warn.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l.xlWarnings(warn.length.toString()), style: th.titleSmall?.copyWith(color: c.warning)),
                for (final r in warn.take(5)) line('${l.xlRow(r.rowNo.toString())}: ${r.label}: ${r.warnings.join(' ')}', color: c.warning),
                if (warn.length > 5) line(l.xlMore((warn.length - 5).toString())),
              ],
              if (bad.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l.xlProblems, style: th.titleSmall?.copyWith(color: c.danger)),
                for (final r in bad.take(10)) line('${l.xlRow(r.rowNo.toString())}: ${r.label.isEmpty ? '' : '${r.label}: '}${r.problems.join(' ')}', color: c.danger),
                if (bad.length > 10) line(l.xlMore((bad.length - 10).toString())),
              ],
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l.cancel)),
        if (plan != null && plan.hasWork) FilledButton(key: const ValueKey('xlApply'), onPressed: _busy ? null : _apply, child: Text(l.xlApply((plan.updates + plan.creates).toString()))),
      ],
    );
  }
}
