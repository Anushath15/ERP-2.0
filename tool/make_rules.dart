// Makes the deployable Firestore rules from firebase/firestore.allowlist.rules and the people in
// firebase/allowed-emails.local.json (git-ignored; never committed). Run from the project folder:
//   dart run tool/make_rules.dart
// File format:  {"owners": ["shop@gmail.com", "me@gmail.com"], "managers": [], "cashiers": [], "caps": {"owner": 4000, "manager": 3000, "cashier": 1500}}  (caps optional)
// Output: firebase/deploy/firestore.rules (git-ignored)
import 'dart:convert';
import 'dart:io';
import 'rules_builder.dart';

void main() {
  final src = File('firebase/firestore.allowlist.rules').readAsStringSync();
  final f = File('firebase/allowed-emails.local.json');
  if (!f.existsSync()) {
    stderr.writeln('Missing firebase/allowed-emails.local.json (see the header of this file).');
    exit(1);
  }
  try {
    final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final out = buildRules(src, j);
    Directory('firebase/deploy').createSync(recursive: true);
    File('firebase/deploy/firestore.rules').writeAsStringSync(out);
    stdout.writeln('Wrote firebase/deploy/firestore.rules for ${(j['owners'] as List).length} owner(s), ${(j['managers'] as List? ?? const []).length} manager(s), ${(j['cashiers'] as List? ?? const []).length} cashier(s).');
  } on FormatException catch (e) {
    stderr.writeln('Not written: ${e.message}');
    exit(1);
  }
}
