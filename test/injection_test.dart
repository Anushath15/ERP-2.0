import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/core/csv_safe.dart';
import 'package:erp2/core/safe_json.dart';
import 'package:erp2/domain/credit/reminder.dart';

// SECURITY: other ways text can hurt: spreadsheet formulas, a crafted WhatsApp link, a hostile import file, SQL, logs.
void main() {
  group('CSV and Excel export: no formula can run', () {
    test('text starting with = + - @ tab or carriage return gets a leading apostrophe', () {
      for (final evil in ['=HYPERLINK("http://evil","click")', '+1+1', '-2+3', '@SUM(A1)', '\t=1+1', '\r=1+1', '=cmd|\' /C calc\'!A0']) {
        final cell = csvCell(evil);
        final plain = cell.startsWith('"') ? cell.substring(1) : cell;
        expect(plain.startsWith("'"), isTrue, reason: 'cell for $evil was $cell');
      }
    });

    test('ordinary text, numbers and negative NUMBERS are not changed', () {
      expect(csvCell('Murugan Electricals'), 'Murugan Electricals');
      expect(csvCell(1234), '1234');
      expect(csvCell(-50), '-50', reason: 'a real number, not text');
      expect(csvCell(12.5), '12.5');
      expect(csvCell(null), '');
    });

    test('cells with commas, quotes and line breaks are quoted correctly', () {
      expect(csvCell('Sri Murugan, Sons'), '"Sri Murugan, Sons"');
      expect(csvCell('say "hi"'), '"say ""hi"""');
      expect(csvCell('two\nlines'), '"two\nlines"');
    });

    test('a whole table; very long cells are cut at the spreadsheet limit', () {
      expect(toCsv([['Name', 'Owes'], ['=evil', 5]]), "Name,Owes\r\n'=evil,5\r\n");
      expect(csvCell('a' * 100000).length, 32000);
    });
  });

  group('WhatsApp link: whatever the text, the link has only the number and the text', () {
    test('hostile text cannot add parameters, end the link or change the number', () {
      final links = buildWhatsappLinks(digits: '919876543210', message: '&phone=111&text=x#frag %00 \n ../ <script>alert(1)</script> ?a=b ₹ "quoted" \'single\' + plus');
      for (final link in [links.appLink, links.webLink]) {
        final uri = Uri.parse(link);
        expect(uri.queryParameters.keys.toSet(), link.startsWith('whatsapp') ? {'phone', 'text'} : {'text'}, reason: link);
        expect(uri.hasFragment, isFalse, reason: 'a # in the text must be encoded');
        expect(uri.queryParameters['text'], '&phone=111&text=x#frag %00 \n ../ <script>alert(1)</script> ?a=b ₹ "quoted" \'single\' + plus');
      }
      expect(Uri.parse(links.appLink).queryParameters['phone'], '919876543210');
      expect(Uri.parse(links.webLink).path, '/919876543210');
    });

    test('a number that is not just digits is refused', () {
      for (final bad in ['9198765 43210', '+919876543210', '91987654321;rm', '12', '1' * 30, '']) {
        expect(() => buildWhatsappLinks(digits: bad, message: 'hi'), throwsArgumentError, reason: bad);
      }
    });

    test('a message longer than the limit is cut, whoever passes it', () {
      final links = buildWhatsappLinks(digits: '919876543210', message: 'x' * 5000);
      expect(Uri.parse(links.webLink).queryParameters['text']!.length, maxReminderLength);
    });
  });

  group('a file made by somebody else (ERP 1 import, restore) is read with limits', () {
    test('a normal file is read', () {
      expect(readSafeJson('{"products":[{"name":"x","price":150}]}'), isA<Map<String, dynamic>>());
    });

    test('damaged or not-JSON files give one plain exception, never a crash', () {
      for (final bad in ['', '{', '{"a":', 'not json at all', '[1,2,', '\u0000\u0001\u0002']) {
        expect(() => readSafeJson(bad), throwsA(isA<SafeJsonException>()), reason: 'input "$bad"');
      }
    });

    test('a million nested brackets cannot crash the program', () {
      expect(() => readSafeJson('[' * 1000000), throwsA(isA<SafeJsonException>()));
      expect(() => readSafeJson('{"a":' * 100000), throwsA(isA<SafeJsonException>()));
      expect(readSafeJson('[[[[1]]]]'), isA<List<dynamic>>(), reason: 'ordinary nesting is fine');
    });

    test('brackets inside text are not nesting', () {
      expect(readSafeJson('{"note":"[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[["}'), isA<Map<String, dynamic>>());
    });

    test('a huge file is refused before it is decoded', () {
      expect(() => readSafeJson('[${'1,' * 200}0]', maxChars: 100), throwsA(isA<SafeJsonException>()));
    });

    test('too many values is refused', () {
      expect(() => readSafeJson('[${List.filled(1000, '0').join(',')}]', maxNodes: 500), throwsA(isA<SafeJsonException>()));
    });
  });

  group('the code itself: no SQL built from text, no logging of personal data', () {
    final libFiles = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

    test('no SQL statement is built by putting text into the query (everything must be a parameter)', () {
      final risky = RegExp(r'''(customStatement|rawQuery|rawInsert|rawUpdate|rawDelete|customSelect|execute)\s*\(\s*["'][^"']*\$''');
      final found = [for (final f in libFiles) if (risky.hasMatch(f.readAsStringSync())) f.path];
      expect(found, isEmpty, reason: 'SQL with text pasted in: $found');
    });

    test('the app prints and logs nothing (so no customer data, phone number or token can leak into a log)', () {
      final loud = RegExp(r'(^|[^A-Za-z_.])(print|debugPrint|debugPrintStack|log)\s*\(', multiLine: true);
      final found = [for (final f in libFiles) if (loud.hasMatch(f.readAsStringSync())) f.path];
      expect(found, isEmpty, reason: 'logging found in: $found');
    });
  });
}
