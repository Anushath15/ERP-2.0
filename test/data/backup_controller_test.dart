import 'dart:io';
import 'package:erp2/core/app_paths_io.dart';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/backup/backup.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/app_database.dart';
import 'package:erp2/data/db/open.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/fake/backup_controller.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'helpers.dart';

void main() {
  late Directory dir;
  late AppDatabase db;
  late AppData d;
  late ProviderContainer c;
  late FileAppPaths paths;
  late String live;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('bkctl');
    paths = FileAppPaths(p.join(dir.path, 'ASK ERP 2.0'));
    live = paths.dbLocation('shop');
    db = await openShopDatabase(live);
    d = AppData(DataContext(db: db, deviceId: 'dev-test'));
    d.bills.series = 'A';
    await d.settings.put('shop.id', 'shop-A');
    await d.catalog.saveProduct(sampleProduct('Pipe', id: 'p1'), create: true);
    c = ProviderContainer(overrides: [
      appPathsProvider.overrideWithValue(paths),
      dbFilePathProvider.overrideWithValue(live),
      appDataProvider.overrideWithValue(d),
      deviceIdProvider.overrideWithValue('abcdef12-0000'),
    ]);
    // backups go inside the temp folder (never the real Documents folder)
    await paths.writeText('backup.folder', p.join(dir.path, 'Backups'));
    await c.read(backupControllerProvider.notifier).load();
  });

  tearDown(() async {
    c.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> makeBill() => d.bills.saveBill(SaveBillInput(idemKey: 'k${DateTime.now().microsecondsSinceEpoch}', at: DateTime.now(), lines: const [BillLineInput(productId: 'p1', name: 'Pipe', unit: 'pcs', qtyMilli: 1000, ratePaise: 15000, gstBp: 1800)]));

  test('the schedule: nothing with no bills; the first bill of the day makes a backup; then only 2-hourly and only when something changed', () async {
    final ctl = c.read(backupControllerProvider.notifier);
    await ctl.tick();
    expect(listBackups(c.read(backupControllerProvider).folder!), isEmpty, reason: 'no bills yet: nothing to protect');

    await makeBill();
    await ctl.tick();
    var list = listBackups(c.read(backupControllerProvider).folder!);
    expect(list, hasLength(1), reason: 'the first bill of the day');
    final firstName = list.single.name;
    expect(c.read(backupControllerProvider).last, isNotNull);
    expect(await paths.readText('backup.last'), isNotNull, reason: 'the time is kept on this computer, outside the data');

    await ctl.tick();
    expect(listBackups(c.read(backupControllerProvider).folder!), hasLength(1), reason: 'same day, nothing new');

    // three hours later with no new save: still nothing
    await ctl.tick(now: DateTime.now().add(const Duration(hours: 3)));
    expect(listBackups(c.read(backupControllerProvider).folder!), hasLength(1));

    // a new save, and two hours pass: a new backup
    await makeBill();
    await Future<void>.delayed(const Duration(milliseconds: 1100)); // file names carry seconds
    await ctl.tick(now: DateTime.now().add(const Duration(hours: 3)));
    list = listBackups(c.read(backupControllerProvider).folder!);
    expect(c.read(backupControllerProvider).lastError, isNull);
    expect(list, hasLength(1), reason: 'the rotation keeps one backup per day: the newer one replaces the earlier one of the same day');
    expect(list.single.name, isNot(firstName), reason: 'a new backup WAS made');
  });

  test('a failed backup says why in plain words, keeps the time of the last good one, and the next try can work', () async {
    final ctl = c.read(backupControllerProvider.notifier);
    expect(await ctl.run(BackupKind.manual), isTrue);
    final good = c.read(backupControllerProvider).last;
    // the backup folder becomes unusable (a file where the folder should be, like a pen drive that was unplugged)
    final blocker = File(p.join(dir.path, 'blocker'))..writeAsStringSync('x');
    await paths.writeText('backup.folder', p.join(blocker.path, 'sub'));
    await ctl.load();
    expect(await ctl.run(BackupKind.manual), isFalse);
    final s = c.read(backupControllerProvider);
    expect(s.lastError, contains('backup folder cannot be used'));
    expect(s.last!.millisecondsSinceEpoch, good!.millisecondsSinceEpoch, reason: 'the last GOOD backup is still the one shown');
    expect(s.running, isFalse);
    ctl.dismissError();
    expect(c.read(backupControllerProvider).lastError, isNull);
  });

  test('choosing a folder: only a folder that can be written to is saved', () async {
    final ctl = c.read(backupControllerProvider.notifier);
    final blocker = File(p.join(dir.path, 'blocker2'))..writeAsStringSync('x');
    expect(await ctl.setFolder(p.join(blocker.path, 'sub')), contains('cannot be written to'));
    expect(c.read(backupControllerProvider).folder, isNot(contains('blocker2')));
    final ok = p.join(dir.path, 'PenDrive', 'Backups');
    expect(await ctl.setFolder(ok), isNull);
    expect(await paths.readText('backup.folder'), ok);
    expect(Directory(ok).existsSync(), isTrue);
  });

  test('closing the program: one last backup only if something was saved since the previous one', () async {
    final ctl = c.read(backupControllerProvider.notifier);
    await makeBill();
    await ctl.backupOnClose();
    var list = listBackups(c.read(backupControllerProvider).folder!);
    expect(list, hasLength(1));
    expect(list.single.kind, BackupKind.closing);
    expect(c.read(backupControllerProvider).closing, isFalse);
    await ctl.backupOnClose();
    expect(listBackups(c.read(backupControllerProvider).folder!), hasLength(1), reason: 'nothing changed, closing is instant');
  });

  test('copy to a pen drive: the newest backup is copied and proved identical; with none yet, one is made first', () async {
    final ctl = c.read(backupControllerProvider.notifier);
    final to = await ctl.copyNewestTo(p.join(dir.path, 'pen'));
    expect(File(to).existsSync(), isTrue);
    expect(listBackups(c.read(backupControllerProvider).folder!), hasLength(1));
    expect(File(to).lengthSync(), listBackups(c.read(backupControllerProvider).folder!).single.bytes);
  });

  test('the yearly archive is its own kind, is remembered per financial year, and rotation never removes it', () async {
    final ctl = c.read(backupControllerProvider.notifier);
    expect(ctl.hasArchive('FY2025-26'), isFalse);
    expect(await ctl.run(BackupKind.archive, fy: 'FY2025-26'), isTrue);
    expect(ctl.hasArchive('FY2025-26'), isTrue);
    expect(ctl.hasArchive('FY2024-25'), isFalse);
    final folder = c.read(backupControllerProvider).folder!;
    expect(await rotateBackups(folder), isEmpty);
    expect(listBackups(folder).single.kind, BackupKind.archive);
  });
}
