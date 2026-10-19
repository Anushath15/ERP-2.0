/// Making, checking, listing, trimming and copying backup files (desktop). A backup is a consistent snapshot of the live database made by SQLite itself
/// (`VACUUM INTO`, from a separate read connection, so billing carries on and the file is never a raw copy of a live log). It is written under a temporary
/// name, checked, and only then given its real name, so a half-made backup can never be mistaken for a good one.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import '../db/app_database.dart';
import '../platform/disk_space.dart';
import 'backup_crypto.dart';
import 'backup_types.dart';

const bool backupSupported = true;

/// Tests of the screens run the backup work in the same isolate (the test clock cannot wait for another isolate). The program never sets this.
bool runBackupWorkInline = false;

Future<T> _work<T>(T Function() job) => runBackupWorkInline ? Future<T>.sync(job) : Isolate.run(job);

const _fullCheckBelowBytes = 500 * 1024 * 1024;

class _Args {
  _Args(this.live, this.folder, this.device, this.version, this.kind, this.fy, this.now);
  final String live, folder, device, version, kind, fy;
  final DateTime now;
}

/// Makes one backup of [livePath] into [folder]. Throws [BackupException] with a plain-English reason. Runs away from the screen.
Future<BackupInfo> createBackup({required String livePath, required String folder, required String deviceId, required String appVersion, BackupKind kind = BackupKind.auto, String fy = '', DateTime? now, int? freeBytesOverride}) async {
  final live = File(livePath);
  if (!live.existsSync()) throw BackupException('There is no data file to back up yet.');
  try {
    Directory(folder).createSync(recursive: true);
  } on FileSystemException {
    throw BackupException('The backup folder cannot be used. If it is on a pen drive or another drive, check that it is plugged in, or choose another folder.');
  }
  final need = live.lengthSync() + 100 * 1024 * 1024;
  final free = freeBytesOverride ?? await freeDiskBytes(folder);
  if (free != null && free < need) {
    throw BackupException('There is not enough free space for a backup in that folder (needs about ${(need / (1024 * 1024)).round()} MB, ${(free / (1024 * 1024)).round()} MB free). Your data is safe. Free some space or choose another folder.');
  }
  try {
    return await _work(() => _create(_Args(livePath, folder, deviceId, appVersion, kind.name, fy, now ?? DateTime.now())));
  } on BackupException {
    rethrow;
  } on Object catch (e) {
    throw BackupException('The backup could not be made ($e). Your data is safe.');
  }
}

BackupInfo _create(_Args a) {
  final kind = BackupKind.values.firstWhere((k) => k.name == a.kind);
  final name = BackupInfo.fileName(at: a.now, device: a.device, appVersion: a.version, kind: kind, fy: a.fy);
  final finalPath = p.join(a.folder, name);
  final tmp = p.join(a.folder, '$name.part');
  for (final f in Directory(a.folder).listSync().whereType<File>()) {
    if (f.path.endsWith('.part')) {
      try {
        f.deleteSync(); // a half-made backup from an earlier crash
      } catch (_) {}
    }
  }
  if (File(finalPath).existsSync()) throw BackupException('A backup with this name already exists.');
  Database? src;
  try {
    src = sqlite3.open(a.live, mode: OpenMode.readOnly);
    src.execute('PRAGMA busy_timeout = 15000');
    src.execute('VACUUM INTO ?', [tmp]);
  } on SqliteException catch (e) {
    _drop(tmp);
    throw BackupException('The backup could not be made because the data file is busy or unreadable (${e.message}). Your data is safe. It will be tried again.');
  } finally {
    src?.close();
  }
  Database? snap;
  late int schema, products, customers, bills;
  int? lastBill;
  String shopId = '';
  try {
    snap = sqlite3.open(tmp);
    snap.execute('PRAGMA journal_mode = DELETE');
    schema = snap.select('PRAGMA user_version').first.values.first as int;
    int n(String t) => snap!.select('SELECT COUNT(*) FROM $t').first.values.first as int;
    products = n('products');
    customers = n('customers');
    bills = n('bills');
    final lb = snap.select('SELECT MAX(billed_at) FROM bills').first.values.first;
    lastBill = lb as int?;
    final sid = snap.select("SELECT value FROM kv WHERE name = 'shop.id'");
    shopId = sid.isEmpty ? '' : sid.first.values.first as String;
    final meta = jsonEncode({'at': a.now.toIso8601String(), 'device': a.device, 'appVersion': a.version, 'kind': a.kind, 'schema': schema, 'shopId': shopId, 'products': products, 'customers': customers, 'bills': bills, 'lastBill': lastBill, 'fy': a.fy});
    snap.execute("INSERT INTO kv(name, value, updated_at) VALUES ('backup.meta', ?, ?) ON CONFLICT(name) DO UPDATE SET value = excluded.value", [meta, a.now.millisecondsSinceEpoch]);
  } catch (e) {
    snap?.close();
    _drop(tmp);
    throw BackupException('The backup file could not be prepared ($e). Your data is safe.');
  } finally {
    snap?.close();
  }
  // verify the snapshot as a separate read before it earns its name
  final bad = _verifyFile(tmp, expectBills: bills, expectProducts: products, expectCustomers: customers);
  if (bad != null) {
    _drop(tmp);
    throw BackupException('The new backup did not pass its check ($bad), so it was thrown away. Your data is safe. It will be tried again.');
  }
  File(tmp).renameSync(finalPath);
  return BackupInfo(path: finalPath, name: name, at: a.now, device: a.device, appVersion: a.version, kind: kind, fy: a.fy, bytes: File(finalPath).lengthSync());
}

