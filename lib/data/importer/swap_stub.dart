import 'swap_types.dart';

Future<void> requestImportSwap({required String dataDir, required String newFile, required Map<String, int> expected, required String source}) async => throw UnsupportedError('Swapping data needs the Windows or Mac program.');
Future<void> requestRestore({required String dataDir, required String backupFile, required String source}) async => throw UnsupportedError('Restoring needs the Windows or Mac program.');
Future<void> requestGoBack({required String dataDir, required String stamp}) async => throw UnsupportedError('Swapping data needs the Windows or Mac program.');
Future<SwapResult?> applyPendingSwap(String dataDir, {DateTime? now}) async => null;
Future<List<PreviousData>> previousData(String dataDir, {DateTime? now}) async => const [];
Future<SwapResult?> lastSwapResult(String dataDir) async => null;
Future<void> clearSwapResult(String dataDir) async {}
