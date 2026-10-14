import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/core/validators.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/fake/store.dart';
import 'helpers.dart';

// SECURITY: every text a person types (names, phones, notes, towns, GSTIN, UPI ids) goes through ONE set of rules: length limits,
// no control characters, no bidirectional-override characters, trimmed.
void main() {
  group('cleanText', () {
    test('trims, collapses spaces and removes control, zero-width and bidirectional-override characters', () {
      expect(cleanText('  Murugan   Electricals  '), 'Murugan Electricals');
      expect(cleanText('a\u0000b\u0007c\u001Fd'), 'abcd');
      expect(cleanText('a\u202Eb\u202Ac\u2066d\u2069e'), 'abcde', reason: 'bidirectional overrides can disguise text');
      expect(cleanText('a\u200Bb\u200Dc\uFEFFd'), 'abcd', reason: 'zero-width characters');
      expect(cleanText('line1\nline2'), 'line1 line2', reason: 'a single-line field has no line breaks');
      expect(cleanText('x\ty'), 'x y');
    });

    test('multi-line text keeps line breaks but nothing else that is invisible', () {
      expect(cleanText('first\r\nsecond\u0000\n\n\nthird', multiline: true), 'first\nsecond\n\nthird');
      expect(cleanText('a\u202Eb', multiline: true), 'ab');
    });

    test('letters of every language and normal punctuation are kept', () {
      expect(cleanText('வணக்கம் Traders & Sons, 12/B (Main)'), 'வணக்கம் Traders & Sons, 12/B (Main)');
    });
  });

  group('checkText', () {
    test('length limits per kind', () {
      expect(checkText(TextKind.name, 'a' * 80), isNull);
      expect(checkText(TextKind.name, 'a' * 81), TextProblem.tooLong);
      expect(checkText(TextKind.name, 'N' * 10000), TextProblem.tooLong);
      expect(checkText(TextKind.town, 'a' * 61), TextProblem.tooLong);
      expect(checkText(TextKind.address, 'a' * 201), TextProblem.tooLong);
      expect(checkText(TextKind.note, 'a' * 501), TextProblem.tooLong);
      expect(checkText(TextKind.message, 'a' * 1501), TextProblem.tooLong);
      expect(checkText(TextKind.note, 'a' * 500), isNull);
    });

    test('forbidden characters are reported, not silently kept', () {
      expect(checkText(TextKind.name, 'bad\u0000name'), TextProblem.badChars);
      expect(checkText(TextKind.name, 'a\u202Eb'), TextProblem.badChars);
      expect(checkText(TextKind.note, 'ok\nfine'), isNull);
      expect(checkText(TextKind.name, 'ok\nnot fine'), TextProblem.badChars, reason: 'no line break in a name');
    });

    test('empty is fine for optional fields (required is the form\'s job)', () {
      for (final k in TextKind.values) {
        expect(checkText(k, ''), isNull, reason: k.name);
        expect(checkText(k, '   '), isNull, reason: k.name);
      }
    });

    test('GSTIN: 15 characters in the official shape, capital letters', () {
      expect(checkText(TextKind.gstin, '33AAAAA0000A1Z5'), isNull);
      expect(checkText(TextKind.gstin, '33aaaaa0000a1z5'), isNull, reason: 'lower case is accepted and stored as capitals (cleanText)');
      for (final bad in ['33AAAAA0000A1Z', '33AAAAA0000A1Z55', 'XXAAAAA0000A1Z5', '33AAAAA0000A1X5', '<script>alert(1)</scr', '33AAAAA0000A1Z5 ']) {
        if (bad == '33AAAAA0000A1Z5 ') continue; // a trailing space is trimmed first
        expect(checkText(TextKind.gstin, bad), TextProblem.notGstin, reason: bad);
      }
    });

    test('UPI id: name@bank, safe characters only', () {
      expect(checkText(TextKind.upi, 'senthil@okbank'), isNull);
      expect(checkText(TextKind.upi, 'shop.name-1@ybl'), isNull);
      for (final bad in ['nobank', '@okbank', 'a b@okbank', 'a@b@c', 'a@ok bank', 'x@y;rm -rf', 'a' * 200 + '@bank', '<x>@bank']) {
        expect(checkText(TextKind.upi, bad), isNotNull, reason: bad);
      }
    });

    test('phone: the same rules as WhatsApp numbers (digits, +91, spaces and dashes)', () {
      expect(checkText(TextKind.phone, '98765 43210'), isNull);
      expect(checkText(TextKind.phone, '+91 98765-43210'), isNull);
      expect(checkText(TextKind.phone, 'call me'), TextProblem.notPhone);
      expect(checkText(TextKind.phone, '1'), TextProblem.notPhone);
      expect(checkText(TextKind.phone, '9' * 30), TextProblem.notPhone);
    });
  });

  group('the input formatter used by every text box', () {
    test('strips forbidden characters as they are typed and cuts the length', () {
      final f = safeInput(TextKind.name);
      var v = f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: 'abc\u202Edef'));
      expect(v.text, 'abcdef');
      v = f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: 'x' * 500));
      expect(v.text.length, 80);
    });

    test('multi-line kinds keep line breaks', () {
      final v = safeInput(TextKind.note).formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: 'a\nb\u0000'));
      expect(v.text, 'a\nb');
    });
  });

  group('on the real forms', () {
    testWidgets('quick-add customer: a name with a hidden override character is cleaned, a 10,000 letter name cannot be typed, a too-short phone is refused', (tester) async {
      final c = await pumpApp(tester, size: desktop1366, location: '/customers', motion: MotionLevel.off, followSystemMotion: false);
      await tester.tap(find.text('Add customer').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name').last, 'Evil\u202Egnp.exe ${'x' * 10000}');
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone').last, '12');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(c.read(customersProvider).any((x) => x.name.contains('Evil')), isFalse, reason: 'the bad phone stops the save');
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone').last, '98765 43210');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      final made = c.read(customersProvider).firstWhere((x) => x.name.contains('Evil'));
      expect(made.name.contains('\u202E'), isFalse);
      expect(made.name.length, lessThanOrEqualTo(80));
    });

    testWidgets('Shop profile: GSTIN and UPI id show an error for a wrong value and the shop keeps its last good value', (tester) async {
      final c = await pumpApp(tester, size: const ScreenSpec('tall', 1920, 2400), location: '/shop', motion: MotionLevel.off, followSystemMotion: false);
      expect(find.byKey(const ValueKey('shop-gstin')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('shop-gstin')), 'not a gstin');
      await tester.pump();
      expect(find.text('This is not a valid GSTIN (15 letters and digits)'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('shop-upi')), 'nobank');
      await tester.pump();
      expect(find.text('This is not a valid UPI id (like name@bank)'), findsOneWidget);
      expect(c.read(shopProvider).gstin, '33AAAAA0000A1Z5', reason: 'a wrong value is not saved');
      await tester.enterText(find.byKey(const ValueKey('shop-name')), 'Shop\u202E Name');
      await tester.pump();
      expect(c.read(shopProvider).name, 'Shop Name');
    });
  });
}
