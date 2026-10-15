import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:erp2/boot.dart';
import 'package:erp2/core/app_paths_io.dart';
import 'package:erp2/data/db/app_database.dart';
import 'package:erp2/data/db/errors.dart';
import 'package:erp2/data/repo/series_registry.dart';
import 'package:erp2/demo/demo_seeder.dart';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/open.dart';
import 'package:erp2/data/importer/erp1_writer.dart';
import 'package:erp2/data/importer/swap.dart';
import 'package:erp2/import/erp1/plan.dart';
import '../../tool/import/synthetic.dart';
import 'helpers.dart';

// Opening the shop at start-up: real and demo data in separate files, a stable device id, clear outcomes when the file cannot be opened.
void main() {
  late Directory tmp;
  late FileAppPaths paths;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('erp2_boot_');
    paths = FileAppPaths('${tmp.path}${Platform.pathSeparator}ASK ERP 2.0');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  const small = DemoCounts(products: 60, customers: 80, bills: 40, estimates: 5);

  test('a new shop opens empty and asks for the first-run set-up; the device id is made once and stays', () async {
    final o = await bootApp(paths: paths, mode: DataMode.real, background: false) as BootReady;
    expect(o.needsSetup, isTrue);
    expect(await o.data.catalog.productCount(), 0);
    final id = o.deviceId;
    await o.data.close();
    final again = await bootApp(paths: paths, mode: DataMode.real, background: false) as BootReady;
    expect(again.deviceId, id);
    await again.data.close();
    expect(File('${paths.base}${Platform.pathSeparator}device.id').existsSync(), isTrue, reason: 'kept outside the data folder');
    expect(Directory(paths.dataDir).listSync().any((f) => f.path.endsWith('device.id')), isFalse);
  });

  test('demo mode fills its OWN file once, never touches the real file, and needs no set-up', () async {
    final real = await bootApp(paths: paths, mode: DataMode.real, background: false) as BootReady;
    await real.data.close();
    final realBytes = File(paths.dbLocation('shop')).lengthSync();
    final demo = await bootApp(paths: paths, mode: DataMode.demo, background: false, demoCounts: small) as BootReady;
    expect(demo.needsSetup, isFalse);
    expect(await demo.data.catalog.productCount(), 60);
    expect(await demo.data.bills.count(), 40);
    expect(demo.location, endsWith('demo.sqlite'));
    await demo.data.close();
    final again = await bootApp(paths: paths, mode: DataMode.demo, background: false, demoCounts: small) as BootReady;
    expect(await again.data.bills.count(), 40, reason: 'the demo shop is not filled a second time');
    await again.data.close();
    final back = await bootApp(paths: paths, mode: DataMode.real, background: false) as BootReady;
    expect(await back.data.catalog.productCount(), 0, reason: 'the real shop has none of the demo data');
    expect(File(paths.dbLocation('shop')).lengthSync(), greaterThanOrEqualTo(realBytes));
    await back.data.close();
  });

  test('the chosen mode is remembered on this computer', () async {
    expect(await loadMode(paths), DataMode.real);
    await saveMode(paths, DataMode.demo);
    expect(await loadMode(paths), DataMode.demo);
    await saveMode(paths, DataMode.real);
    expect(await loadMode(paths), DataMode.real);
  });

  test('data from a newer program, a damaged file and an unusable folder give a clear problem and change nothing', () async {
    Directory(paths.dataDir).createSync(recursive: true);
    final f = File(paths.dbLocation('shop'));
    final raw = sqlite3.open(f.path);
    raw.execute('CREATE TABLE t(x)');
    raw.execute('PRAGMA user_version = ${currentSchemaVersion + 3}');
    raw.close();
    final before = f.readAsBytesSync();
    var o = await bootApp(paths: paths, mode: DataMode.real, background: false);
    expect(o, isA<BootProblem>().having((p) => p.error.problem, 'problem', DbProblem.tooNew));
    expect(f.readAsBytesSync(), before);
    f.writeAsBytesSync(List.generate(3000, (i) => i % 200));
    o = await bootApp(paths: paths, mode: DataMode.real, background: false);
    expect(o, isA<BootProblem>().having((p) => p.error.problem, 'problem', DbProblem.notDatabase));
    expect(f.lengthSync(), 3000);
    // the data folder is a file, so it cannot be a folder
    f.deleteSync();
    Directory(paths.dataDir).deleteSync(recursive: true);
    File(paths.dataDir).writeAsStringSync('not a folder');
    o = await bootApp(paths: paths, mode: DataMode.real, background: false);
    expect(o, isA<BootProblem>().having((p) => p.error.problem, 'problem', DbProblem.cannotOpen));
  });

  group('the letter of each computer', () {
    test('a letter is taken once; the same computer can ask again; another computer cannot have it; a computer has one letter', () async {
      final d = memoryShop(device: 'dev-1');
      final settings = d.settings;
      final one = SeriesRegistry(settings, 'dev-1');
      final two = SeriesRegistry(settings, 'dev-2');
      expect(await one.mine(), isNull);
      await one.claim('A');
      await one.claim('A'); // the same again is fine
      expect(await one.mine(), 'A');
      await expectLater(two.claim('A'), throwsA(isA<SeriesTakenException>()));
      await expectLater(one.claim('B'), throwsStateError);
      await two.claim('B');
      expect((await one.free()).contains('A'), isFalse);
      expect((await one.free()).contains('B'), isFalse);
      expect((await one.free()).contains('C'), isTrue);
      await expectLater(two.claim('Q'), throwsArgumentError, reason: 'letters that look like digits or each other are not offered');
      await d.close();
    });

    test('damaged registry text is ignored, not trusted', () async {
      final d = memoryShop();
      await d.settings.put(SeriesRegistry.key, '{"A": 5, "B": "x", "C": ');
      expect(await SeriesRegistry(d.settings, 'dev-test').all(), isEmpty);
      await d.close();
    });
  });

  test('start-up after a confirmed import: the imported shop opens, the earlier (even demo-like) data is kept aside, and the counts are the real ones', () async {
    // the earlier data on this computer
    final first = await bootApp(paths: paths, mode: DataMode.real, background: false) as BootReady;
    await first.data.catalog.saveProduct(sampleProduct('Earlier item', id: 'early'), create: true);
    await first.data.close();
    // the new file, made the way the Import page makes it
    final newFile = '${paths.dataDir}${Platform.pathSeparator}import${Platform.pathSeparator}erp1.sqlite';
    final db = await openShopDatabase(newFile);
    final d = AppData(DataContext(db: db, deviceId: 'import'));
    await writePlan(d, Erp1Plan.parse(jsonEncode(Synthetic(bills: 30, products: 25, customers: 4, dealers: 1, flaws: false).build())), nowMs: 1760000000000);
    final counts = await shopCounts(d);
    await db.close();
    await requestImportSwap(dataDir: paths.dataDir, newFile: newFile, expected: counts, source: 'x.json');

    final o = await bootApp(paths: paths, mode: DataMode.real, background: false) as BootReady;
    expect(o.swap!.ok, isTrue, reason: o.swap!.message);
    expect(await o.data.catalog.productCount(), 25);
    expect(o.boot.customers, hasLength(4));
    expect(o.boot.customers.every((c) => !c.name.startsWith('Demo')), isTrue);
    expect(await o.data.reports.shopCounts().then((c) => c.bills), 30);
    expect((await o.data.reports.shopCounts()).importedFromErp1, isNotNull);
    expect((await previousData(paths.dataDir)).single.products, 1);
    await o.data.close();
  });
}
