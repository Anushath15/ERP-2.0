// Builds lib/l10n/app_en.arb and app_ta.arb from l10n_src/strings.txt (one line per string:
//   key | English | Tamil). {name} placeholders become String parameters.
// Then run: flutter gen-l10n
import 'dart:convert';
import 'dart:io';

void main() {
  final lines = File('l10n_src/strings.txt').readAsLinesSync();
  final en = <String, Object>{'@@locale': 'en'};
  final ta = <String, Object>{'@@locale': 'ta'};
  final seen = <String>{};
  var n = 0;
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split(' | ');
    if (parts.length != 3) {
      stderr.writeln('BAD LINE (need 3 parts): $line');
      exitCode = 1;
      continue;
    }
    final key = parts[0].trim();
    if (!seen.add(key)) {
      stderr.writeln('DUPLICATE KEY: $key');
      exitCode = 1;
      continue;
    }
    final e = parts[1].trim().replaceAll(r'\n', '\n');
    final t = parts[2].trim().replaceAll(r'\n', '\n');
    final ph = RegExp(r'\{(\w+)\}').allMatches(e).map((m) => m.group(1)!).toSet();
    final ph2 = RegExp(r'\{(\w+)\}').allMatches(t).map((m) => m.group(1)!).toSet();
    if (ph.length != ph2.length || !ph.containsAll(ph2)) {
      stderr.writeln('PLACEHOLDER MISMATCH: $key');
      exitCode = 1;
    }
    en[key] = e;
    ta[key] = t;
    if (ph.isNotEmpty) {
      final meta = {
        'placeholders': {for (final p in ph) p: {'type': 'String'}}
      };
      en['@$key'] = meta;
      ta['@$key'] = meta;
    }
    n++;
  }
  const enc = JsonEncoder.withIndent('  ');
  File('lib/l10n/app_en.arb').writeAsStringSync(enc.convert(en));
  File('lib/l10n/app_ta.arb').writeAsStringSync(enc.convert(ta));
  stdout.writeln('wrote $n strings');
}
