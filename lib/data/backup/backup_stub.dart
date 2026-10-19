import 'dart:typed_data';
import 'backup_crypto.dart';
import 'backup_types.dart';

/// The browser build keeps its data inside the browser; file backups need the desktop program.
const bool backupSupported = false;

Future<BackupInfo> createBackup({required String livePath, required String folder, required String deviceId, required String appVersion, BackupKind kind = BackupKind.auto, String fy = '', DateTime? now, int? freeBytesOverride}) async => throw BackupException('Backups need the Windows or Mac program.');
List<BackupInfo> listBackups(String folder) => const [];
Future<List<String>> rotateBackups(String folder) async => const [];
Future<BackupInspection> inspectBackup(String path, {required String expectedShopId}) async => const BackupInspection(RestoreProblem.notDatabase);
Future<String> copyBackupTo(String source, String destFolder) async => throw BackupException('Backups need the Windows or Mac program.');
Future<void> tryFolder(String path) async => throw BackupException('Backups need the Windows or Mac program.');
bool runBackupWorkInline = false;
Future<Uint8List> sealBackupFile(String path, String password, {int rounds = defaultRounds}) async => throw BackupException('Backups need the Windows or Mac program.');
Future<String> openSealedBackupToTemp(String path, String password) async => throw BackupException('Backups need the Windows or Mac program.');
