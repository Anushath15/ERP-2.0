import 'dart:convert';
import 'dart:io';
import 'package:erp2/import/erp1/runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import '../../tool/import/synthetic.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('runner'));
  tearDown(() => dir.deleteSync(recursive: true));
  final text = jsonEncode(Synthetic(bills: 300, products: 60, customers: 20, dealers: 3, flaws: false).build());

  test('the preview is made away from the screen and matches the command-line report', () async {
    final pv = await previewInBackground(text, 'b.json');
    expect(pv.ok, isTrue);
    expect(pv.counts['bills'], 300);
    expect(pv.canImport, isTrue);
    expect(pv.reportText, contains('CHECKED AND CORRECT'));
  });

  test('a file that is not a backup comes back as a failed preview, not an exception', () async {
    final pv = await previewInBackground('{"x": 1}', 'x.json');
    expect(pv.ok, isFalse);
    expect(pv.error, contains('not an ERP 1 backup'));
    expect((await previewInBackground('garbage', 'g.json')).ok, isFalse);
  });

  test('the new data file is written in its own isolate with every check passing, reporting its stages', () async {
    final out = p.join(dir.path, 'import', 'new.sqlite');
    final stages = <String>[];
    final o = await writeNewShopFile(text: text, fileName: 'b.json', outPath: out, onStage: stages.add);
    expect(o.ok, isTrue, reason: o.error);
    expect(o.allChecksPassed, isTrue, reason: '${o.mismatches} ${o.selfCheckProblems} ${o.integrity}');
    expect(o.counts['bills'], 300);
    expect(File(out).existsSync(), isTrue);
    expect(stages, containsAllInOrder(['reading', 'writing', 'checking']));
  });

  test('it refuses to write over an existing file, and a bad backup leaves no file behind', () async {
    final out = p.join(dir.path, 'x.sqlite');
    File(out).writeAsStringSync('already here');
    expect((await writeNewShopFile(text: text, fileName: 'b', outPath: out)).ok, isFalse);
    expect(File(out).readAsStringSync(), 'already here');
    final out2 = p.join(dir.path, 'y.sqlite');
    final bad = await writeNewShopFile(text: '{"data": []}', fileName: 'b', outPath: out2);
    expect(bad.ok, isFalse);
    expect(File(out2).existsSync(), isFalse);
  });
}
