// Makes the deployable Firestore rules from firebase/firestore.allowlist.rules and the people in
// firebase/allowed-emails.local.json (git-ignored; never committed). Run from the project folder:
//   dart run tool/make_rules.dart
// File format:  {"owners": ["shop@gmail.com", "me@gmail.com"], "managers": [], "cashiers": []}
// Output: firebase/deploy/firestore.rules (git-ignored)
import 'dart:convert';
import 'dart:io';

String list(Object? v) => [for (final e in (v as List? ?? const [])) "'${e.toString().trim().toLowerCase().replaceAll("'", '')}'"].join(', ');

void main() {
  final src = File('firebase/firestore.allowlist.rules').readAsStringSync();
  final f = File('firebase/allowed-emails.local.json');
  if (!f.existsSync()) {
    stderr.writeln('Missing firebase/allowed-emails.local.json (see the header of this file).');
    exit(1);
  }
  final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final owners = list(j['owners']);
  if (owners.isEmpty) {
    stderr.writeln('At least one owner e-mail is needed.');
    exit(1);
  }
  final out = src
      .replaceAll("/*OWNERS*/'__OWNER_EMAIL__'", owners)
      .replaceAll('/*MANAGERS*/', list(j['managers']))
      .replaceAll('/*CASHIERS*/', list(j['cashiers']));
  Directory('firebase/deploy').createSync(recursive: true);
  File('firebase/deploy/firestore.rules').writeAsStringSync(out);
  stdout.writeln('Wrote firebase/deploy/firestore.rules for ${owners.split(',').length} owner(s).');
}
