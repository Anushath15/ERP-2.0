// The shipped daily commit caps (owner 24, manager 24, cashier 16) are the ones in the template, and 500 documents fit in one commit
// (so the documented worst case is cap x 500).
import 'package:test/test.dart';
import 'rules_support.dart';

void main() {
  late Actor owner, cashier;

  setUpAll(() async {
    await loadRules();
    owner = await actor(ownerEmail);
    cashier = await actor(cashier1);
    final c = nowMs();
    await owner.fs.commitMixed([w('devices', owner.device, {'id': owner.device, 'ownerEmail': owner.email, 'name': 'Owner PC', 'platform': 'windows', 'status': 'pending', 'createdAt': c})]);
    await owner.fs.commitMixed([w('devices', owner.device, {'id': owner.device, 'ownerEmail': owner.email, 'name': 'Owner PC', 'platform': 'windows', 'status': 'approved', 'createdAt': c, 'approvedBy': owner.email, 'approvedAt': nowMs()})]);
    await approvedDevice(cashier, owner);
  });
  tearDownAll(restoreRules);

  test('a cashier may commit 16 times a day and not a 17th', () async {
    for (var i = 0; i < 16; i++) {
      final b = id('bill');
      await send(cashier, [w('bills', b, bill(b, cashier))]);
    }
    final b = id('bill');
    await refused(send(cashier, [w('bills', b, bill(b, cashier))]), reason: '17th commit');
  });

  test('the owner may commit 24 times and not a 25th; one commit may hold 500 documents', () async {
    for (var i = 0; i < 23; i++) {
      final b = id('bill');
      await send(owner, [w('bills', b, bill(b, owner))]);
    }
    final docs = [for (var i = 0; i < 499; i++) wn('bills', 'bill', (x) => bill(x, owner))];
    await send(owner, docs); // the 24th commit, 499 documents plus the counter = 500 writes
    final b = id('bill');
    await refused(send(owner, [w('bills', b, bill(b, owner))]), reason: '25th commit');
  });
}
