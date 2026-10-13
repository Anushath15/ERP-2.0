// Design (b): allowed e-mails inside the rules file. Swaps the emulator's rules at run time.
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:s1_rest_sync/rest.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

final client = http.Client();
String? original;

Future<void> setRules(String content) async {
  final r = await client.put(Uri.parse('$fsBase/emulator/v1/projects/$projectId:securityRules'),
      body: jsonEncode({'rules': {'files': [{'name': 'firestore.rules', 'content': content}]}}));
  expect(r.statusCode, 200, reason: r.body);
}

Future<FirestoreRest> user(String email) async {
  final a = AuthRest(client);
  final s = await a.signUp(email, 'secret-pass-1');
  await a.verifyEmailViaEmulator(s);
  await a.refresh(s);
  return FirestoreRest(client, s);
}

void main() {
  final tag = DateTime.now().millisecondsSinceEpoch;
  late String ownerEmail;
  setUpAll(() async {
    original = File('../../firebase/firestore.rules').readAsStringSync();
    ownerEmail = 'owner$tag@example.com';
    await setRules(File('../../firebase/firestore.allowlist.rules').readAsStringSync().replaceAll('__OWNER_EMAIL__', ownerEmail));
  });
  tearDownAll(() async => setRules(original!));

  test('(b) allowed e-mail can write and read; others cannot; no membership docs involved', () async {
    final owner = await user(ownerEmail);
    final other = await user('other$tag@example.com');
    final id = const Uuid().v7();
    final doc = {'id': id, 'deviceId': 'D1', 'updatedAt': 1, 'version': 1, 'total': 5};
    await owner.commit([(path: 'shops/s1/bills/$id', data: doc)]);
    await owner.commit([(path: 'shops/s1/bills/$id', data: doc)]); // duplicate delivery ok
    expect((await owner.get('shops/s1/bills/$id'))!['total'], 5);
    expect(() => other.get('shops/s1/bills/$id'), throwsA(isA<FbException>()));
    expect(() => other.commit([(path: 'shops/s1/bills/x', data: {...doc, 'id': 'x'})]), throwsA(isA<FbException>()));
    expect(() => owner.commit([(path: 'shops/s1/bills/$id', data: {...doc, 'total': 9})]), throwsA(isA<FbException>()));
    final p = const Uuid().v7();
    await owner.commit([(path: 'shops/s1/products/$p', data: {...doc, 'id': p})]);
    expect(await owner.pullAfter('shops/s1', 'bills', null), isNotEmpty);
  });
}
