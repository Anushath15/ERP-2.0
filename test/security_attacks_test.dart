import 'dart:typed_data';
import 'package:erp2/core/cloud/session_vault_io.dart' show systemDll;
import 'package:erp2/core/link_launcher_io.dart' as io;
import 'package:erp2/core/lan/lan_crypto.dart';
import 'package:erp2/core/lan/lan_transport.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/sync/lan_link.dart';
import 'package:erp2/data/sync/sync_triggers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'data/helpers.dart';
import 'lan_link_test.dart' show FakeWifi;

// What these tests prove, from an attacker's side: on the shop Wi-Fi a recorded counter-link message cannot be played back (not to the same address,
// not to another one), a recorded answer cannot be passed off as a new one; and a shop file brought in from outside cannot keep a hidden trigger
// of its own, nor a changed copy of one of ours.
void main() {
  group('the counter link under attack', () {
    test('a replayed or re-aimed message is refused; a new one goes through', () async {
      final wifi = FakeWifi();
      final key = LanKey.generate();
      final b = memoryShop(device: 'dev-bbbb');
      addTearDown(b.close);
      final lb = LanLink(b, wifi.at('10.0.0.2'), key, name: 'Counter 2');
      await lb.start();
      final net = wifi.at('10.0.0.66'); // the attacker's laptop on the Wi-Fi
      Future<int> send(String path, Uint8List body) async => (await net.post('10.0.0.2', lanPort, path, body)).status;

      final hello = await lanSeal(key, {'path': '/lan/v1/hello'});
      expect(await send('/lan/v1/hello', hello), 200, reason: 'the real counter, first time');
      expect(await send('/lan/v1/hello', hello), 401, reason: 'the same message again: a replay');

      // a "link" message recorded from the real counter and sent from the attacker's address would make this counter send its data there
      final link = await lanSeal(key, {'path': '/lan/v1/link', 'deviceId': 'dev-aaaa', 'name': 'Counter 1', 'port': lanPort});
      expect(await send('/lan/v1/link', link), 200);
      expect(await send('/lan/v1/link', link), 401, reason: 'replayed from another address: refused');
      expect((await lb.peers()).single.host, '10.0.0.66', reason: 'only the first one (here sent by the test itself) was taken');

      // a message sealed for one address is not accepted at another
      final aimed = await lanSeal(key, {'path': '/lan/v1/hello'});
      expect(await send('/lan/v1/push', aimed), 401);
      final noPath = await lanSeal(key, {'deviceId': 'x'});
      expect(await send('/lan/v1/link', noPath), 401, reason: 'a message that does not say where it is for');
    });

    test('a push answered with an old answer fails instead of passing as delivered', () async {
      final key = LanKey.generate();
      final old = await lanSeal(key, {'applied': 3, 're': 'not-this-request'});
      final api = LanPeerApi(_Canned(old), key, '10.0.0.2', lanPort, 'dev-aaaa');
      await expectLater(api.push(const []), throwsA(anything));
    });
  });

  group('the computer itself', () {
    test('the link opener refuses anything that is not a web or WhatsApp link (a path would start a program)', () async {
      final l = io.createLauncher();
      expect(await l.open(r'C:\Windows\System32\calc.exe'), isFalse);
      expect(await l.open('file:///C:/Windows/System32/calc.exe'), isFalse);
      expect(await l.open('ms-settings:'), isFalse);
      expect(await l.open('https://wa.me/91 98"x'), isFalse, reason: 'spaces and quotes are never in a link we make');
    });

    test('Windows DLLs are loaded by their full System32 path', () {
      expect(systemDll('crypt32.dll'), endsWith(r'\System32\crypt32.dll'));
      expect(systemDll('crypt32.dll'), contains(':'));
    });
  });

  group('a shop file from outside', () {
    test('a hidden trigger and a view are removed on opening; a changed sync trigger is made again', () async {
      final d = memoryShop();
      addTearDown(d.close);
      await d.catalog.saveProduct(sampleProduct('Bulb', id: 'p1', stock: 10000, price: 1000), create: true);
      // what a crafted backup could carry: every new bill line quietly empties the customers' ledger
      await d.db.exec('CREATE TRIGGER evil_wipe AFTER INSERT ON bill_lines BEGIN DELETE FROM ledger_entries; END');
      await d.db.exec('CREATE VIEW evil_view AS SELECT * FROM bills');
      // and one of OUR names with other contents
      await d.db.exec('DROP TRIGGER sync_bills_ai');
      await d.db.exec('CREATE TRIGGER sync_bills_ai AFTER INSERT ON bills BEGIN UPDATE bills SET total_paise = 0 WHERE id = new.id; END');

      final removed = await removeForeignSchemaObjects(d.db);
      expect(removed, 2, reason: 'the foreign trigger and the view');
      await ensureSyncTriggers(d.db);
      final names = [for (final r in await d.db.rows("SELECT name FROM sqlite_master WHERE type IN ('trigger','view')")) r.read<String>('name')];
      expect(names, isNot(contains('evil_wipe')));
      expect(names, isNot(contains('evil_view')));
      final sql = (await d.db.row("SELECT sql FROM sqlite_master WHERE name = 'sync_bills_ai'"))!.read<String>('sql');
      expect(sql, expectedSyncTriggers()['sync_bills_ai'], reason: 'our trigger is ours again');
      // and the bill keeps its total
      final s = await d.bills.saveBill(SaveBillInput(idemKey: 'k', at: DateTime(2026, 10, 1), lines: [const BillLineInput(productId: 'p1', name: 'Bulb', unit: 'pcs', qtyMilli: 1000, ratePaise: 1000, gstBp: 1800)]));
      expect(await d.db.scalarInt('SELECT total_paise FROM bills WHERE id = ?', [s.id]), s.totalPaise);
      expect(s.totalPaise, greaterThan(0));
    });

    test('our own triggers are left alone on a normal open', () async {
      final d = memoryShop();
      addTearDown(d.close);
      expect(await removeForeignSchemaObjects(d.db), 0);
    });
  });
}

/// A "network" that always answers 200 with the same recorded body.
class _Canned implements LanTransport {
  _Canned(this.body);
  final Uint8List body;
  @override
  Future<void> serve(int port, LanHandler handler) async {}
  @override
  Future<void> stopServing() async {}
  @override
  Future<List<String>> localAddresses() async => const [];
  @override
  Future<({int status, Uint8List body})> post(String host, int port, String path, Uint8List b) async => (status: 200, body: body);
}
