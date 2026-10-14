// Lists t.<key> / l.<key> uses in lib/ that are missing from tool/strings.txt.
import 'dart:io';

void main() {
  final have = File('tool/strings.txt')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
      .map((l) => l.split(' | ').first.trim())
      .toSet();
  final used = <String, String>{};
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.endsWith('strings.dart') && !f.path.replaceAll(r'\', '/').startsWith('lib/data/') && !f.path.replaceAll(r'\', '/').startsWith('lib/demo/'))) {
    for (final m in RegExp(r'(?<![\w.])(?:l|rl)\.([a-zA-Z]\w*)').allMatches(f.readAsStringSync())) {
      used.putIfAbsent(m.group(1)!, () => f.path);
    }
  }
  final missing = used.keys.where((k) => !have.contains(k)).toList()..sort();
  for (final k in missing) {
    stdout.writeln('MISSING $k   (${used[k]})');
  }
  final unused = have.where((k) => !used.containsKey(k)).length;
  stdout.writeln('${missing.length} missing, $unused unused of ${have.length}');
}
