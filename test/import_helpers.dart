import 'dart:convert';
import 'dart:io';
import 'package:erp2/features/import/import_providers.dart';
import 'package:erp2/import/erp1/outcome.dart';
import 'package:erp2/import/erp1/preview.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:erp2/fake/health.dart';
import '../tool/import/synthetic.dart';

/// A runner that works in-process (no isolate, no disk) so widget tests control time. [delay] stands in for a slow big file.
class FakeRunner extends ImportRunner {
  FakeRunner({this.delay = Duration.zero, this.createdCounts = const {'products': 80, 'customers': 12, 'bills': 60, 'dealers': 3, 'estimates': 1}, this.createOk = true});
  final Duration delay;
  final Map<String, int> createdCounts;
  final bool createOk;
  int previews = 0, creates = 0;

  @override
  bool get supported => true;

  @override
  Future<ImportPreview> preview(String text, String name) async {
    previews++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return previewFromText(text, name);
  }

  @override
  Future<ImportOutcome> create(String text, String name, String outPath, void Function(String stage) onStage) async {
    creates++;
    onStage('writing');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return createOk
        ? ImportOutcome(ok: true, newFile: outPath, verified: true, integrity: 'ok', counts: createdCounts)
        : ImportOutcome(ok: true, newFile: outPath, verified: false, mismatches: const ['sales total (paise): database has 1, the backup says 2'], integrity: 'ok', counts: createdCounts);
  }
}

String syntheticBackup({int bills = 60, bool tamper = false}) {
  final m = Synthetic(bills: bills, products: 80, customers: 12, dealers: 3, flaws: false).build();
  if (tamper) {
    final inv = (m['data'] as Map<String, Object?>)['erp_sales_invoices']! as List<Object?>;
    (inv[3]! as Map<String, Object?>)['totalAmount'] = 1.0;
  }
  return jsonEncode(m);
}

Override pickerReturning(String name, String text) => backupPickerProvider.overrideWithValue(() async => PickedBackup(name, () async => text, bytes: text.length));

/// The overrides the Import page needs in a test: a data folder (so the page is available), a slow fake runner and a file picker.
List<Override> importOverrides({FakeRunner? runner, String? text, String name = 'backup.json', String? dataDir}) => [
      dataDirProvider.overrideWithValue(dataDir ?? '${Directory.systemTemp.path}/erp2-import-test'),
      importRunnerProvider.overrideWithValue(runner ?? FakeRunner(delay: const Duration(milliseconds: 900))),
      pickerReturning(name, text ?? syntheticBackup()),
    ];
