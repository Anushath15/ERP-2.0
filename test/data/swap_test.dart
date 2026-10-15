import 'dart:convert';
import 'dart:io';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/open.dart';
import 'package:erp2/data/importer/erp1_writer.dart';
import 'package:erp2/data/importer/swap.dart';
import 'package:erp2/import/erp1/plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import '../../tool/import/synthetic.dart';
import 'helpers.dart';

Future<Map<String, int>> makeNew(String file) async {
  final text = jsonEncode(Synthetic(bills: 40, products: 40, customers: 10, dealers: 2, flaws: false).build());
  final db = await openShopDatabase(file);
  final d = AppData(DataContext(db: db, deviceId: 'import'));
  await writePlan(d, Erp1Plan.parse(text), nowMs: 1760000000000);
  final c = await shopCounts(d);
  await db.close();
  return c;
}

Future<void> makeLive(String file, {int products = 3}) async {
  final db = await openShopDatabase(file);
  final d = AppData(DataContext(db: db, deviceId: 'dev-test'));
  for (var i = 0; i < products; i++) {
    await d.catalog.saveProduct(sampleProduct('Old item $i', id: 'old$i'), create: true);
  }
  await db.close();
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('swap'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a confirmed import switch: the old data is moved (not deleted), the new data takes its place, nothing is queued, going back works', () async {
    final live = p.join(dir.path, 'shop.sqlite');
    await makeLive(live);
    final newFile = p.join(dir.path, 'import', 'erp1-new.sqlite');
    final counts = await makeNew(newFile);
    await requestImportSwap(dataDir: dir.path, newFile: newFile, expected: counts, source: 'test.json');
    final r = await applyPendingSwap(dir.path, now: DateTime(2026, 10, 16, 9, 30, 0));
    expect(r!.ok, isTrue, reason: r.message);
    expect(r.counts['products'], counts['products']);
    expect(File(p.join(dir.path, 'swap.pending.json')).existsSync(), isFalse);
    // the live file now holds the imported shop
    final db = await openShopDatabase(live);
    expect(await db.scalarInt('SELECT COUNT(*) FROM products'), counts['products']);
    await db.close();
    // the old data is safe and listed
    final prev = await previousData(dir.path, now: DateTime(2026, 10, 20));
    expect(prev, hasLength(1));
    expect(prev.single.products, 3);
    expect(File(p.join(dir.path, 'previous', prev.single.stamp, 'shop.sqlite')).existsSync(), isTrue);
    expect(await previousData(dir.path, now: DateTime(2026, 12, 1)), isEmpty, reason: 'offered for 30 days');
    // the Health page can show what happened
    expect((await lastSwapResult(dir.path))!.ok, isTrue);

    // go back
    await requestGoBack(dataDir: dir.path, stamp: prev.single.stamp);
    final back = await applyPendingSwap(dir.path, now: DateTime(2026, 10, 21, 10));
    expect(back!.ok, isTrue, reason: back.message);
    final old = await openShopDatabase(live);
    expect(await old.scalarInt('SELECT COUNT(*) FROM products'), 3);
    await old.close();
    final after = await previousData(dir.path, now: DateTime(2026, 10, 22));
    expect(after.any((x) => x.products == counts['products']), isTrue, reason: 'the imported data is kept too');
  });

  test('a new file that fails the checks is refused and the live data is untouched', () async {
    final live = p.join(dir.path, 'shop.sqlite');
    await makeLive(live);
    final liveBytes = File(live).readAsBytesSync();
    final newFile = p.join(dir.path, 'import', 'bad.sqlite');
    Directory(p.dirname(newFile)).createSync(recursive: true);
    File(newFile).writeAsBytesSync(List.filled(5000, 7));
    await requestImportSwap(dataDir: dir.path, newFile: newFile, expected: {'products': 1}, source: 't');
    final r = await applyPendingSwap(dir.path);
    expect(r!.ok, isFalse);
    expect(r.message, contains('Your data is as it was'));
    expect(File(live).readAsBytesSync(), liveBytes);
  });

  test('a new file whose counts differ from what was announced is refused', () async {
    final live = p.join(dir.path, 'shop.sqlite');
    await makeLive(live);
    final newFile = p.join(dir.path, 'import', 'n.sqlite');
    final counts = await makeNew(newFile);
    await requestImportSwap(dataDir: dir.path, newFile: newFile, expected: {...counts, 'products': counts['products']! + 1}, source: 't');
    final r = await applyPendingSwap(dir.path);
    expect(r!.ok, isFalse);
    final db = await openShopDatabase(live);
    expect(await db.scalarInt('SELECT COUNT(*) FROM products'), 3);
    await db.close();
  });

  test('a request that points outside the data folder is refused', () async {
    await makeLive(p.join(dir.path, 'shop.sqlite'));
    File(p.join(dir.path, 'swap.pending.json')).writeAsStringSync(jsonEncode({'kind': 'import', 'file': '../outside.sqlite', 'expected': {}, 'source': 'x'}));
    final r = await applyPendingSwap(dir.path);
    expect(r!.ok, isFalse);
  });

  test('an unreadable request is ignored and reported', () async {
    File(p.join(dir.path, 'swap.pending.json')).writeAsStringSync('not json');
    final r = await applyPendingSwap(dir.path);
    expect(r!.ok, isFalse);
  });

  test('with no earlier data at all the switch still works and there is nothing to go back to', () async {
    final newFile = p.join(dir.path, 'import', 'n.sqlite');
    final counts = await makeNew(newFile);
    await requestImportSwap(dataDir: dir.path, newFile: newFile, expected: counts, source: 't');
    final r = await applyPendingSwap(dir.path);
    expect(r!.ok, isTrue, reason: r.message);
    expect(await previousData(dir.path), isEmpty);
  });

  test('nothing waiting means nothing happens', () async {
    expect(await applyPendingSwap(dir.path), isNull);
  });
}
