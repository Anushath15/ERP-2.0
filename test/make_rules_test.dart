import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/rules_builder.dart';

// SECURITY: the rules that are deployed are made from the template and the private list of people. A typo or a hostile
// value in that list must never produce rules that are broken or let somebody in.
void main() {
  final src = File('firebase/firestore.allowlist.rules').readAsStringSync();
  Map<String, dynamic> people({List<String> owners = const ['shop@example.com'], List<String> managers = const [], List<String> cashiers = const [], Map<String, dynamic>? caps}) =>
      {'owners': owners, 'managers': managers, 'cashiers': cashiers, 'caps': ?caps};

  test('the people are written into the rules, lower-cased, and no placeholder is left', () {
    final out = buildRules(src, people(owners: ['Shop@Example.com', 'me@example.com'], managers: ['m@example.com'], cashiers: ['c1@example.com', 'c2@example.com']));
    expect(out, contains("['shop@example.com', 'me@example.com']"));
    expect(out, contains("'m@example.com'"));
    expect(out, contains("'c2@example.com'"));
    expect(out, isNot(contains('__OWNER_EMAIL__')));
    expect(out, isNot(contains('/*OWNERS*/')));
    expect(out, isNot(contains('/*CAP_')));
  });

  test('daily caps can be changed; the defaults are used otherwise', () {
    expect(buildRules(src, people()), contains('isOwner() ? 24 : (isManager() ? 24 : 20)'), reason: 'defaults: owner 24, manager 24, cashier 20 batches a day');
    final out = buildRules(src, people(caps: {'owner': 10, 'manager': 20, 'cashier': 30}));
    expect(out, contains('isOwner() ? 10 : (isManager() ? 20 : 30)'));
  });

  test('an address that is not a plain address is refused (quotes, spaces, brackets could break out of the list)', () {
    for (final bad in ["a'b@example.com", 'a b@example.com', 'a@example.com, b@example.com', "x'] || true || ['y@example.com", 'noatsign', '', 'a@b', '<x>@example.com', 'a@example.com\nb@example.com']) {
      expect(() => buildRules(src, people(owners: ['ok@example.com'], cashiers: [bad])), throwsFormatException, reason: 'address "$bad"');
    }
  });

  test('no owner at all, the same person in two roles, or silly caps are refused', () {
    expect(() => buildRules(src, people(owners: [])), throwsFormatException);
    expect(() => buildRules(src, people(managers: ['shop@example.com'])), throwsFormatException);
    expect(() => buildRules(src, people(cashiers: ['x@example.com'], managers: ['X@example.com'])), throwsFormatException);
    for (final caps in [{'owner': 0}, {'cashier': -5}, {'manager': 'many'}, {'owner': 99999999}]) {
      expect(() => buildRules(src, people(caps: caps)), throwsFormatException, reason: '$caps');
    }
  });

  test('a template with an unknown placeholder left over is refused', () {
    expect(() => buildRules('$src\n/*CAP_NEW*/', people()), throwsFormatException);
  });
}
