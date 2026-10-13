// Spike S1 (REST fallback) + security-rules tests against the emulator.
// Run the emulator first:  firebase emulators:start --only auth,firestore --project demo-erp2
import 'package:http/http.dart' as http;
import 'package:s1_rest_sync/rest.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

const _u = Uuid();
final client = http.Client();

Future<(Session, FirestoreRest)> newUser(String email, {bool verify = true}) async {
  final a = AuthRest(client);
  final s = await a.signUp(email, 'secret-pass-1');
  if (verify) {
    await a.verifyEmailViaEmulator(s);
    await a.refresh(s); // new token carries email_verified=true
  }
  return (s, FirestoreRest(client, s));
}

Map<String, Object?> rec(String id, {String device = 'D1', Map<String, Object?>? extra}) => {
      'id': id,
      'deviceId': device,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'version': 1,
      ...?extra,
    };

Future<String> makeShop(FirestoreRest fs, String shopId, String email) async {
  await fs.commit([
    (path: 'shops/$shopId', data: {'id': shopId, 'deviceId': 'D1', 'updatedAt': 1, 'ownerEmail': email, 'name': 'Demo Shop'}),
  ]);
  return shopId;
}

void main() {
  final tag = DateTime.now().millisecondsSinceEpoch;

  test('S1: sign up, verify, sign in, token refresh, read/write round trip', () async {
    final email = 'owner$tag@example.com';
    final (s, fs) = await newUser(email);
    expect(s.idToken, isNotEmpty);
    final shop = 'shop-a-$tag';
    // shop doc needs serverAt per smallDoc? No: shops/{id} create rule only needs ownerEmail.
    final r = await client.post(
        Uri.parse('$fsBase/v1/projects/$projectId/databases/(default)/documents:commit'),
        headers: {'content-type': 'application/json', 'authorization': 'Bearer ${s.idToken}'},
        body: '{"writes":[{"update":{"name":"projects/$projectId/databases/(default)/documents/shops/$shop","fields":{"ownerEmail":{"stringValue":"$email"},"name":{"stringValue":"Demo"}}}},'
            '{"update":{"name":"projects/$projectId/databases/(default)/documents/shops/$shop/members/$email","fields":{"role":{"stringValue":"owner"}}}}]}');
    expect(r.statusCode, 200, reason: r.body);
    final p = _u.v7();
    await fs.commit([(path: 'shops/$shop/products/$p', data: rec(p, extra: {'name': 'Havells wire 1.5 sq mm', 'pricePaise': 123400}))]);
    final got = await fs.get('shops/$shop/products/$p');
    expect(got!['name'], 'Havells wire 1.5 sq mm');
    expect(got['pricePaise'], 123400);
    expect(got['serverAt'], isNotNull);
  });

  test('rules: other shop cannot be read; unverified email denied; non-member denied', () async {
    final e1 = 'a$tag@example.com', e2 = 'b$tag@example.com', e3 = 'c$tag@example.com';
    final (s1, f1) = await newUser(e1);
    final (_, f2) = await newUser(e2);
    final (_, f3) = await newUser(e3, verify: false);
    final shop = 'shop-b-$tag';
    await _createShop(f1, s1, shop, e1);
    final id = _u.v7();
    await f1.commit([(path: 'shops/$shop/bills/$id', data: rec(id))]);
    // user 2 (verified, not a member) cannot read or write
    expect(() => f2.get('shops/$shop/bills/$id'), throwsA(isA<FbException>().having((e) => e.isPermissionDenied, 'denied', true)));
    final id2 = _u.v7();
    expect(() => f2.commit([(path: 'shops/$shop/bills/$id2', data: rec(id2))]), throwsA(isA<FbException>()));
    // user 3 (unverified) cannot even create a shop
    expect(() => _createShop(f3, f3.session, 'shop-c-$tag', e3), throwsA(isA<FbException>()));
    // user 2 cannot make themself member of shop B
    expect(
        () => f2.commit([(path: 'shops/$shop/members/$e2', data: {'id': e2, 'deviceId': 'D', 'updatedAt': 1, 'role': 'owner'})]),
        throwsA(isA<FbException>()));
    // user 2 cannot create a shop claiming to be owned by someone else
    expect(() => _createShop(f2, f2.session, 'shop-evil-$tag', e1), throwsA(isA<FbException>()));
  });

  test('rules: append-only cannot be edited/deleted, master data can; resend is harmless', () async {
    final e = 'ao$tag@example.com';
    final (s, fs) = await newUser(e);
    final shop = 'shop-d-$tag';
    await _createShop(fs, s, shop, e);
    final b = _u.v7();
    final bill = rec(b, extra: {'total': 100});
    await fs.commit([(path: 'shops/$shop/bills/$b', data: bill)]);
    // duplicate delivery of the SAME record: must succeed (idempotent)
    await fs.commit([(path: 'shops/$shop/bills/$b', data: bill)]);
    // tampering with content: must fail
    expect(() => fs.commit([(path: 'shops/$shop/bills/$b', data: {...bill, 'total': 999})]), throwsA(isA<FbException>()));
    // master data may be edited
    final p = _u.v7();
    await fs.commit([(path: 'shops/$shop/products/$p', data: rec(p, extra: {'name': 'x'}))]);
    await fs.commit([(path: 'shops/$shop/products/$p', data: rec(p, extra: {'name': 'y', 'version': 2}))]);
    expect((await fs.get('shops/$shop/products/$p'))!['name'], 'y');
    // unknown collection denied
    final z = _u.v7();
    expect(() => fs.commit([(path: 'shops/$shop/secrets/$z', data: rec(z))]), throwsA(isA<FbException>()));
    // oversize (too many fields) denied
    final big = rec(_u.v7(), extra: {for (var i = 0; i < 70; i++) 'f$i': i});
    expect(() => fs.commit([(path: 'shops/$shop/products/${big['id']}', data: big)]), throwsA(isA<FbException>()));
    // id mismatch denied
    expect(() => fs.commit([(path: 'shops/$shop/products/some-other-id', data: rec(_u.v7()))]), throwsA(isA<FbException>()));
  });

  test('rules: revoked device cannot write; staff roles', () async {
    final eo = 'ro$tag@example.com', ec = 'cashier$tag@example.com';
    final (so, fo) = await newUser(eo);
    final (_, fc) = await newUser(ec);
    final shop = 'shop-e-$tag';
    await _createShop(fo, so, shop, eo);
    // owner adds cashier by email
    await fo.commit([(path: 'shops/$shop/members/$ec', data: {'id': ec, 'deviceId': 'D1', 'updatedAt': 1, 'role': 'cashier'})]);
    final b = _u.v7();
    await fc.commit([(path: 'shops/$shop/bills/$b', data: rec(b, device: 'LAPTOP'))]);
    // cashier cannot add members
    expect(() => fc.commit([(path: 'shops/$shop/members/x@example.com', data: {'id': 'x@example.com', 'deviceId': 'D1', 'updatedAt': 1, 'role': 'owner'})]), throwsA(isA<FbException>()));
    // owner revokes the LAPTOP device
    await fo.commit([(path: 'shops/$shop/revokedDevices/LAPTOP', data: rec('LAPTOP'))]);
    final b2 = _u.v7();
    expect(() => fc.commit([(path: 'shops/$shop/bills/$b2', data: rec(b2, device: 'LAPTOP'))]), throwsA(isA<FbException>()));
    final b3 = _u.v7();
    await fc.commit([(path: 'shops/$shop/bills/$b3', data: rec(b3, device: 'PHONE'))]);
  });

  test('S1: batch of 500 and cursor pull; reads counted', () async {
    final e = 'bat$tag@example.com';
    final (s, fs) = await newUser(e);
    final shop = 'shop-f-$tag';
    await _createShop(fs, s, shop, e);
    final sw = Stopwatch()..start();
    final ids = <String>[];
    final docs = <({String path, Map<String, Object?> data})>[];
    for (var i = 0; i < 500; i++) {
      final id = _u.v7();
      ids.add(id);
      docs.add((path: 'shops/$shop/bills/$id', data: rec(id, extra: {'total': i})));
    }
    await fs.commit(docs);
    print('batch of 500 bills committed in ${sw.elapsedMilliseconds} ms');
    // first pull (page of 300), then pull after cursor
    final page1 = await fs.pullAfter('shops/$shop', 'bills', null, limit: 300);
    expect(page1.length, 300);
    final cursor = page1.last['serverAt'] as String;
    final page2 = await fs.pullAfter("shops/$shop", "bills", (ts: cursor, id: page1.last["id"] as String), limit: 300);
    // all 500 share one commit timestamp, so the serverAt cursor alone cannot split them:
    expect(page2.length, 200);
    final none = await fs.pullAfter("shops/$shop", "bills", (ts: DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(), id: "zzz"));
    expect(none, isEmpty);
  });

  test('S1: wrong token / expired-style token is rejected cleanly', () async {
    final e = 'tok$tag@example.com';
    final (s, fs) = await newUser(e);
    final shop = 'shop-g-$tag';
    await _createShop(fs, s, shop, e);
    final bad = FirestoreRest(client, Session('garbage', 'x', 'u', e));
    expect(() => bad.get('shops/$shop'), throwsA(isA<FbException>()));
  });
}

Future<void> _createShop(FirestoreRest fs, Session s, String shop, String email) async {
  final base = 'projects/$projectId/databases/(default)/documents';
  final r = await client.post(Uri.parse('$fsBase/v1/$base:commit'),
      headers: {'content-type': 'application/json', 'authorization': 'Bearer ${s.idToken}'},
      body: '{"writes":[{"update":{"name":"$base/shops/$shop","fields":{"ownerEmail":{"stringValue":"$email"},"name":{"stringValue":"Demo"}}}},'
          '{"update":{"name":"$base/shops/$shop/members/$email","fields":{"role":{"stringValue":"owner"}}}}]}');
  if (r.statusCode != 200) throw FbException(r.statusCode, 'PERMISSION_DENIED', r.body);
}
