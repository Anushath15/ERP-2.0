import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// SECURITY ("Trojan Source"): characters that are invisible or that change the order text is DISPLAYED in (bidirectional overrides,
// zero-width characters, control characters) can hide what source code or documents really say. None may appear in our files.
// (Written with numbers, not with the characters themselves, so that this file cannot contain them either.)
bool hidden(int c) =>
    (c <= 0x08) ||
    c == 0x0B ||
    c == 0x0C ||
    (c >= 0x0E && c <= 0x1F) ||
    (c >= 0x7F && c <= 0x9F) ||
    (c >= 0x200B && c <= 0x200F) ||
    (c >= 0x202A && c <= 0x202E) ||
    c == 0x2060 ||
    (c >= 0x2066 && c <= 0x2069) ||
    c == 0x2028 ||
    c == 0x2029 ||
    c == 0xFEFF;

void main() {
  test('no source, document or workflow file contains a hidden or direction-changing character', () {
    const folders = ['lib', 'test', 'tool', 'docs', '.github', 'firebase', 'spikes', 'web', 'windows', 'android', 'macos'];
    const kinds = ['.dart', '.md', '.yml', '.yaml', '.json', '.txt', '.js', '.py', '.html', '.rules', '.cpp', '.rc', '.xml', '.xcconfig', '.plist', '.gradle', '.kts', '.cmake'];
    final problems = <String>[];
    var checked = 0;
    for (final folder in folders) {
      final dir = Directory(folder);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true, followLinks: false).whereType<File>()) {
        final p = f.path.replaceAll(r'\', '/');
        if (!kinds.any(p.endsWith) || p.contains('/build/') || p.contains('/.dart_tool/') || p.contains('/node_modules/') || p.contains('/ui-review/') || p.contains('/ephemeral/') || p.contains('/.gradle/')) continue;
        String text;
        try {
          text = f.readAsStringSync();
        } catch (_) {
          continue; // not text
        }
        checked++;
        final runes = text.runes.toList();
        for (var i = 0; i < runes.length; i++) {
          if (i == 0 && runes[i] == 0xFEFF) continue; // a byte-order mark at the very start is normal
          if (hidden(runes[i])) {
            problems.add('$p: U+${runes[i].toRadixString(16).toUpperCase()} at character $i');
            break;
          }
        }
      }
    }
    for (final top in ['README.md', 'SECURITY.md', 'pubspec.yaml']) {
      final f = File(top);
      if (f.existsSync() && f.readAsStringSync().runes.skip(1).any(hidden)) problems.add(top);
    }
    expect(checked, greaterThan(100));
    expect(problems, isEmpty);
  });
}
