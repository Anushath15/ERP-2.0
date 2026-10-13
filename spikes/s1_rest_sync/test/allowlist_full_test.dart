// Full rules checks for the design that will be deployed (allow-list in the rules file) on the emulator.
// Swaps the emulator's rules at run time and restores them afterwards.
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

final _users = <String, (FirestoreRest, Session)>{};

Future<(FirestoreRest, Session)> user(String email, {bool verify = true}) async {
  final cached = _users[email];
  if (cached != null) return cached;
  final a = AuthRest(client);
  final s = await a.signUp(email, 'secret-pass-1');
  if (verify) {
    await a.verifyEmailViaEmulator(s);
    await a.refresh(s);
  }
  return _users[email] = (FirestoreRest(client, s), s);
}

Map<String, Object?> doc(String id, [Map<String, Object?> extra = const {}]) => {'id': id, 'deviceId': 'D1', 'updatedAt': 1, 'version': 1, ...extra};

Future<int> rawDelete(Session s, String path) async {
  final r = await client.delete(Uri.parse('$fsBase/v1/projects/$projectId/databases/(default)/documents/$path'), headers: {'authorization': 'Bearer ${s.idToken}'});
  return r.statusCode;
}

void main() {
  final tag = DateTime.now().millisecondsSinceEpoch;
  final ownerEmail = 'owner$tag@example.com';
  final managerEmail = 'manager$tag@example.com';
  final cashierEmail = 'cashier$tag@example.com';
  final unverifiedListed = 'listed$tag@example.com';
  setUpAll(() async {
    original = File('../../firebase/firestore.rules').readAsStringSync();
    final t = File('../../firebase/firestore.allowlist.rules').readAsStringSync();
    expect(t.contains('__OWNER_EMAIL__') && t.contains('/*MANAGERS*/') && t.contains('/*CASHIERS*/'), isTrue);
    await setRules(t
        .replaceAll("/*OWNERS*/'__OWNER_EMAIL__'", "'${ownerEmail.toLowerCase()}', '$unverifiedListed'")
        .replaceAll('/*MANAGERS*/', "'$managerEmail'")
        .replaceAll('/*CASHIERS*/', "'$cashierEmail'"));
  });
  tearDownAll(() async => setRules(original!));

  test('every listed role (owner, manager, cashier) can read and write', () async {
    for (final e in [ownerEmail, managerEmail, cashierEmail]) {
      final (u, _) = await user(e);
      final id = const Uuid().v7();
      await u.commit([(path: 'shops/s1/bills/$id', data: doc(id, {'total': 1}))]);
      expect((await u.get('shops/s1/bills/$id'))!['total'], 1);
    }
  });

  test('a verified person who is not in the lists is denied everything', () async {
    final (u, _) = await user('stranger$tag@example.com');
    final id = const Uuid().v7();
    await expectLater(u.commit([(path: 'shops/s1/bills/$id', data: doc(id))]), throwsA(isA<FbException>()));
    await expectLater(u.get('shops/s1/bills/$id'), throwsA(isA<FbException>()));
    await expectLater(u.pullAfter('shops/s1', 'bills', null), throwsA(isA<FbException>()));
  });

  test('a listed e-mail that is NOT verified is denied (nobody can sign up with the owner address and get in)', () async {
    final (u, _) = await user(unverifiedListed, verify: false);
    final id = const Uuid().v7();
    await expectLater(u.commit([(path: 'shops/s1/bills/$id', data: doc(id))]), throwsA(isA<FbException>()));
    await expectLater(u.get('shops/s1/bills/$id'), throwsA(isA<FbException>()));
  });

  test('not signed in at all is denied', () async {
    final s = Session('not-a-real-token', 'x', 'u', 'x@example.com');
    final id = const Uuid().v7();
    await expectLater(FirestoreRest(client, s).commit([(path: 'shops/s1/bills/$id', data: doc(id))]), throwsA(isA<FbException>()));
  });

  test('append-only records (bills, payments, reminders, cancellations...) cannot be edited or deleted; a repeat of the same record is accepted', () async {
    final (u, s) = await user(ownerEmail);
    for (final coll in ['bills', 'payments', 'reminders', 'billCancellations', 'stockMovements', 'ledgerEntries', 'audit', 'salesReturns', 'purchaseReturns']) {
      final id = const Uuid().v7();
      await u.commit([(path: 'shops/s1/$coll/$id', data: doc(id, {'amount': 5}))]);
      await u.commit([(path: 'shops/s1/$coll/$id', data: doc(id, {'amount': 5}))]); // duplicate delivery
      await expectLater(u.commit([(path: 'shops/s1/$coll/$id', data: doc(id, {'amount': 6}))]), throwsA(isA<FbException>()), reason: '$coll edit');
      expect(await rawDelete(s, 'shops/s1/$coll/$id'), isNot(200), reason: '$coll delete');
      expect((await u.get('shops/s1/$coll/$id'))!['amount'], 5, reason: '$coll unchanged');
    }
  });

  test('editable records (products, customers...) can be edited but never deleted', () async {
    final (u, s) = await user(managerEmail);
    for (final coll in ['products', 'customers', 'dealers', 'categories', 'estimations', 'settingsShared']) {
      final id = const Uuid().v7();
      await u.commit([(path: 'shops/s1/$coll/$id', data: doc(id, {'name': 'a'}))]);
      await u.commit([(path: 'shops/s1/$coll/$id', data: doc(id, {'name': 'b', 'version': 2}))]);
      expect((await u.get('shops/s1/$coll/$id'))!['name'], 'b');
      expect(await rawDelete(s, 'shops/s1/$coll/$id'), isNot(200), reason: '$coll delete');
    }
  });

  test('unknown collections are denied; a record whose id does not match its path is denied; a missing field is denied', () async {
    final (u, _) = await user(ownerEmail);
    final id = const Uuid().v7();
    await expectLater(u.commit([(path: 'shops/s1/secrets/$id', data: doc(id))]), throwsA(isA<FbException>()));
    await expectLater(u.commit([(path: 'shops/s1/products/$id', data: doc('different-id'))]), throwsA(isA<FbException>()));
    await expectLater(u.commit([(path: 'shops/s1/products/$id', data: {'id': id, 'updatedAt': 1})]), throwsA(isA<FbException>())); // no deviceId
    await expectLater(u.commit([(path: 'rootThing/$id', data: doc(id))]), throwsA(isA<FbException>()));
  });

  test('a record with more than 60 fields is denied (cannot be used to stuff the free storage)', () async {
    final (u, _) = await user(ownerEmail);
    final id = const Uuid().v7();
    final big = {for (var i = 0; i < 70; i++) 'f$i': i};
    await expectLater(u.commit([(path: 'shops/s1/products/$id', data: doc(id, big))]), throwsA(isA<FbException>()));
  });

  test('one bad record in a batch rejects the whole batch (nothing half-saved)', () async {
    final (u, _) = await user(ownerEmail);
    final good = const Uuid().v7(), bad = const Uuid().v7();
    await expectLater(u.commit([(path: 'shops/s1/bills/$good', data: doc(good)), (path: 'shops/s1/secrets/$bad', data: doc(bad))]), throwsA(isA<FbException>()));
    expect(await u.get('shops/s1/bills/$good'), isNull);
  });
}
