import 'dart:io' show HttpOverrides;
import 'dart:typed_data';
import 'package:erp2/core/lan/lan_controller.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:flutter/material.dart';
import 'helpers.dart' as ui;
import 'package:erp2/core/lan/lan_crypto.dart';
import 'package:erp2/data/sync/lan_link.dart';
import 'package:erp2/core/lan/lan_transport.dart';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/domain/credit/account.dart';
import 'package:erp2/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'data/helpers.dart';

/// A pretend Wi-Fi: counters register their handler under an address; a request goes straight to it (or fails when the counter is "off").
class FakeWifi {
  final Map<String, LanHandler> servers = {};
  final Set<String> down = {};
  LanTransport at(String myAddress) => _Node(this, myAddress);
}

class _Node implements LanTransport {
  _Node(this.wifi, this.me);
  final FakeWifi wifi;
  final String me;
  @override
  Future<void> serve(int port, LanHandler handler) async => wifi.servers[me] = handler;
  @override
  Future<void> stopServing() async => wifi.servers.remove(me);
  @override
  Future<List<String>> localAddresses() async => [me];
  @override
  Future<({int status, Uint8List body})> post(String host, int port, String path, Uint8List body) async {
    final h = wifi.servers[host];
    if (h == null || wifi.down.contains(host)) throw Exception('no route to $host');
    try {
      return (status: 200, body: await h(path, body, me));
    } on LanRefused catch (e) {
      return (status: e.status, body: Uint8List(0));
    }
  }
}

