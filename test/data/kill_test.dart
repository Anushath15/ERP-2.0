import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/kill_test/driver.dart';

// Power cut while saving: kill the saving program at a random moment, open the file, check it. Repeat.
// The full 200-run version: dart run tool/kill_test/run.dart 200
void main() {
  test('after being killed mid-save the database always opens, passes every check, and keeps every bill it acknowledged', () async {
    final runs = int.tryParse(Platform.environment['KILL_RUNS'] ?? '') ?? 25;
    final tmp = Directory.systemTemp.createTempSync('erp2_kill_');
    try {
      final r = await killTest(projectDir: Directory.current.path, dbPath: '${tmp.path}/kill.sqlite', runs: runs, seed: 7);
      expect(r.problems, isEmpty);
      expect(r.billsAtEnd, greaterThan(runs), reason: 'the writer really saved bills');
    } finally {
      tmp.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
