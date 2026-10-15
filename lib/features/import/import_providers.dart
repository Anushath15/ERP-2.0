import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/importer/swap.dart';
import '../../data/repo/report_repo.dart';
import '../../fake/data_providers.dart';
import '../../fake/health.dart';
import '../../import/erp1/outcome.dart';
import '../../import/erp1/preview.dart';
import '../../import/erp1/runner.dart' as real;

/// A backup file the owner chose: its name and a way to read its text. The file is only ever read.
class PickedBackup {
  PickedBackup(this.name, this.read, {this.bytes = 0});
  final String name;
  final Future<String> Function() read;
  final int bytes;
}

const maxBackupBytes = 1500 * 1024 * 1024;

Future<PickedBackup?> pickBackupFile() async {
  const types = XTypeGroup(label: 'ERP 1 backup', extensions: ['json']);
  final f = await openFile(acceptedTypeGroups: [types]);
  if (f == null) return null;
  return PickedBackup(f.name, f.readAsString, bytes: await f.length());
}

/// Overridden in tests so no real file dialog or background isolate is needed.
final backupPickerProvider = Provider<Future<PickedBackup?> Function()>((ref) => pickBackupFile);

class ImportRunner {
  const ImportRunner();
  bool get supported => real.importSupported;
  Future<ImportPreview> preview(String text, String name) => real.previewInBackground(text, name);
  Future<ImportOutcome> create(String text, String name, String outPath, void Function(String stage) onStage) => real.writeNewShopFile(text: text, fileName: name, outPath: outPath, onStage: onStage);
}

final importRunnerProvider = Provider<ImportRunner>((ref) => const ImportRunner());

final shopCountsProvider = FutureProvider.autoDispose<ShopCounts>((ref) => ref.watch(appDataProvider).reports.shopCounts());

/// What happened at the last start-up data switch (an import or a go-back), for the Health page.
final swapResultProvider = FutureProvider.autoDispose<SwapResult?>((ref) async {
  final dir = ref.watch(dataDirProvider);
  return dir == null ? null : lastSwapResult(dir);
});

/// The earlier data sets that can still be gone back to (30 days).
final previousDataProvider = FutureProvider.autoDispose<List<PreviousData>>((ref) async {
  final dir = ref.watch(dataDirProvider);
  return dir == null ? const [] : previousData(dir);
});