void _drop(String path) {
  for (final s in ['', '-journal', '-wal', '-shm']) {
    final f = File('$path$s');
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }
}

String? _verifyFile(String path, {int? expectBills, int? expectProducts, int? expectCustomers}) {
  Database? db;
  try {
    db = sqlite3.open(path, mode: OpenMode.readOnly);
    final full = File(path).lengthSync() < _fullCheckBelowBytes;
    final c = db.select(full ? 'PRAGMA integrity_check' : 'PRAGMA quick_check');
    if (c.length != 1 || c.first.values.first != 'ok') return 'the integrity check failed';
    int n(String t) => db!.select('SELECT COUNT(*) FROM $t').first.values.first as int;
    if (expectBills != null && n('bills') != expectBills) return 'the number of bills differs';
    if (expectProducts != null && n('products') != expectProducts) return 'the number of products differs';
    if (expectCustomers != null && n('customers') != expectCustomers) return 'the number of customers differs';
    return null;
  } catch (e) {
    return 'it could not be opened again';
  } finally {
    db?.close();
  }
}

/// Our backups in [folder], newest first. Files with other names are ignored.
List<BackupInfo> listBackups(String folder) {
  final d = Directory(folder);
  if (!d.existsSync()) return const [];
  final out = <BackupInfo>[];
  for (final f in d.listSync().whereType<File>()) {
    final info = BackupInfo.fromName(f.path, p.basename(f.path), bytes: f.lengthSync());
    if (info != null) out.add(info);
  }
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}

/// Removes the backups the rotation no longer keeps (7 days, 4 weeks, 12 months). The newest backup is verified first and nothing is removed if it is not good.
/// Returns the names removed.
Future<List<String>> rotateBackups(String folder) async {
  final all = listBackups(folder);
  final keep = backupsToKeep(all);
  if (keep.isEmpty) return const [];
  final newest = all.where((b) => b.kind == BackupKind.auto || b.kind == BackupKind.manual || b.kind == BackupKind.closing).first;
  if (await _work(() => _verifyFile(newest.path)) != null) return const [];
  final removed = <String>[];
  for (final b in all) {
    if ((b.kind == BackupKind.auto || b.kind == BackupKind.manual || b.kind == BackupKind.closing) && !keep.contains(b.name)) {
      try {
        File(b.path).deleteSync();
        removed.add(b.name);
      } catch (_) {}
    }
  }
  return removed;
}

/// Looks inside a file before it is restored. Never changes it.
Future<BackupInspection> inspectBackup(String path, {required String expectedShopId}) => _work(() => _inspect(path, expectedShopId));

