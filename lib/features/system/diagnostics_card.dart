import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_info.dart';
import '../../core/cloud/sync_controller.dart';
import '../../core/diag/diag_log.dart';
import '../../core/file_saver.dart';
import '../../core/printer_service.dart';
import '../../data/db/app_database.dart' show currentSchemaVersion;
import '../../design/widgets.dart';
import '../../fake/data_providers.dart';
import '../../fake/store.dart';

/// Everything the diagnostics file says, collected from this computer. Counts and settings only.
Future<String> collectDiagnostics(WidgetRef ref) async {
  final facts = <String, Object?>{'program': appVersionLabel, 'data version': currentSchemaVersion, ...systemFacts()};
  try {
    final d = ref.read(appDataProvider);
    final c = await d.reports.shopCounts();
    facts['products'] = c.products;
    facts['customers'] = c.customers;
    facts['dealers'] = c.dealers;
    facts['bills'] = c.bills;
    facts['last bill'] = c.lastBill?.toIso8601String() ?? '-';
    final o = await d.outbox.counts();
    facts['waiting to send'] = o.pending;
    facts['needs attention'] = o.attention;
  } catch (e) {
    facts['database'] = 'could not be read: ${e.runtimeType}';
  }
  final sync = ref.read(syncProvider);
  facts['cloud sync'] = sync.active ? sync.phase.name : 'off';
  facts['last sync'] = sync.last?.toIso8601String() ?? '-';
  facts['next sync try'] = sync.nextTry?.toIso8601String() ?? '-';
  final s = ref.read(settingsProvider);
  facts['paper'] = s.paper.name;
  facts['printer chosen'] = s.printerName.isEmpty ? '(Windows default)' : s.printerName;
  facts['use Windows print window'] = s.printViaDialog;
  facts['print after save'] = s.printAfterSave;
  try {
    final printers = await ref.read(printerServiceProvider).printers();
    facts['printers found'] = printers.map((p) => '${p.name}${p.isDefault ? ' (default)' : ''}').join('; ');
  } catch (e) {
    facts['printers found'] = 'could not be listed: ${e.runtimeType}';
  }
  return buildDiagnosticsText(now: ref.read(clockProvider), facts: facts, log: ref.read(diagProvider).recent(300));
}

/// Settings > Help and diagnostics: one button that saves the diagnostics file.
class DiagnosticsCard extends ConsumerWidget {
  const DiagnosticsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    return SectionCard(
      title: l.diagTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.diagHelp, style: th.bodySmall),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('diagSave'),
          icon: const Icon(Icons.medical_information_rounded),
          label: Text(l.diagSave),
          onPressed: () async {
            final now = ref.read(clockProvider);
            String two(int n) => n.toString().padLeft(2, '0');
            final text = await collectDiagnostics(ref);
            final where = await ref.read(fileSaverProvider).save('ASK-ERP-diagnostics-${now.year}-${two(now.month)}-${two(now.day)}.txt', Uint8List.fromList(diagnosticsBytes(text)));
            if (context.mounted) toast(context, where == null ? l.diagFailed : l.diagSaved(where));
          },
        ),
        const SizedBox(height: 14),
        Text(l.dbTidyHelp, style: th.bodySmall),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('dbTidy'),
          icon: const Icon(Icons.cleaning_services_rounded),
          label: Text(l.dbTidy),
          onPressed: () async {
            try {
              final r = await ref.read(writeQueueProvider).run(() => ref.read(appDataProvider).db.maintain());
              ref.read(diagProvider).event('db', 'tidy', {'before': r.before, 'after': r.after});
              if (context.mounted) toast(context, l.dbTidyDone(_size(r.before), _size(r.after)));
            } catch (e) {
              ref.read(diagProvider).error('db', e);
              if (context.mounted) toast(context, l.dbTidyFailed);
            }
          },
        ),
      ]),
    );
  }

  static String _size(int bytes) => bytes >= 1024 * 1024 ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB' : '${(bytes / 1024).toStringAsFixed(0)} KB';
}
