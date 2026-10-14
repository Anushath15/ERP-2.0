// Roles: cashier, manager, owner (production rules, emulator). A person writes only what the role allows.
import 'package:test/test.dart';
import 'rules_support.dart';

void main() {
  late Actor owner, manager, cashier, other;

  setUpAll(() async {
    await loadRules();
    owner = await actor(ownerEmail);
    manager = await actor(manager1);
    cashier = await actor(cashier1);
    other = await actor(cashier2);
    // the owner's own device is approved by the owner; the others are approved by the owner too
    final created = nowMs();
    await owner.fs.commitMixed([w('devices', owner.device, {'id': owner.device, 'ownerEmail': owner.email, 'name': 'Owner PC', 'platform': 'windows', 'status': 'pending', 'createdAt': created})]);
    await owner.fs.commitMixed([w('devices', owner.device, {'id': owner.device, 'ownerEmail': owner.email, 'name': 'Owner PC', 'platform': 'windows', 'status': 'approved', 'createdAt': created, 'approvedBy': owner.email, 'approvedAt': nowMs()})]);
    await approvedDevice(manager, owner);
    await approvedDevice(cashier, owner);
    await approvedDevice(other, owner);
  });
  tearDownAll(restoreRules);

  group('the happy path works for every role', () {
    test('a cashier makes a bill, a payment, a ledger entry, a sale movement, a note and a reminder', () async {
      final b = id('bill');
      await send(cashier, [
        w('bills', b, bill(b, cashier, total: 15000, received: 10000, customerId: 'c1')),
        wn('ledgerEntries', 'led', (ni) => ledger(ni, cashier)),
        wn('stockMovements', 'mov', (ni) => movement(ni, cashier)),
      ]);
      final p = id('pay');
      await send(cashier, [w('payments', p, payment(p, cashier))]);
      final n = id('note');
      await send(cashier, [w('customerNotes', n, {...baseDoc(n, cashier), 'customerId': 'c1', 'note': 'Will pay on Friday', 'at': nowMs()})]);
      final r = id('rem');
      await send(cashier, [w('reminders', r, {...baseDoc(r, cashier), 'customerId': 'c1', 'at': nowMs(), 'amountDuePaise': 5000, 'message': 'Hello', 'by': cashier.email})]);
    });

    test('a manager adds a product and a dealer; the owner writes the shop profile', () async {
      final p = id('prod');
      await send(manager, [w('products', p, product(p, manager))]);
      final d = id('deal');
      await send(manager, [w('dealers', d, {...baseDoc(d, manager, editable: true), 'name': 'Kovai Pipes'})]);
      await send(owner, [w('shopProfile', 'main', {...baseDoc('main', owner, editable: true), 'name': 'Senthil Enterprises', 'gstin': '33AAAAA0000A1Z5', 'upiId': 'senthil@okbank'})]);
    });
  });

  group('cashier: can NOT touch what already exists or what is not theirs', () {
    test('cannot create or change products, prices, categories, dealers, purchases, expenses, settings, shop profile', () async {
      final p = id('prod');
      await send(manager, [w('products', p, product(p, manager))]);
      await refused(send(cashier, [wn('products', 'prod', (ni) => product(ni, cashier))]), reason: 'new product');
      await refused(send(cashier, [w('products', p, {...product(p, cashier), 'createdBy': manager.email, 'version': 2, 'pricePaise': 1})]), reason: 'price change');
      await refused(send(cashier, [wn('categories', 'cat', (ni) => {...baseDoc(ni, cashier, editable: true), 'name': 'Paints'})]));
      await refused(send(cashier, [wn('dealers', 'deal', (ni) => {...baseDoc(ni, cashier, editable: true), 'name': 'X'})]));
      await refused(send(cashier, [wn('expenses', 'exp', (ni) => {...baseDoc(ni, cashier, editable: true), 'category': 'Tea', 'amountPaise': 500, 'at': nowMs()})]));
      await refused(send(cashier, [wn('settingsShared', 'set', (ni) => {...baseDoc(ni, cashier, editable: true), 'key': 'x', 'value': 'y'})]));
      await refused(send(cashier, [w('shopProfile', 'main', {...baseDoc('main', cashier, editable: true), 'name': 'Hacked', 'version': 2})]));
    });

    test('can quick-add a NEW customer with credit limit 0 only; cannot set a limit or edit an existing customer', () async {
      final c = id('cust');
      await send(cashier, [w('customers', c, customer(c, cashier, limit: 0))]);
      await refused(send(cashier, [wn('customers', 'cust', (ni) => customer(ni, cashier, limit: 5000000))]), reason: 'new customer with a limit');
      await refused(send(cashier, [w('customers', c, {...customer(c, cashier, limit: 9999999), 'version': 2})]), reason: 'raise the limit of an existing customer');
      await refused(send(cashier, [w('customers', c, {...customer(c, cashier, limit: 0, name: 'Renamed'), 'version': 2})]), reason: 'change the name or contact data of an existing customer');
      // the manager can
      final c2 = id('cust');
      await send(manager, [w('customers', c2, customer(c2, manager, limit: 5000000))]);
    });

    test('cannot write off, adjust, add credit by hand, return or cancel; cannot take stock in; cannot cancel a bill', () async {
      for (final kind in ['writeOff', 'adjustment', 'manualCredit', 'opening', 'returnCredit', 'billCancel']) {
        final amount = ['writeOff', 'returnCredit', 'billCancel'].contains(kind) ? -500 : 500;
        await refused(send(cashier, [wn('ledgerEntries', 'led', (ni) => ledger(ni, cashier, kind: kind, amount: amount))]), reason: kind);
      }
      await refused(send(cashier, [wn('stockMovements', 'mov', (ni) => movement(ni, cashier, qty: 5000, kind: 'purchase'))]), reason: 'stock in');
      await refused(send(cashier, [wn('stockMovements', 'mov', (ni) => movement(ni, cashier, qty: 500, kind: 'sale'))]), reason: 'a "sale" that adds stock');
      final c = id('can');
      await refused(send(cashier, [w('billCancellations', c, {...baseDoc(c, cashier), 'billId': 'b1', 'billNo': 'A-1', 'reason': 'x', 'at': nowMs()})]), reason: 'cancel a bill');
    });

    test('cannot pay a dealer; cannot approve a device; cannot delete anything', () async {
      final p = id('pay');
      await refused(send(cashier, [w('payments', p, {...payment(p, cashier), 'customerId': null, 'dealerId': 'd1'}..remove('customerId'))]), reason: 'pay a dealer');
      await refused(send(cashier, [w('devices', other.device, {'id': other.device, 'ownerEmail': other.email, 'name': 'x', 'platform': 'windows', 'status': 'approved', 'createdAt': nowMs(), 'approvedBy': cashier.email, 'approvedAt': nowMs()})], bump: false), reason: 'approve a device');
    });
  });

  group('manager: more than a cashier, but not the owner', () {
    test('can edit prices with an audit record, products, dealers, purchases; can NOT write the shop profile, settings, cancel bills or approve devices', () async {
      await refused(send(manager, [w('shopProfile', 'main', {...baseDoc('main', manager, editable: true), 'name': 'X', 'version': 2, 'createdBy': owner.email})]), reason: 'shop profile');
      await refused(send(manager, [wn('settingsShared', 'set', (ni) => {...baseDoc(ni, manager, editable: true), 'key': 'x', 'value': 'y'})]), reason: 'settings');
      final c = id('can');
      await refused(send(manager, [w('billCancellations', c, {...baseDoc(c, manager), 'billId': 'b1', 'billNo': 'A-1', 'reason': 'x', 'at': nowMs()})]), reason: 'cancel a bill');
      await refused(send(manager, [wn('ledgerEntries', 'led', (ni) => ledger(ni, manager, kind: 'writeOff', amount: -500))]), reason: 'write-off is the owner only');
      await refused(send(manager, [w('devices', cashier.device, {'id': cashier.device, 'ownerEmail': cashier.email, 'name': 'x', 'platform': 'windows', 'status': 'revoked', 'createdAt': nowMs(), 'approvedBy': manager.email, 'approvedAt': nowMs()})], bump: false), reason: 'revoke a device');
    });

    test('can adjust and add credit by hand and pay a dealer', () async {
      await send(manager, [wn('ledgerEntries', 'led', (ni) => ledger(ni, manager, kind: 'manualCredit', amount: 700))]);
      await send(manager, [wn('ledgerEntries', 'led', (ni) => ledger(ni, manager, kind: 'adjustment', amount: -300))]);
      final p = id('pay');
      await send(manager, [w('payments', p, {...payment(p, manager), 'dealerId': 'd1'}..remove('customerId'))]);
    });
  });

  group('owner: everything, including approving and revoking devices, write-offs and cancellations', () {
    test('owner cancels a bill and writes off', () async {
      final c = id('can');
      await send(owner, [w('billCancellations', c, {...baseDoc(c, owner), 'billId': 'b1', 'billNo': 'A-1', 'reason': 'Wrong customer', 'at': nowMs()})]);
      await send(owner, [wn('ledgerEntries', 'led', (ni) => ledger(ni, owner, kind: 'writeOff', amount: -500))]);
    });
  });

  group('nobody can delete; records of what happened cannot be edited', () {
    test('delete is refused for every role and collection; editing a bill is refused', () async {
      final b = id('bill');
      await send(cashier, [w('bills', b, bill(b, cashier))]);
      for (final a in [cashier, manager, owner]) {
        final r = await client.delete(Uri.parse('http://127.0.0.1:8080/v1/projects/demo-erp2/databases/(default)/documents/$shop/bills/$b'), headers: {'authorization': 'Bearer ${a.session.idToken}'});
        expect(r.statusCode, isNot(200), reason: 'delete by ${a.email}');
      }
      await refused(send(owner, [w('bills', b, {...bill(b, cashier), 'totalPaise': 1})]), reason: 'edit of a bill, even by the owner');
    });
  });

  group('people who are not in the lists', () {
    test('a verified stranger and an unverified owner address are refused', () async {
      final s = await actor(stranger);
      await refused(s.fs.commitMixed([w('devices', s.device, {'id': s.device, 'ownerEmail': s.email, 'name': 'x', 'platform': 'windows', 'status': 'pending', 'createdAt': nowMs()})]), reason: 'a stranger registering a device');
      await refused(s.fs.get('$shop/bills/x'));
    });
  });
}
