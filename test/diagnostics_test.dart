import 'dart:convert';
import 'dart:io';
import 'package:erp2/core/diag/diag_log.dart';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/fake/data_providers.dart' show appDataProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: the diary holds events and numbers but nothing personal (an @ sign or a long number is hidden), it keeps only the newest lines,
// the file on disk rotates instead of growing for ever, and the diagnostics file saved from Settings has the facts and the diary and no customer name.
void main() {
  group('the diary', () {
    test('events are one line each with the time, the area and the numbers', () {
      final sink = MemoryDiagSink();
      final log = DiagLog(sink, now: () => DateTime(2026, 10, 21, 12, 30));
      log.event('print', 'result', {'status': 'sent', 'ms': 120, 'viaWindow': true});
      expect(sink.recent(10).single, '2026-10-21T12:30:00.000 | print | result | status=sent | ms=120 | viaWindow=true');
    });

    test('anything that looks personal is hidden; long text is cut; errors keep only their kind and a short first line', () {
      final sink = MemoryDiagSink();
      final log = DiagLog(sink);
      log.event('x', 'y', {'mail': 'murugan@gmail.com', 'phone': '9876543210', 'amount': 123456, 'word': 'A' * 100, 'multi': 'a\nb'});
      final line = sink.recent(1).single;
      expect(line, contains('mail=[hidden]'));
      expect(line, contains('phone=[hidden]'));
      expect(line, contains('amount=123456'), reason: 'a number given as a number is a count or a time, not a phone number');
      expect(line, isNot(contains('A' * 61)));
      expect(line, contains('multi=a b'));
      log.error('db', StateError('first line\nsecond line with 9876543210'));
      expect(sink.recent(1).single, allOf(contains('type=StateError'), contains('Bad state: first line'), isNot(contains('second line'))));
    });

    test('only the newest lines are kept in memory', () {
      final sink = MemoryDiagSink();
      for (var i = 0; i < 2500; i++) {
        sink.write('line $i');
      }
      expect(sink.recent(5000).length, 2000);
      expect(sink.recent(2).last, 'line 2499');
    });

    test('the file on disk keeps the newest lines and rotates when full (one older file is kept)', () {
      final dir = Directory.systemTemp.createTempSync('diag');
      addTearDown(() => dir.deleteSync(recursive: true));
      final sink = createDiagSink(dir.path, maxBytes: 20 * 1024);
      final fat = 'x' * 200;
      for (var i = 0; i < 300; i++) {
        sink.write('$i $fat');
      }
      expect(File('${dir.path}/diag.old.log').existsSync(), isTrue);
      expect(File('${dir.path}/diag.log').lengthSync(), lessThan(25 * 1024));
      final last = sink.recent(5);
      expect(last.last, startsWith('299 '));
      expect(sink.recent(100000).length, lessThan(300), reason: 'the oldest lines were dropped');
    });
  });

  testWidgets('Settings > Save diagnostics file: facts and the diary, and not a single customer name', (tester) async {
    final saver = FakeSaver();
    final sink = MemoryDiagSink();
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 2800), location: '/settings', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [
      fileSaverProvider.overrideWithValue(saver),
      diagSinkProvider.overrideWithValue(sink),
    ]);
    c.read(diagProvider).event('sync', 'round', {'ok': true, 'pushed': 3});
    await tester.ensureVisible(find.byKey(const ValueKey('diagSave')));
    await tester.tap(find.byKey(const ValueKey('diagSave')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    final entry = saver.saved.entries.single;
    expect(entry.key, matches(RegExp(r'^ASK-ERP-diagnostics-\d{4}-\d{2}-\d{2}\.txt$')));
    final text = utf8.decode(entry.value);
    expect(text, contains('program: 2.0.0'));
    expect(text, contains('data version:'));
    expect(text, contains('products:'));
    expect(text, contains('printers found: HP LaserJet A4 (default); Epson Receipt'));
    expect(text, contains('sync | round | ok=true | pushed=3'));
    expect(text, contains('no customer names'));
    // the demo shop has customers with names; none of them may be in the file
    final names = (await tester.runAsync(() async => (await c.read(appDataProvider).db.rows('SELECT name FROM customers LIMIT 20')).map((r) => r.read<String>('name')).toList()))!;
    expect(names, isNotEmpty);
    for (final n in names) {
      expect(text.contains(n), isFalse, reason: 'customer name "$n" must not be in the diagnostics file');
    }
  });
}
