import 'dart:io';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/app_database.dart';
import 'package:erp2/data/db/open.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  test('checkpoints run in quiet moments between saves, never inside a save, and every saved bill is still there after a reopen', () async {
    final dir = Directory.systemTemp.createTempSync('ckpt');
    final path = '${dir.path}/shop.sqlite';
    try {
      final db = await openShopDatabase(path, checkpoints: const CheckpointPolicy(commitsBetween: 5, idleMs: 20, tickMs: 10));
      final d = AppData(DataContext(db: db, deviceId: 'dev-test'));
      for (var i = 0; i < 30; i++) {
        await d.catalog.saveProduct(sampleProduct('Item $i', id: 'p$i'), create: true);
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(db.controlledCheckpoints, greaterThan(0), reason: 'the program folded the log back into the file by itself');
      expect(await db.scalarInt('SELECT COUNT(*) FROM products'), 30);
      await db.close();
      final again = await openShopDatabase(path);
      expect(await again.scalarInt('SELECT COUNT(*) FROM products'), 30);
      await again.close();
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('without the controlled policy no timer exists (tests and tools leave nothing running)', () async {
    final dir = Directory.systemTemp.createTempSync('ckpt2');
    try {
      final db = await openShopDatabase('${dir.path}/shop.sqlite');
      expect(db.controlledCheckpoints, 0);
      await db.close();
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
