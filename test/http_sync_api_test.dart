import 'dart:convert';
import 'package:erp2/core/cloud/cloud_config.dart';
import 'package:erp2/core/cloud/http_sync_api.dart';
import 'package:erp2/core/cloud/sync_controller.dart';
import 'package:erp2/data/sync/sync_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'data/fake_cloud.dart';
import 'data/helpers.dart';

// What these tests prove: the program talks to the two cloud functions the way the SQL expects, and every kind of failure comes out as
// the right kind of sync problem (wait and retry / sign in again / this one document is refused).
void main() {
  const cfg = CloudConfig(url: 'http://127.0.0.1:54321', key: 'pk');
  HttpSyncApi api(http.Client c) => HttpSyncApi(cfg, 'dev-1', () async => (token: 'tok', shopId: 'shop-1'), client: c);

  test('push sends shop, device and documents to push_docs with the token; pull reads the rows back', () async {
    late http.Request seen;
    final client = MockClient((r) async {
      seen = r;
      if (r.url.path.endsWith('push_docs')) return http.Response('"2026-10-19T10:00:00Z"', 200);
      return http.Response(jsonEncode([{'seq': 7, 'coll': 'products', 'id': 'p1', 'data': {'name': 'X'}, 'hlc': 'h', 'deleted': false, 'device_id': 'dev-2'}]), 200);
    });
    final a = api(client);
    await a.push([const SyncDoc(coll: 'products', id: 'p1', data: {'name': 'X'}, hlc: 'h')]);
    expect(seen.url.path, '/rest/v1/rpc/push_docs');
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(seen.headers['apikey'], 'pk');
    final body = jsonDecode(seen.body) as Map;
    expect(body['p_shop'], 'shop-1');
    expect(body['p_device'], 'dev-1');
    expect((body['p_docs'] as List).single['coll'], 'products');
    final got = await a.pull(3, 300);
    expect(jsonDecode(seen.body), {'p_shop': 'shop-1', 'p_after': 3, 'p_limit': 300});
    expect((got.single.seq, got.single.id, got.single.deviceId, got.single.data['name']), (7, 'p1', 'dev-2', 'X'));
  });

  test('failures: no internet and server trouble = wait; 401 = sign in again; not a member = sign in again; other refusals = that document', () async {
    Future<Object?> fail(http.Response Function() r) async {
      try {
        await api(MockClient((_) async => r())).push(const []);
      } catch (e) {
        return e;
      }
      return null;
    }

    expect(await fail(() => http.Response('boom', 503)), isA<SyncOffline>());
    expect(await fail(() => http.Response('{"message":"JWT expired"}', 401)), isA<SyncAuthFailed>());
    expect(await fail(() => http.Response('{"code":"42501","message":"not a member of this shop"}', 403)), isA<SyncAuthFailed>());
    expect(await fail(() => http.Response('{"code":"42501","message":"cashiers cannot change products"}', 403)), isA<SyncRejected>());
    expect(await fail(() => http.Response('{"code":"22023","message":"a batch holds at most 100 documents"}', 400)), isA<SyncRejected>());
    final off = HttpSyncApi(cfg, 'd', () async => (token: 't', shopId: 's'), client: MockClient((_) async => throw Exception('socket')));
    await expectLater(off.pull(0, 1), throwsA(isA<SyncOffline>()));
    final out = HttpSyncApi(cfg, 'd', () async => null, client: MockClient((_) async => http.Response('', 200)));
    await expectLater(out.pull(0, 1), throwsA(isA<SyncAuthFailed>()));
  });

  test('the controller runs a round, shows what is waiting, goes offline and recovers', () async {
    final cloud = FakeCloud();
    final shop = memoryShop(device: 'dev-ctl');
    final c = ProviderContainer();
    addTearDown(() async {
      c.dispose();
      await shop.close();
    });
    final ctl = c.read(syncProvider.notifier);
    expect(c.read(syncProvider).active, isFalse);
    ctl.startWith(shop, cloud.client('dev-ctl'), timer: false);
    await shop.catalog.saveProduct(sampleProduct('X', id: 'p1'), create: true);
    await ctl.syncNow();
    expect(c.read(syncProvider).phase, SyncPhase.idle);
    expect(c.read(syncProvider).pending, 0);
    expect(c.read(syncProvider).last, isNotNull);
    cloud.offline = true;
    await shop.catalog.saveProduct(sampleProduct('Y', id: 'p2'), create: true);
    await ctl.syncNow();
    expect(c.read(syncProvider).phase, SyncPhase.offline);
    expect(c.read(syncProvider).pending, greaterThan(0));
    cloud.offline = false;
    await ctl.syncNow();
    expect(c.read(syncProvider).phase, SyncPhase.idle);
    expect(cloud.docs.containsKey('products/p2'), isTrue);
    ctl.stop();
  });
}
