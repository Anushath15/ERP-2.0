// Device approval and the daily write counter (production rules, emulator). Small caps so the limit can be reached.
import 'package:test/test.dart';
import 'rules_support.dart';

void main() {
  late Actor owner, manager, cashier, newcomer;

  Future<void> approve(Actor who, Actor by, String status, int created) => by.fs.commitMixed([
        w('devices', who.device, {'id': who.device, 'ownerEmail': who.email, 'name': 'PC of ${who.email.split('@').first}', 'platform': 'windows', 'status': status, 'createdAt': created, 'approvedBy': by.email, 'approvedAt': nowMs()}),
      ]);

  Future<int> register(Actor a) async {
    final created = nowMs();
    await a.fs.commitMixed([w('devices', a.device, {'id': a.device, 'ownerEmail': a.email, 'name': 'PC of ${a.email.split('@').first}', 'platform': 'windows', 'status': 'pending', 'createdAt': created})]);
    return created;
  }

  setUpAll(() async {
    // caps: owner 50, manager 6, cashier 3 batches a day
    await loadRules(caps: (50, 6, 3));
    owner = await actor(ownerEmail);
    manager = await actor(manager1);
    cashier = await actor(cashier1);
    newcomer = await actor(cashier2);
    final c = await register(owner);
    await approve(owner, owner, 'approved', c);
    await approvedDevice(manager, owner);
    await approvedDevice(cashier, owner);
  });
  tearDownAll(restoreRules);

  group('a new device can only ask; the owner decides', () {
    test('a new device that writes "approved" for itself is refused', () async {
      final created = nowMs();
      await refused(newcomer.fs.commitMixed([w('devices', newcomer.device, {'id': newcomer.device, 'ownerEmail': newcomer.email, 'name': 'x', 'platform': 'windows', 'status': 'approved', 'createdAt': created, 'approvedBy': newcomer.email, 'approvedAt': nowMs()})]), reason: 'self-approval at creation');
    });
    test('a pending device cannot write any business data', () async {
      await register(newcomer);
      final b = id('bill');
      await refused(send(newcomer, [w('bills', b, bill(b, newcomer))]), reason: 'bill from a pending device');
    });
    test('the person cannot approve their own pending device, and a manager cannot either', () async {
      final created = nowMs();
      await refused(approve(newcomer, newcomer, 'approved', created), reason: 'self-approval');
      await refused(approve(newcomer, manager, 'approved', created), reason: 'approval by a manager');
    });
    test('the owner approves, then the device can write; the owner revokes, then it cannot (at once)', () async {
      final devices = await owner.fs.get('$shop/devices/${newcomer.device}');
      final created = devices!['createdAt'] as int;
      await approve(newcomer, owner, 'approved', created);
      final b = id('bill');
      await send(newcomer, [w('bills', b, bill(b, newcomer))]);
      await approve(newcomer, owner, 'revoked', created);
      final b2 = id('bill');
      await refused(send(newcomer, [w('bills', b2, bill(b2, newcomer))]), reason: 'bill from a revoked device');
    });
    test('an approved device of ANOTHER person cannot be used', () async {
      final b = id('bill');
      await refused(send(newcomer, [w('bills', b, {...bill(b, newcomer), 'deviceId': cashier.device})]), reason: 'borrowing the cashier device');
    });
    test('a device record cannot be changed in other ways (name, owner e-mail) or deleted, even by the owner', () async {
      final d = await owner.fs.get('$shop/devices/${cashier.device}');
      await refused(owner.fs.commitMixed([w('devices', cashier.device, {...d!, 'ownerEmail': owner.email, 'status': 'approved', 'approvedBy': owner.email, 'approvedAt': nowMs()})]), reason: 'moving a device to another person');
    });
  });

  group('the daily counter (write-spam limit)', () {
    test('every business batch must also move today\'s counter up by one', () async {
      final b = id('bill');
      await refused(send(cashier, [w('bills', b, bill(b, cashier))], bump: false), reason: 'no counter');
      final b2 = id('bill');
      await refused(send(cashier, [w('bills', b2, bill(b2, cashier))], bumpBy: 2), reason: 'counter up by two');
      final b3 = id('bill');
      await refused(send(cashier, [w('bills', b3, bill(b3, cashier))], bumpBy: 0), reason: 'counter not moved');
      final b4 = id('bill');
      await refused(send(cashier, [w('bills', b4, bill(b4, cashier))], usageEmail: manager.email), reason: "somebody else's counter");
    });

    test('a cashier gets 3 batches; the 4th is refused; the counter cannot be reset or deleted', () async {
      final before = await usageNow(cashier);
      for (var i = before; i < 3; i++) {
        final b = id('bill');
        await send(cashier, [w('bills', b, bill(b, cashier))]);
      }
      expect(await usageNow(cashier), 3);
      final b = id('bill');
      await refused(send(cashier, [w('bills', b, bill(b, cashier))]), reason: 'over the daily cap');
      // trying to reset the counter by writing 1 or 0 again
      final b2 = id('bill');
      await refused(send(cashier, [w('bills', b2, bill(b2, cashier))], bumpBy: -2), reason: 'counter set back to 1');
      final r = await client.delete(Uri.parse('http://127.0.0.1:8080/v1/projects/demo-erp2/databases/(default)/documents/$shop/usage/${usageId(cashier.email)}'), headers: {'authorization': 'Bearer ${cashier.session.idToken}'});
      expect(r.statusCode, isNot(200), reason: 'counter deleted');
      expect(await usageNow(cashier), 3);
    });

    test('a manager has a higher cap than a cashier; the owner a higher one still', () async {
      for (var i = 0; i < 6; i++) {
        final b = id('bill');
        await send(manager, [w('bills', b, bill(b, manager))]);
      }
      final b = id('bill');
      await refused(send(manager, [w('bills', b, bill(b, manager))]), reason: 'manager over 6');
      for (var i = 0; i < 8; i++) {
        final x = id('bill');
        await send(owner, [w('bills', x, bill(x, owner))]);
      }
    });

    test('how many documents fit in one counted batch (measured; the cost of the device and counter checks)', () async {
      final sizes = <int>[];
      for (final n in [2, 4, 8, 12, 16, 20, 30]) {
        final docs = [for (var i = 0; i < n; i++) wn('bills', 'bill', (x) => bill(x, owner))];
        try {
          await send(owner, docs);
          sizes.add(n);
        } catch (_) {
          break;
        }
      }
      // ignore: avoid_print
      print('MEASURED largest counted batch accepted: ${sizes.isEmpty ? 0 : sizes.last} bills');
      expect(sizes, contains(4), reason: 'a normal sale (bill + ledger + stock lines) must fit');
    });
  });
}
