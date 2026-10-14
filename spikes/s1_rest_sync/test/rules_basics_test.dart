// The basics that must always hold with the production rules: identity, retries, edits, atomic batches (emulator).
import 'package:s1_rest_sync/rest.dart';
import 'package:test/test.dart';
import 'rules_support.dart';

void main() {
  late Actor owner, manager, cashier;

  setUpAll(() async {
    await loadRules();
    owner = await actor(ownerEmail);
    manager = await actor(manager1);
    cashier = await actor(cashier1);
    final c = nowMs();
    await owner.fs.commitMixed([w('devices', owner.device, {'id': owner.device, 'ownerEmail': owner.email, 'name': 'Owner PC', 'platform': 'windows', 'status': 'pending', 'createdAt': c})]);
    await owner.fs.commitMixed([w('devices', owner.device, {'id': owner.device, 'ownerEmail': owner.email, 'name': 'Owner PC', 'platform': 'windows', 'status': 'approved', 'createdAt': c, 'approvedBy': owner.email, 'approvedAt': nowMs()})]);
    await approvedDevice(manager, owner);
    await approvedDevice(cashier, owner);
  });
  tearDownAll(restoreRules);

  test('a listed e-mail that is NOT verified is refused (nobody can sign up with the owner address)', () async {
    final unv = 'unverified$run@example.com';
    await loadRules(owners: [ownerEmail, unv]);
    try {
      final a = AuthRest(client);
      final s = await a.signUp(unv, 'secret-pass-1'); // never verified
      final f = FirestoreRest(client, s);
      await refused(f.commitMixed([w('devices', 'dev-unverified', {'id': 'dev-unverified', 'ownerEmail': unv, 'name': 'x', 'platform': 'windows', 'status': 'pending', 'createdAt': nowMs()})]));
      await refused(f.get('$shop/bills/x'));
    } finally {
      await loadRules();
    }
  });

  test('not signed in at all is refused', () async {
    final f = FirestoreRest(client, Session('not-a-real-token', 'x', 'u', 'x@example.com'));
    await refused(f.get('$shop/bills/x'));
  });

  test('a record sent twice (a retry after a lost reply) is accepted; a changed copy is not', () async {
    final b = id('bill');
    final d = bill(b, cashier);
    await send(cashier, [w('bills', b, d)]);
    await send(cashier, [w('bills', b, d)]);
    await refused(send(cashier, [w('bills', b, {...d, 'totalPaise': 1})]), reason: 'changed copy of a bill');
  });

  test('an editable record is edited one version at a time, never deleted, never by skipping a version', () async {
    final p = id('prod');
    await send(manager, [w('products', p, product(p, manager))]);
    await send(manager, [w('products', p, {...product(p, manager), 'version': 2, 'name': 'Renamed'})]);
    await refused(send(manager, [w('products', p, {...product(p, manager), 'version': 9, 'name': 'Skipped'})]), reason: 'version skipped');
    await refused(send(manager, [w('products', p, {...product(p, manager), 'version': 2, 'name': 'Stale'})]), reason: 'stale version');
    final r = await client.delete(Uri.parse('http://127.0.0.1:8080/v1/projects/demo-erp2/databases/(default)/documents/$shop/products/$p'), headers: {'authorization': 'Bearer ${manager.session.idToken}'});
    expect(r.statusCode, isNot(200));
  });

  test('a record with more than 60 fields is refused', () async {
    final b = id('bill');
    await refused(send(cashier, [w('bills', b, {...bill(b, cashier), for (var i = 0; i < 70; i++) 'f$i': i})]));
  });

  test('one bad record in a batch rejects the whole batch (nothing half-saved)', () async {
    final good = id('bill');
    final bad = id('bill');
    await refused(send(cashier, [w('bills', good, bill(good, cashier)), w('bills', bad, {...bill(bad, cashier), 'totalPaise': -5})]));
    expect(await cashier.fs.get('$shop/bills/$good'), isNull);
  });
}