BackupInspection _inspect(String path, String expectedShopId) {
  Database? db;
  try {
    final f = File(path);
    if (!f.existsSync()) return const BackupInspection(RestoreProblem.notDatabase, detail: 'The file was not found.');
    final head = f.openSync()..setPositionSync(0);
    final magic = head.readSync(16);
    head.closeSync();
    if (utf8.decode(magic, allowMalformed: true) != 'SQLite format 3\u0000') return const BackupInspection(RestoreProblem.notDatabase);
    db = sqlite3.open(path, mode: OpenMode.readOnly);
    final schema = db.select('PRAGMA user_version').first.values.first as int;
    if (schema > currentSchemaVersion) return BackupInspection(RestoreProblem.tooNew, detail: 'data version $schema, this program understands up to $currentSchemaVersion');
    final full = f.lengthSync() < _fullCheckBelowBytes;
    final c = db.select(full ? 'PRAGMA integrity_check' : 'PRAGMA quick_check');
    if (c.length != 1 || c.first.values.first != 'ok') return const BackupInspection(RestoreProblem.corrupt);
    final sid = db.select("SELECT value FROM kv WHERE name = 'shop.id'");
    final shopId = sid.isEmpty ? '' : sid.first.values.first as String;
    int n(String t) => db!.select('SELECT COUNT(*) FROM $t WHERE deleted_at IS NULL').first.values.first as int;
    final bills = db.select('SELECT COUNT(*), MAX(billed_at) FROM bills').first.values;
    DateTime? madeAt;
    var device = '', ver = '';
    final meta = db.select("SELECT value FROM kv WHERE name = 'backup.meta'");
    if (meta.isNotEmpty) {
      final j = jsonDecode(meta.first.values.first as String) as Map<String, dynamic>;
      madeAt = DateTime.tryParse('${j['at']}');
      device = '${j['device'] ?? ''}';
      ver = '${j['appVersion'] ?? ''}';
    }
    final contents = BackupContents(products: n('products'), customers: n('customers'), bills: bills[0] as int, lastBill: bills[1] == null ? null : DateTime.fromMillisecondsSinceEpoch(bills[1] as int), madeAt: madeAt, device: device, appVersion: ver, schema: schema, shopId: shopId);
    if (shopId.isEmpty) return BackupInspection(RestoreProblem.unknownShop, contents: contents);
    if (expectedShopId.isNotEmpty && shopId != expectedShopId) return BackupInspection(RestoreProblem.otherShop, contents: contents);
    return BackupInspection(RestoreProblem.none, contents: contents);
  } on SqliteException {
    return const BackupInspection(RestoreProblem.corrupt);
  } catch (_) {
    return const BackupInspection(RestoreProblem.corrupt);
  } finally {
    db?.close();
  }
}

/// Copies [source] into [destFolder] (a pen drive, another folder) and proves the copy is identical by comparing SHA-256 of both. Returns the copy's path.
Future<String> copyBackupTo(String source, String destFolder) async {
  try {
    Directory(destFolder).createSync(recursive: true);
  } on FileSystemException {
    throw BackupException('That folder cannot be used. Check that the pen drive is plugged in, or choose another folder.');
  }
  final dest = p.join(destFolder, p.basename(source));
  final src = File(source);
  final need = src.lengthSync() + 10 * 1024 * 1024;
  final free = await freeDiskBytes(destFolder);
  if (free != null && free < need) throw BackupException('There is not enough free space in that folder for the copy.');
  final tmp = '$dest.part';
  try {
    await src.copy(tmp);
    final a = await sha256.bind(src.openRead()).first;
    final b = await sha256.bind(File(tmp).openRead()).first;
    if (a != b) {
      File(tmp).deleteSync();
      throw BackupException('The copy did not match the original, so it was thrown away. Try again or choose another place.');
    }
    File(tmp).renameSync(dest);
    return dest;
  } on FileSystemException catch (e) {
    _drop(tmp);
    throw BackupException('The copy could not be made (${e.message}).');
  }
}

/// Tries a folder before it is chosen for backups: it is made if needed, a small file is written and removed. Throws a plain-English [BackupException].
Future<void> tryFolder(String path) async {
  try {
    final d = Directory(path)..createSync(recursive: true);
    final probe = File(p.join(d.path, '.write-test'));
    probe.writeAsStringSync('ok', flush: true);
    probe.deleteSync();
  } on FileSystemException {
    throw BackupException('That folder cannot be written to. If it is on a pen drive or another drive, check that it is plugged in and not write-protected.');
  }
}

/// The backup file [path] compressed and locked with [password], ready to leave this computer (done away from the screen: locking takes a second or two).
Future<Uint8List> sealBackupFile(String path, String password, {int rounds = defaultRounds}) {
  Future<Uint8List> job() async => sealBackup(File(path).readAsBytesSync(), password, rounds: rounds);
  return runBackupWorkInline ? job() : Isolate.run(job);
}

/// Opens a locked backup file and writes the plain backup to a new file in the computer's temp folder, named like the original without `.askbak`.
/// Returns that path. Throws [SealException] (wrong password, damaged, not one of ours).
Future<String> openSealedBackupToTemp(String path, String password) async {
  final data = File(path).readAsBytesSync();
  Future<Uint8List> job() async => openSealedBackup(data, password);
  final plain = await (runBackupWorkInline ? job() : Isolate.run(job));
  final dir = Directory.systemTemp.createTempSync('askerp-restore-');
  var name = p.basename(path);
  if (name.endsWith('.askbak')) name = name.substring(0, name.length - '.askbak'.length);
  if (!name.endsWith('.sqlite')) name = '$name.sqlite';
  final out = File(p.join(dir.path, name));
  out.writeAsBytesSync(plain, flush: true);
  return out.path;
}
