// Every collection checks the shape of what it receives: exact types, integer paise, ranges, lengths, no unknown fields,
// the id matches the path, the creator is the signed-in person, plausible dates (production rules, emulator).
import 'package:test/test.dart';
import 'rules_support.dart';

void main() {
  late Actor owner, manager, cashier;

  setUpAll(() async {
    await loadRules();
    owner = await actor(ownerEmail);
    manager = await actor(manager1);
    cashier = await actor(cashier1);
    final created = nowMs();
    await owner.fs.commitMixed([w('devices', owner.device, {'id': owner.device, 'ownerEmail': owner.email, 'name': 'Owner PC', 'platform': 'windows', 'status': 'pending', 'createdAt': created})]);
    await owner.fs.commitMixed([w('devices', owner.device, {'id': owner.device, 'ownerEmail': owner.email, 'name': 'Owner PC', 'platform': 'windows', 'status': 'approved', 'createdAt': created, 'approvedBy': owner.email, 'approvedAt': nowMs()})]);
    await approvedDevice(manager, owner);
    await approvedDevice(cashier, owner);
  });
  tearDownAll(restoreRules);

  /// Sends a product with one thing changed; it must be refused.
  Future<void> badProduct(Map<String, Object?> change, {List<String> remove = const [], String? reason}) async {
    final p = id('prod');
    final d = {...product(p, manager), ...change};
    for (final k in remove) {
      d.remove(k);
    }
    await refused(send(manager, [w('products', p, d)]), reason: reason ?? '$change');
  }

  group('products', () {
    test('a good product is accepted (control)', () async {
      final p = id('prod');
      await send(manager, [w('products', p, product(p, manager))]);
    });
    test('negative, string, fractional, absurd prices are refused', () async {
      await badProduct({'pricePaise': -999999}, reason: '-999999 price');
      await badProduct({'pricePaise': '150'}, reason: 'string price');
      await badProduct({'pricePaise': 150.5}, reason: 'fractional price');
      await badProduct({'pricePaise': 99999999999}, reason: 'absurd price');
      await badProduct({'costPaise': -1}, reason: 'negative cost');
      await badProduct({'costPaise': 'free'}, reason: 'string cost');
    });
    test('long names, wrong types and unknown fields are refused', () async {
      await badProduct({'name': 'x' * 10000}, reason: '10,000 character name');
      await badProduct({'name': ''}, reason: 'empty name');
      await badProduct({'name': 5}, reason: 'name that is a number');
      await badProduct({'isAdmin': true}, reason: 'unknown field');
      await badProduct({'gstBp': 99999}, reason: 'tax 999%');
      await badProduct({'active': 'yes'}, reason: 'active as text');
      await badProduct({'minQtyMilli': -5}, reason: 'negative minimum');
    });
    test('a missing required field is refused', () async {
      await badProduct({}, remove: ['pricePaise'], reason: 'no price');
      await badProduct({}, remove: ['updatedBy'], reason: 'no editor');
    });
    test('forged creator, wrong id and unrealistic dates are refused', () async {
      await badProduct({'createdBy': 'someone.else@example.com'}, reason: 'forged creator');
      await badProduct({'updatedBy': 'someone.else@example.com'}, reason: 'forged editor');
      await badProduct({'id': 'not-the-path-id'}, reason: 'id differs from the path');
      await badProduct({'updatedAt': 1}, reason: 'date in 1970');
      await badProduct({'updatedAt': nowMs() + 1000 * 60 * 60 * 24 * 365}, reason: 'date a year ahead');
      await badProduct({'version': 7}, reason: 'new product with version 7');
    });
  });

  group('bills', () {
    Future<void> badBill(Map<String, Object?> change, String why, {List<String> remove = const []}) async {
      final b = id('bill');
      final d = {...bill(b, cashier, customerId: 'c1'), ...change};
      for (final k in remove) {
        d.remove(k);
      }
      await refused(send(cashier, [w('bills', b, d)]), reason: why);
    }

    test('a good bill is accepted (control)', () async {
      final b = id('bill');
      await send(cashier, [w('bills', b, bill(b, cashier, customerId: 'c1'))]);
    });
    test('negative, string and fractional money, a balance above the total, a bad payment mode are refused', () async {
      await badBill({'totalPaise': -100}, 'negative total');
      await badBill({'totalPaise': '15000'}, 'string total');
      await badBill({'totalPaise': 150.75}, 'fractional total');
      await badBill({'receivedPaise': -1}, 'negative received');
      await badBill({'balancePaise': 99999999}, 'balance above total');
      await badBill({'payMode': 9}, 'unknown payment mode');
      await badBill({'status': 3}, 'bill created already cancelled');
    });
    test('oversized lists and notes, unknown fields, forged creator, wrong id are refused', () async {
      await badBill({'lines': List.generate(301, (i) => {'n': i})}, '301 lines');
      await badBill({'note': 'n' * 501}, 'long note');
      await badBill({'discountEverything': 100}, 'unknown field');
      await badBill({'createdBy': 'boss@example.com'}, 'forged creator');
      await badBill({'id': 'other-record-id'}, 'id differs from path');
      await badBill({}, 'no idempotency key', remove: ['idemKey']);
    });
    test('a bill cannot use a device that belongs to somebody else', () async {
      await badBill({'deviceId': owner.device}, 'borrowed device');
      await badBill({'deviceId': 'never-registered-device'}, 'unknown device');
    });
  });

  group('payments, ledger, stock, notes', () {
    test('payment amounts must be whole positive paise and the party exactly one of customer or dealer', () async {
      for (final c in <Map<String, Object?>>[
        {'amountPaise': 0},
        {'amountPaise': -500},
        {'amountPaise': '500'},
        {'amountPaise': 5.5},
        {'mode': 'cheque-of-gold'},
        {'advancePaise': 99999},
        {'note': 'n' * 501},
      ]) {
        final p = id('pay');
        await refused(send(cashier, [w('payments', p, {...payment(p, cashier), ...c})]), reason: '$c');
      }
      final p = id('pay');
      await refused(send(cashier, [w('payments', p, {...payment(p, cashier), 'dealerId': 'd1'})]), reason: 'customer and dealer together');
    });
    test('ledger entries: zero amount, wrong sign, unknown kind, long note', () async {
      for (final c in <Map<String, Object?>>[
        {'amountPaise': 0},
        {'amountPaise': '5'},
        {'kind': 'billCredit', 'amountPaise': -5},
        {'kind': 'payment', 'amountPaise': 500},
        {'kind': 'freeMoney'},
        {'note': 'n' * 501},
      ]) {
        final l = id('led');
        await refused(send(cashier, [w('ledgerEntries', l, {...ledger(l, cashier), ...c})]), reason: '$c');
      }
    });
    test('stock movements: zero, fractional, absurd quantity, unknown kind', () async {
      for (final c in <Map<String, Object?>>[
        {'qtyMilli': 0},
        {'qtyMilli': -1.5},
        {'qtyMilli': -99999999999},
        {'qtyMilli': '-1000'},
        {'kind': 'gift'},
      ]) {
        final m = id('mov');
        await refused(send(cashier, [w('stockMovements', m, {...movement(m, cashier), ...c})]), reason: '$c');
      }
    });
    test('customer notes and reminders: empty, oversized, forged', () async {
      for (final c in <Map<String, Object?>>[
        {'note': ''},
        {'note': 'n' * 501},
        {'note': 7},
        {'extra': 1},
      ]) {
        final n = id('note');
        await refused(send(cashier, [w('customerNotes', n, {...baseDoc(n, cashier), 'customerId': 'c1', 'note': 'ok', 'at': nowMs(), ...c})]), reason: '$c');
      }
      final r = id('rem');
      await refused(send(cashier, [w('reminders', r, {...baseDoc(r, cashier), 'customerId': 'c1', 'at': nowMs(), 'amountDuePaise': 5000, 'message': 'm' * 1501, 'by': cashier.email})]), reason: 'long reminder');
      final r2 = id('rem');
      await refused(send(cashier, [w('reminders', r2, {...baseDoc(r2, cashier), 'customerId': 'c1', 'at': nowMs(), 'amountDuePaise': 5000, 'message': 'hi', 'by': 'boss@example.com'})]), reason: 'reminder in another name');
    });
    test('customers: oversized name or phone, negative limit, string limit', () async {
      for (final c in <Map<String, Object?>>[
        {'name': 'x' * 81},
        {'phone': '9' * 21},
        {'creditLimitPaise': -1},
        {'creditLimitPaise': '0'},
        {'isVip': true},
      ]) {
        final cu = id('cust');
        await refused(send(manager, [w('customers', cu, {...customer(cu, manager, limit: 0), ...c})]), reason: '$c');
      }
    });
  });

  group('nothing can be written outside the known collections', () {
    test('an unknown collection and the shop document itself are refused', () async {
      await refused(send(owner, [w('secrets', 'x1234567', {'a': 1})]), reason: 'unknown collection');
      await refused(owner.fs.commitMixed([(path: 'shops/s1', data: {'name': 'x'}, stamp: false)]), reason: 'the shop document');
    });
  });
}
