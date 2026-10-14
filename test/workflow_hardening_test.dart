import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// SECURITY (supply chain): guards on the files that build and publish the program, so nobody can weaken them by accident.
void main() {
  final flows = Directory('.github/workflows').listSync().whereType<File>().where((f) => f.path.endsWith('.yml')).toList();
  String text(File f) => f.readAsStringSync();

  test('every action is pinned to a full commit SHA with the version in a comment', () {
    final uses = RegExp(r'^\s*(?:-\s*)?uses:\s*(\S+)(.*)$', multiLine: true);
    var n = 0;
    for (final f in flows) {
      for (final m in uses.allMatches(text(f))) {
        n++;
        expect(m.group(1), matches(RegExp(r'^[\w.-]+/[\w./-]+@[0-9a-f]{40}$')), reason: '${f.path}: ${m.group(0)}');
        expect(m.group(2), matches(RegExp(r'^\s+#\s*v\d')), reason: '${f.path} needs a "# vX.Y.Z" comment: ${m.group(0)}');
      }
    }
    expect(n, greaterThan(3));
  });

  test('every workflow starts with read-only permissions and none uses pull_request_target', () {
    for (final f in flows) {
      final t = text(f);
      expect(RegExp(r'^permissions:\s*\n\s+contents: read', multiLine: true).hasMatch(t), isTrue, reason: '${f.path} must set top-level permissions to contents: read');
      expect(t, isNot(contains('pull_request_target')), reason: f.path);
      expect(RegExp(r'\$\{\{\s*secrets\.').hasMatch(t), isFalse, reason: '${f.path}: no secrets are needed');
    }
  });

  test('the release runs only for a version tag, checks main and CI, waits for the owner, then attests and checksums', () {
    final t = text(File('.github/workflows/release.yml'));
    expect(t, contains("tags: ['v*']"));
    expect(RegExp(r'^on:\s*\n\s+push:\s*\n\s+tags:', multiLine: true).hasMatch(t), isTrue, reason: 'only a tag push starts it');
    expect(t, contains('merge-base --is-ancestor'), reason: 'tag must be on main');
    expect(t, contains('check-runs'), reason: 'CI must have passed on that commit');
    expect(t, contains('environment: release'), reason: 'manual approval by the owner');
    expect(t, contains('attest-build-provenance'));
    expect(t, contains('SHA256SUMS.txt'));
    expect(t, contains('needs: gate'));
    expect(t, contains('needs: build'));
    // only the publish job may write
    final publish = t.substring(t.indexOf('  publish:'));
    final beforePublish = t.substring(0, t.indexOf('  publish:'));
    expect(publish, contains('contents: write'));
    expect(beforePublish, isNot(contains('contents: write')));
    expect(beforePublish, isNot(contains('attestations: write')));
  });

  test('Dependabot watches the actions, the Dart packages and the Firebase tools', () {
    final t = File('.github/dependabot.yml').readAsStringSync();
    for (final e in ['github-actions', 'pub', 'npm']) {
      expect(t, contains('package-ecosystem: $e'));
    }
    expect(File('firebase/package.json').existsSync() && File('firebase/package-lock.json').existsSync(), isTrue, reason: 'npm needs a manifest to watch');
  });

  test('SECURITY.md tells people how to report a problem and which versions are supported', () {
    final t = File('SECURITY.md').readAsStringSync();
    expect(t, contains('Report a vulnerability'));
    expect(t, contains('Supported versions'));
  });
}