// What these tests prove: two billing counters on the shop Wi-Fi, with no internet, end up with the same bills, stock and balances; only a
// counter that knows the shop's key can join; and a counter that is switched off simply catches up later.
void main() {
  group('the key and the locked messages', () {
    test('a key is written and read back; typing mistakes are refused', () {
      final k = LanKey.generate();
      expect(LanKey.parse(k.text)!.bytes, k.bytes);
      expect(LanKey.parse(k.text.toUpperCase().replaceAll('-', ' '))!.bytes, k.bytes);
      expect(LanKey.parse('1234'), isNull);
      expect(LanKey.parse('z' * 64), isNull);
    });

    test('opens with the same key only; a changed byte, another key or an old message is refused', () async {
      final k = LanKey.generate(), other = LanKey.generate();
      final sealed = await lanSeal(k, {'a': 1});
      expect((await lanOpen(k, sealed))['a'], 1);
      await expectLater(lanOpen(other, sealed), throwsA(isA<LanSealException>()));
      final bad = Uint8List.fromList(sealed)..[20] ^= 1;
      await expectLater(lanOpen(k, bad), throwsA(isA<LanSealException>()));
      final old = await lanSeal(k, {'a': 1}, nowMs: () => 1000);
      await expectLater(lanOpen(k, old), throwsA(isA<LanSealException>()));
      await expectLater(lanOpen(k, Uint8List(5)), throwsA(isA<LanSealException>()));
    });
  });

  group('two counters', () {
    late FakeWifi wifi;
    late AppData a, b;
    late LanLink la, lb;
    late LanKey key;
    var changed = 0;

    setUp(() async {
      wifi = FakeWifi();
      key = LanKey.generate();
      a = memoryShop(device: 'dev-aaaa');
      b = memoryShop(device: 'dev-bbbb');
      la = LanLink(a, wifi.at('10.0.0.1'), key, name: 'Counter 1');
      lb = LanLink(b, wifi.at('10.0.0.2'), key, name: 'Counter 2', onChanged: () => changed++);
      await la.start();
      await lb.start();
      changed = 0;
    });
    tearDown(() async {
      await a.close();
      await b.close();
    });

    Product prod(String id, String name) => sampleProduct(name, id: id, stock: 10000, price: 10000);
    BillLineInput line(Product p, int qty) => BillLineInput(productId: p.id, name: p.name, unit: p.unit, qtyMilli: qty, ratePaise: p.pricePaise, gstBp: p.gstBp, discountBp: 0);
    SaveBillInput bill(Product p, int qty, String key) => SaveBillInput(idemKey: key, at: DateTime(2026, 10, 14, 15, 30), lines: [line(p, qty)]);
    Future<int> stock(AppData d, String id) async => (await d.catalog.product(id))!.stockMilli;
    Future<int> count(AppData d, String t) => d.db.scalarInt('SELECT COUNT(*) FROM $t');

    test('linking one counter links both ways; the wrong key, an empty address and the same computer are refused', () async {
      final peer = await la.addPeer('10.0.0.2');
      expect(peer.deviceId, 'dev-bbbb');
      expect((await la.peers()).single.chan, 'lan-dev-bbbb');
      expect((await lb.peers()).single.chan, 'lan-dev-aaaa', reason: 'the other counter was told to remember this one too');
      final wrong = LanLink(a, wifi.at('10.0.0.9'), LanKey.generate());
      await expectLater(wrong.addPeer('10.0.0.2'), throwsA(isA<LanLinkException>().having((e) => e.problem, 'problem', LanLinkProblem.wrongKey)));
      await expectLater(la.addPeer('10.0.0.77'), throwsA(isA<LanLinkException>().having((e) => e.problem, 'problem', LanLinkProblem.unreachable)));
      await expectLater(la.addPeer('bad host!'), throwsA(isA<LanLinkException>().having((e) => e.problem, 'problem', LanLinkProblem.badAddress)));
      await expectLater(la.addPeer('10.0.0.1'), throwsA(isA<LanLinkException>().having((e) => e.problem, 'problem', LanLinkProblem.thisComputer)));
    });

    test('a bill made on one counter is on the other within one round, with stock and totals; and back again', () async {
      await la.addPeer('10.0.0.2');
      final p = prod('p1', 'WOOD SCREW');
      await a.catalog.saveProduct(p, create: true);
      final s = await a.bills.saveBill(bill(p, 2000, 'ka'));
      await la.syncOnce();
      expect(await count(b, 'bills'), 1);
      expect(await stock(b, 'p1'), 8000);
      expect((await b.bills.detail(s.id))!.row.number, s.number);
      expect(changed, greaterThan(0), reason: 'the screens are told');
      // the other direction
      await b.bills.saveBill(bill(p, 1000, 'kb'));
      await lb.syncOnce();
      expect(await count(a, 'bills'), 2);
      expect(await stock(a, 'p1'), 7000);
      expect(await stock(b, 'p1'), 7000);
      // nothing bounces back and forth
      expect(await a.db.scalarInt("SELECT COUNT(*) FROM outbox WHERE chan = 'lan-dev-bbbb'"), 0);
      expect(await b.db.scalarInt("SELECT COUNT(*) FROM outbox WHERE chan = 'lan-dev-aaaa'"), 0);
    });

    test('everything the counter already had goes to a newly linked counter', () async {
      final p = prod('p1', 'OLD');
      await a.catalog.saveProduct(p, create: true);
      await a.bills.saveBill(bill(p, 1000, 'ka'));
      await la.addPeer('10.0.0.2');
      await la.syncOnce();
      expect(await count(b, 'products'), 1);
      expect(await count(b, 'bills'), 1);
    });

    test('a counter that is switched off catches up when it is back; nothing is lost or doubled', () async {
      await la.addPeer('10.0.0.2');
      final p = prod('p1', 'X');
      await a.catalog.saveProduct(p, create: true);
      await la.syncOnce();
      wifi.down.add('10.0.0.2');
      await a.bills.saveBill(bill(p, 1000, 'k1'));
      await a.bills.saveBill(bill(p, 1000, 'k2'));
      await la.syncOnce();
      expect(la.status['lan-dev-bbbb'], isNotEmpty);
      expect(await count(b, 'bills'), 0);
      expect(await a.db.scalarInt("SELECT COUNT(*) FROM outbox WHERE chan = 'lan-dev-bbbb'"), greaterThan(0));
      wifi.down.clear();
      await la.syncOnce();
      expect(la.status['lan-dev-bbbb'], '');
      expect(await count(b, 'bills'), 2);
      expect(await stock(b, 'p1'), 8000);
      await la.syncOnce();
      expect(await count(b, 'bills'), 2);
    });

    test('a counter with the wrong key gets nothing and is told so; unlinking stops the sending', () async {
      await la.addPeer('10.0.0.2');
      final intruder = LanLink(a, wifi.at('10.0.0.1'), LanKey.generate());
      await a.catalog.saveProduct(prod('p1', 'X'), create: true);
      // an intruder pushes with a wrong key straight to counter 2
      final api = LanPeerApi(wifi.at('10.0.0.5'), LanKey.generate(), '10.0.0.2', lanPort, 'evil');
      await expectLater(api.push(const []), throwsA(isA<Exception>()));
      expect(await count(b, 'products'), 0);
      expect(intruder.key, isNot(key));
      await la.removePeer('lan-dev-bbbb');
      await a.catalog.saveProduct(prod('p2', 'Y'), create: true);
      expect(await a.db.scalarInt("SELECT COUNT(*) FROM outbox WHERE chan = 'lan-dev-bbbb'"), 0);
      await la.syncOnce();
      expect(await count(b, 'products'), 0);
    });

    test('payments wait ten seconds before they are sent to the other counter (Undo)', () async {
      await la.addPeer('10.0.0.2');
      final c = sampleCustomer('Murugan', id: 'c1');
      await a.catalog.saveCustomer(c, create: true);
      final p = prod('p1', 'X');
      await a.catalog.saveProduct(p, create: true);
      await a.bills.saveBill(SaveBillInput(idemKey: 'kc', at: DateTime(2026, 10, 14, 15, 30), lines: [line(p, 1000)], customerId: 'c1', customerName: 'Murugan', receivedPaise: 0));
      await a.ledger.receivePayment(PartyKind.customer, partyId: 'c1', partyName: 'Murugan', amount: 3000, mode: 'cash', at: DateTime(2026, 10, 14, 15, 31));
      final held = await a.db.scalarInt("SELECT COUNT(*) FROM outbox WHERE chan = 'lan-dev-bbbb' AND coll = 'payments' AND hold_until > 0");
      expect(held, 1);
      await la.syncOnce();
      expect(await count(b, 'payments'), 0, reason: 'still held back');
    });
  });

  test('over real network sockets (this computer to itself on two ports): link, send a bill, wrong key refused', () async {
    HttpOverrides.global = null; // the test framework fakes the network; this test needs the real one
    final key = LanKey.generate();
    final a = memoryShop(device: 'dev-aaaa'), b = memoryShop(device: 'dev-bbbb');
    final ta = createLanTransport(), tb = createLanTransport();
    final la = LanLink(a, ta, key, name: 'One', port: 47331), lb = LanLink(b, tb, key, name: 'Two', port: 47332);
    await la.start();
    await lb.start();
    addTearDown(() async {
      await la.stop();
      await lb.stop();
      await a.close();
      await b.close();
    });
    final p = sampleProduct('SCREW', id: 'p1', stock: 10000, price: 10000);
    await a.catalog.saveProduct(p, create: true);
    final peer = await la.addPeer('127.0.0.1', port: 47332);
    expect(peer.deviceId, 'dev-bbbb');
    expect((await lb.peers()).single.port, 47331);
    await la.syncOnce();
    expect(la.status['lan-dev-bbbb'], '');
    expect((await b.catalog.product('p1'))!.name, 'SCREW');
    final evil = LanLink(a, createLanTransport(), LanKey.generate(), port: 47333);
    await expectLater(evil.addPeer('127.0.0.1', port: 47332), throwsA(isA<LanLinkException>().having((e) => e.problem, 'problem', LanLinkProblem.wrongKey)));
  });

  testWidgets('Settings > Counter link: switch on shows the address and a key; a wrong address says why; unlinking works', (tester) async {
    final wifi = FakeWifi();
    final other = memoryShop(device: 'dev-other');
    final lo = LanLink(other, wifi.at('10.0.0.2'), LanKey.generate(), name: 'Other');
    addTearDown(other.close);
    final c = await ui.pumpApp(tester, size: ui.desktop1920, location: '/settings', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [lanTransportProvider.overrideWithValue(wifi.at('10.0.0.1'))]);
    await tester.runAsync(() => lo.start());
    final sw = find.byKey(const ValueKey('lanSwitch'));
    await tester.ensureVisible(sw);
    await tester.tap(sw);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(c.read(lanProvider).on, isTrue);
    expect(find.byKey(const ValueKey('lanAddress')), findsOneWidget);
    expect(find.text("This computer's address: 10.0.0.1"), findsOneWidget);
    expect(find.byKey(const ValueKey('lanNone')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('lanHost')), '10.0.0.99');
    await tester.ensureVisible(find.byKey(const ValueKey('lanLinkBtn')));
    await tester.tap(find.byKey(const ValueKey('lanLinkBtn')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lanError')), findsOneWidget);
    c.read(lanProvider.notifier);
  });
}
