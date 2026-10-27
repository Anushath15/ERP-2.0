import 'dart:convert';
import 'package:erp2/core/update_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// What these tests prove: versions are compared by their numbers (2.10 is newer than 2.9; a plain 2.1.0 is newer than a 2.1.0-beta); a newer
// GitHub release is reported with its notes and the installer's own download address; an older or equal one, a draft, a pre-release, a strange
// address, an error or no internet report nothing (and never break the program).
void main() {
  test('version order', () {
    expect(isNewerVersion('2.1.0', '2.0.0-proto.3'), isTrue);
    expect(isNewerVersion('v2.10.0', '2.9.9'), isTrue);
    expect(isNewerVersion('2.1', '2.1.0'), isFalse);
    expect(isNewerVersion('2.1.0', '2.1.0-beta'), isTrue);
    expect(isNewerVersion('2.1.0-beta', '2.1.0'), isFalse);
    expect(isNewerVersion('2.0.9', '2.1.0'), isFalse);
  });

  String release({String tag = 'v2.2.0', bool draft = false, bool pre = false, String exe = 'https://github.com/Anushath15/ERP-2.0/releases/download/v2.2.0/ASK-ERP-2.0-Setup.exe', String page = 'https://github.com/Anushath15/ERP-2.0/releases/tag/v2.2.0'}) =>
      jsonEncode({'tag_name': tag, 'draft': draft, 'prerelease': pre, 'html_url': page, 'body': 'Bill again, Trash, reports', 'assets': [{'name': 'ASK-ERP-2.0-Setup.exe', 'browser_download_url': exe}]});

  Future<UpdateInfo?> ask(http.Response Function(http.Request) answer, {String current = '2.1.0'}) => checkForUpdate(client: MockClient((r) async => answer(r)), current: current);

  test('a newer release is reported with its notes and the installer address; GitHub is asked for the latest release', () async {
    Uri? asked;
    final u = await ask((r) {
      asked = r.url;
      return http.Response(release(), 200);
    });
    expect(asked.toString(), 'https://api.github.com/repos/Anushath15/ERP-2.0/releases/latest');
    expect(u!.version, '2.2.0');
    expect(u.notes, contains('Bill again'));
    expect(u.downloadUrl, endsWith('ASK-ERP-2.0-Setup.exe'));
  });

  test('nothing to report: the same or older version, a draft, a pre-release, an error, no internet, a strange address', () async {
    expect(await ask((_) => http.Response(release(tag: 'v2.1.0'), 200)), isNull);
    expect(await ask((_) => http.Response(release(tag: 'v2.0.5'), 200)), isNull);
    expect(await ask((_) => http.Response(release(draft: true), 200)), isNull);
    expect(await ask((_) => http.Response(release(pre: true), 200)), isNull);
    expect(await ask((_) => http.Response('{"message":"Not Found"}', 404)), isNull);
    expect(await ask((_) => http.Response('not json', 200)), isNull);
    expect(await checkForUpdate(client: MockClient((_) async => throw Exception('no internet')), current: '2.1.0'), isNull);
    expect(await ask((_) => http.Response(release(page: 'https://evil.example/x'), 200)), isNull);
    final u = await ask((_) => http.Response(release(exe: 'https://evil.example/Setup.exe'), 200));
    expect(u!.downloadUrl, isEmpty, reason: 'only GitHub download addresses are ever opened');
  });
}
