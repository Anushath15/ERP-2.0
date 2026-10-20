import 'dart:io';
import 'package:erp2/import/erp1/runner_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// A dry run on the owner's real ERP 1 backup. It only READS the backup and writes a test database into the system temp folder; the shop's real
// data is never touched. Skipped when the file is not on this computer. Run: flutter test test/real_backup_dryrun_test.dart
void main() {
  final path = Platform.environment['ERP1_BACKUP'] ?? 'D:/ERP 1 backup/ERP_Backup_2026-10-19_173859_Manual.json';
  final file = File(path);

  test('the real ERP 1 backup previews cleanly, is written to a test database, and every check passes', () async {
    final text = file.readAsStringSync();
    final p = await previewInBackground(text, 'ERP_Backup.json');
    // ignore: avoid_print
    print('PREVIEW ok=${p.ok} checksum=${p.checksum} counts=${p.counts} bills=${p.bills} sales=${p.salesPaise} owing=${p.customersOwing}/${p.customersOwedPaise} rejected=${p.rejected} repaired=${p.repaired}');
    // ignore: avoid_print
    print('NEGATIVES ${p.negatives}\nCORRECTIONS ${p.corrections}\nDECISIONS ${p.decisions}');
    expect(p.ok, isTrue, reason: p.error);
    expect(p.checksumBad, isFalse);
    final dir = Directory.systemTemp.createTempSync('erp2-real-dryrun');
    addTearDown(() => dir.deleteSync(recursive: true));
    final o = await writeNewShopFile(text: text, fileName: 'ERP_Backup.json', outPath: '${dir.path}/shop.sqlite');
    // ignore: avoid_print
    print('OUTCOME ok=${o.ok} verified=${o.verified} integrity=${o.integrity} counts=${o.counts} mismatches=${o.mismatches} selfcheck=${o.selfCheckProblems} ms=${o.millis} error=${o.error}');
    expect(o.ok, isTrue, reason: o.error);
    expect(o.mismatches, isEmpty);
    expect(o.selfCheckProblems, isEmpty);
    expect(o.integrity, 'ok');
    final db = sqlite3.open('${dir.path}/shop.sqlite');
    final withBrand = db.select("SELECT COUNT(*) AS n FROM products WHERE brand <> ''").first['n'] as int;
    db.dispose();
    expect(withBrand, greaterThan(600), reason: 'the brand of each product comes across (644 in the owners backup)');
  }, skip: file.existsSync() ? false : 'the backup file is not on this computer');
}
