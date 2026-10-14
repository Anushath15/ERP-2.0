// A price, cost or credit-limit change must come with its audit record (who, when, old, new) in the same batch,
// and the audit records themselves can never be edited or deleted (production rules, emulator).
import 'package:test/test.dart';
import 'rules_support.dart';

void main() {
  late Actor owner, manager, cashier;
  late String prodId, custId;

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
    prodId = id('prod');
    await send(manager, [w('products', prodId, product(prodId, manager, price: 15000, cost: 9000))]);
    custId = id('cust');
    await send(manager, [w('customers', custId, customer(custId, manager, limit: 100000))]);
  });
  tearDownAll(restoreRules);

  Map<String, Object?> priceEdit(int price, {int version = 2, String? auditId, int? cost}) => {
        ...product(prodId, manager, price: price, cost: cost ?? 9000),
        'version': version,
        if (auditId != null) 'auditIdPrice': auditId,
      };

  test('a price change without an audit record is refused', () async {
    await refused(send(manager, [w('products', prodId, priceEdit(20000))]), reason: 'price change with no audit');
    await refused(send(manager, [w('products', prodId, priceEdit(20000, auditId: 'does-not-exist'))]), reason: 'audit id that points nowhere');
  });

  test('an audit record that says something different is refused', () async {
    final a = id('aud');
    await refused(send(manager, [
      w('products', prodId, priceEdit(20000, auditId: a)),
      w('audit', a, audit(a, manager, action: 'price', entity: 'product', entityId: prodId, field: 'price', oldValue: 15000, newValue: 99)),
    ]), reason: 'new value does not match');
    final b = id('aud');
    await refused(send(manager, [
      w('products', prodId, priceEdit(20000, auditId: b)),
      w('audit', b, audit(b, manager, action: 'price', entity: 'product', entityId: prodId, field: 'price', oldValue: 14000, newValue: 20000)),
    ]), reason: 'old value does not match');
    final c = id('aud');
    await refused(send(manager, [
      w('products', prodId, priceEdit(20000, auditId: c)),
      w('audit', c, {...audit(c, manager, action: 'price', entity: 'product', entityId: prodId, field: 'price', oldValue: 15000, newValue: 20000), 'by': 'boss@example.com'}),
    ]), reason: 'audit in somebody else\'s name');
  });

  test('a price change WITH a matching audit record is accepted, and the audit can be read by a manager but not a cashier', () async {
    final a = id('aud');
    await send(manager, [
      w('products', prodId, priceEdit(20000, auditId: a)),
      w('audit', a, audit(a, manager, action: 'price', entity: 'product', entityId: prodId, field: 'price', oldValue: 15000, newValue: 20000)),
    ]);
    expect(await manager.fs.get('$shop/audit/$a'), isNotNull);
    await refused(cashier.fs.get('$shop/audit/$a'), reason: 'a cashier reading the audit');
  });

  test('a change of something else (name) needs no audit; a cost change does', () async {
    final d = await manager.fs.get('$shop/products/$prodId');
    final next = (d!['version'] as int) + 1;
    await send(manager, [w('products', prodId, {...product(prodId, manager, price: 20000), 'version': next, 'name': 'Hacksaw blade 12 inch'})]);
    await refused(send(manager, [w('products', prodId, {...product(prodId, manager, price: 20000, cost: 1), 'version': next + 1, 'name': 'Hacksaw blade 12 inch'})]), reason: 'cost change with no audit');
    final a = id('aud');
    await send(manager, [
      w('products', prodId, {...product(prodId, manager, price: 20000, cost: 1), 'version': next + 1, 'name': 'Hacksaw blade 12 inch', 'auditIdCost': a}),
      w('audit', a, audit(a, manager, action: 'cost', entity: 'product', entityId: prodId, field: 'cost', oldValue: 9000, newValue: 1)),
    ]);
  });

  test('a credit-limit change needs its audit record; a cashier cannot do it at all', () async {
    Map<String, Object?> limitEdit(int limit, {String? auditId}) => {...customer(custId, manager, limit: limit), 'version': 2, if (auditId != null) 'auditIdLimit': auditId};
    await refused(send(manager, [w('customers', custId, limitEdit(9000000))]), reason: 'limit change with no audit');
    final a = id('aud');
    await refused(send(cashier, [
      w('customers', custId, {...limitEdit(9000000, auditId: a), 'createdBy': manager.email, 'updatedBy': cashier.email}),
      w('audit', a, audit(a, cashier, action: 'creditLimit', entity: 'customer', entityId: custId, field: 'creditLimit', oldValue: 100000, newValue: 9000000)),
    ]), reason: 'cashier raising a limit even with an audit');
    final b = id('aud');
    await send(manager, [
      w('customers', custId, limitEdit(9000000, auditId: b)),
      w('audit', b, audit(b, manager, action: 'creditLimit', entity: 'customer', entityId: custId, field: 'creditLimit', oldValue: 100000, newValue: 9000000)),
    ]);
  });

  test('audit records cannot be edited or deleted, by anybody', () async {
    final a = id('aud');
    await send(owner, [w('audit', a, audit(a, owner, action: 'adjustment', entity: 'product', entityId: prodId, field: 'stock', oldValue: 5, newValue: 6))]);
    await refused(send(owner, [w('audit', a, {...audit(a, owner, action: 'adjustment', entity: 'product', entityId: prodId, field: 'stock', oldValue: 5, newValue: 600)})]), reason: 'rewriting history');
    final r = await client.delete(Uri.parse('http://127.0.0.1:8080/v1/projects/demo-erp2/databases/(default)/documents/$shop/audit/$a'), headers: {'authorization': 'Bearer ${owner.session.idToken}'});
    expect(r.statusCode, isNot(200));
  });
}
