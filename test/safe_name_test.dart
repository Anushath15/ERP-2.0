import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/core/file_saver_io.dart';
import 'package:erp2/core/safe_name.dart';

// SECURITY: text that a person typed (a customer name, a note) may become part of a file name. It must never be able to leave the
// folder, hide in a startup folder, use a name Windows treats specially, or overwrite a file.
Uint8List bytesOf(List<int> l) => Uint8List.fromList(l);

void main() {
  group('safeFileName', () {
    test('ordinary names keep their letters, digits, spaces, dashes and one extension', () {
      expect(safeFileName('Statement Murugan Electricals 2026-10-14.pdf'), 'Statement Murugan Electricals 2026-10-14.pdf');
      expect(safeFileName('Tax invoice A-020001.pdf'), 'Tax invoice A-020001.pdf');
    });

    test('path separators, drive letters and ".." can never get through', () {
      for (final bad in [r'..\..\Startup\x', '../../etc/passwd', r'C:\evil', r'C:evil.exe', '/etc/hosts', r'\\server\share\x', 'a/b', r'a\b', '....//....//x']) {
        final s = safeFileName(bad);
        expect(s.contains('/'), isFalse, reason: bad);
        expect(s.contains(r'\'), isFalse, reason: bad);
        expect(s.contains(':'), isFalse, reason: bad);
        expect(s.contains('..'), isFalse, reason: bad);
        expect(s, isNotEmpty, reason: bad);
      }
      expect(safeFileName(r'..\..\Startup\x'), isNot(startsWith('.')));
    });

    test('Windows reserved names are changed, with or without an extension, in any letter case', () {
      for (final bad in ['CON', 'con', 'PRN', 'AUX', 'NUL', 'NUL.pdf', 'nul.PDF', 'COM1', 'com9.txt', 'LPT1', 'lpt9.pdf', 'CON.tar.gz', 'Aux.']) {
        final s = safeFileName(bad);
        final stem = s.split('.').first.toUpperCase();
        expect(RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$').hasMatch(stem), isFalse, reason: '$bad became $s');
        expect(s, isNotEmpty);
      }
      expect(safeFileName('NUL.pdf'), endsWith('.pdf'));
      expect(safeFileName('CONSOLE.pdf'), 'CONSOLE.pdf', reason: 'only the exact reserved words are changed');
    });

    test('control characters, quotes and other special characters become underscores', () {
      final s = safeFileName('a\u0000b\u0007c\u001f\r\nd"e<f>g|h?i*j.pdf');
      expect(RegExp(r'[\u0000-\u001f"<>|?*]').hasMatch(s), isFalse);
      expect(s, endsWith('.pdf'));
      expect(safeFileName('x\u202Egnp.exe').contains('\u202E'), isFalse, reason: 'the right-to-left override that disguises an extension');
    });

    test('other scripts are turned into underscores or dropped, never kept', () {
      final s = safeFileName('வணக்கம் Traders.pdf');
      expect(RegExp(r'^[A-Za-z0-9 _.\-]+$').hasMatch(s), isTrue, reason: s);
      expect(s, endsWith('.pdf'));
      expect(safeFileName('வணக்கம்'), isNotEmpty);
    });

    test('trailing dots and spaces are removed (Windows would drop them silently)', () {
      expect(safeFileName('report. . .'), isNot(endsWith('.')));
      expect(safeFileName('report   '), 'report');
      expect(safeFileName('x.pdf. '), endsWith('.pdf'));
    });

    test('very long names are cut to 80 characters before the extension', () {
      final s = safeFileName('${'A' * 500}.pdf');
      expect(s.length, 84);
      expect(s, endsWith('.pdf'));
      expect(safeFileName('B' * 500).length, 80);
    });

    test('an empty or useless name still gives a usable one', () {
      for (final bad in ['', '   ', '.', '..', '...', '___', r'\', '/', '.pdf', '\u0000']) {
        final s = safeFileName(bad);
        expect(s, isNotEmpty, reason: '"$bad"');
        expect(s.startsWith('.'), isFalse, reason: '"$bad" -> "$s"');
      }
      expect(safeFileName('', fallback: 'Statement'), 'Statement');
    });

    test('the result is always safe: random nasty text (property test)', () {
      const pool = r'..\/:*?"<>| aZ09-_' '\u0000\u0001\u202E\u200B\u0BA4 ';
      var seed = 1;
      int next(int n) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        return seed % n;
      }
      for (var i = 0; i < 3000; i++) {
        final text = String.fromCharCodes([for (var k = 0; k < next(120); k++) pool.codeUnitAt(next(pool.length))]);
        final s = safeFileName('$text${next(2) == 0 ? '.pdf' : ''}');
        expect(RegExp(r'^[A-Za-z0-9 _.\-]+$').hasMatch(s), isTrue, reason: 'from "$text" -> "$s"');
        expect(s.contains('..'), isFalse, reason: s);
        expect(s.startsWith('.') || s.endsWith('.') || s.endsWith(' ') || s.startsWith(' '), isFalse, reason: '"$s"');
        expect(s.length, lessThanOrEqualTo(80 + 11), reason: s);
        expect(RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)', caseSensitive: false).hasMatch(s), isFalse, reason: s);
      }
    });
  });

  group('isInside', () {
    test('a path is inside a folder only if it really is, after resolving . and ..', () {
      expect(isInside(r'C:\Users\a\Downloads', r'C:\Users\a\Downloads\x.pdf'), isTrue);
      expect(isInside('/home/a/dl', '/home/a/dl/x.pdf'), isTrue);
      expect(isInside(r'C:\Users\a\Downloads', r'C:\Users\a\Downloads\..\Startup\x.pdf'), isFalse);
      expect(isInside('/home/a/dl', '/home/a/dl/../.bashrc'), isFalse);
      expect(isInside('/home/a/dl', '/home/a/dl2/x.pdf'), isFalse, reason: 'a folder with the same start is a different folder');
      expect(isInside('/home/a/dl', '/home/a/dl'), isFalse, reason: 'the folder itself is not a file inside it');
    });
  });

  group('the file saver (the one place that writes files)', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('erp2_save_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('nasty names are saved INSIDE the chosen folder, never outside it', () async {
      final saver = IoFileSaver(folder: tmp.path);
      for (final bad in [r'..\..\Startup\evil.pdf', '../../evil.pdf', r'C:\evil.pdf', 'CON', 'NUL.pdf', 'a/b/c.pdf']) {
        final where = await saver.save(bad, bytesOf([1, 2, 3]));
        expect(where, isNotNull, reason: bad);
        final f = File(where!);
        expect(f.existsSync(), isTrue);
        expect(f.parent.absolute.path, tmp.absolute.path, reason: '$bad was saved at $where');
      }
      expect(tmp.parent.listSync().whereType<File>().where((f) => f.path.contains('evil')), isEmpty);
    });

    test('a file is never overwritten silently: the second save gets a number', () async {
      final saver = IoFileSaver(folder: tmp.path);
      final a = await saver.save('Statement X.pdf', bytesOf([1]));
      final b = await saver.save('Statement X.pdf', bytesOf([2]));
      expect(a, isNot(b));
      expect(File(a!).readAsBytesSync(), [1]);
      expect(File(b!).readAsBytesSync(), [2]);
    });

    test('the folder is created if it is missing', () async {
      final saver = IoFileSaver(folder: '${tmp.path}${Platform.pathSeparator}ASK ERP 2.0');
      final where = await saver.save('x.pdf', bytesOf([9]));
      expect(File(where!).existsSync(), isTrue);
    });
  });
}
