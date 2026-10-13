// Spike S4: sync chaos against the Firebase emulator.
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:s1_rest_sync/engine.dart';
import 'package:s1_rest_sync/rest.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

const _u = Uuid();
final client = http.Client();
const colls = ['bills', 'products', 'stockMovements'];

/// Wraps a real remote with random failures:
///  - dropBefore: request never arrives (network down)
///  - dropAfter : request IS applied by the server but the reply is lost (=> duplicate delivery on retry)
///  - kill      : process dies after server applied (engine must be rebuilt from disk)
class ChaosRemote implements Remote {
  ChaosRemote(this.inner, this.rnd,
      {this.dropBefore = 0.15, this.dropAfter = 0.15, this.kill = 0.05});
  final Remote inner;
  final Random rnd;
  double dropBefore, dropAfter, kill;
  bool down = false;
  int calls = 0, lostReplies = 0, droppedBefore = 0;

  @override
  Future<DateTime> commit(List<({String coll, String id, Map<String, Object?> data})> docs) async {
    calls++;
    if (down || rnd.nextDouble() < dropBefore) {
      droppedBefore++;
      throw FbException(0, 'NETWORK', 'offline');
    }
    final t = await inner.commit(docs);
    final x = rnd.nextDouble();
    if (x < kill) throw SimulatedKill();
    if (x < kill + dropAfter) {
      lostReplies++;
      throw FbException(0, 'NETWORK', 'reply lost');
    }
    return t;
  }

  @override
  Future<List<Map<String, Object?>>> pull(String coll, ({String ts, String id})? c, int limit) async {
    if (down || rnd.nextDouble() < dropBefore) throw FbException(0, 'NETWORK', 'offline');
    return inner.pull(coll, c, limit);
  }
}

String tmpDb(String n) => '${Directory.systemTemp.path}\\s4_${n}_${DateTime.now().microsecondsSinceEpoch}.sqlite';

Future<(RestRemote, String)> freshShop(String tag) async {
  final a = AuthRest(client);
  final email = '$tag${DateTime.now().microsecondsSinceEpoch}@example.com';
  final s = await a.signUp(email, 'secret-pass-1');
  await a.verifyEmailViaEmulator(s);
  await a.refresh(s);
  final shop = 'shop-$tag-${DateTime.now().microsecondsSinceEpoch}';
  const base = 'projects/$projectId/databases/(default)/documents';
  final r = await client.post(Uri.parse('$fsBase/v1/$base:commit'),
      headers: {'content-type': 'application/json', 'authorization': 'Bearer ${s.idToken}'},
      body: '{"writes":[{"update":{"name":"$base/shops/$shop","fields":{"ownerEmail":{"stringValue":"$email"}}}},'
          '{"update":{"name":"$base/shops/$shop/members/$email","fields":{"role":{"stringValue":"owner"}}}}]}');
  expect(r.statusCode, 200, reason: r.body);
  return (RestRemote(FirestoreRest(client, s), shop), shop);
}

/// Run push until drained, rebuilding the engine on simulated kills.
Future<Engine> drain(Engine e, String path, String dev, ChaosRemote chaos, {int maxRounds = 400}) async {
  var engine = e;
  for (var i = 0; i < maxRounds; i++) {
    if (engine.pendingCount == 0) return engine;
    try {
      await engine.pushAll(chaos);
    } on SimulatedKill {
      engine.close();
      engine = Engine(path, dev, batchSize: 50); // "restart the app": all state comes from the file
    }
  }
  fail('did not drain: ${engine.pendingCount} left');
}

void main() {
  test('S4-1: 3,000 edits with chaos, kills and lost replies: nothing lost, nothing doubled', () async {
    final (remote, _) = await freshShop('chaos1');
    final rnd = Random(1);
    final chaos = ChaosRemote(remote, rnd);
    final path = tmpDb('A');
    var a = Engine(path, 'A', batchSize: 50);
    final productIds = [for (var i = 0; i < 100; i++) _u.v7()];
    var n = 0;
    for (var i = 0; i < 1200; i++) {
      a.save('bills', _u.v7(), {'number': 'A-${++n}', 'total': i * 100});
      for (var l = 0; l < 1; l++) {
        a.save('stockMovements', _u.v7(), {'productId': productIds[i % 100], 'qtyMilli': -1000});
      }
      // product edited repeatedly: must coalesce into ONE pending upload
      a.save('products', productIds[i % 100], {'name': 'item ${i % 100}', 'price': i});
    }
    final outboxBefore = a.pendingCount;
    expect(outboxBefore, 1200 + 1200 + 100, reason: 'edits of the same product coalesce');
    a = await drain(a, path, 'A', chaos);
    print('S4-1 calls=${chaos.calls} lostReplies=${chaos.lostReplies} droppedBefore=${chaos.droppedBefore} '
        'server writes=${remote.fs.writes} (unique records=$outboxBefore)');

    // a brand-new device restores everything
    final pathB = tmpDb('B');
    final b = Engine(pathB, 'B');
    final clean = ChaosRemote(remote, rnd, dropBefore: 0.1, dropAfter: 0, kill: 0);
    var tries = 0;
    while (true) {
      try {
        await b.pull(clean, colls);
        break;
      } on FbException {
        if (++tries > 50) fail('pull never completed');
      }
    }
    for (final c in colls) {
      expect(b.snapshot(c), a.snapshot(c), reason: 'collection $c equal on both devices');
    }
    expect(b.snapshot('bills').length, 1200);
    final numbers = b.db.select("SELECT json_extract(json,'\$.number') n FROM records WHERE coll='bills'").map((r) => r['n']).toList();
    expect(numbers.toSet().length, numbers.length, reason: 'no invoice number twice');
    print('S4-1 restore reads=${remote.fs.reads}');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('S4-2: one poisoned record does not block the other 499', () async {
    final (remote, _) = await freshShop('poison');
    final chaos = ChaosRemote(remote, Random(2), dropBefore: 0, dropAfter: 0, kill: 0);
    final path = tmpDb('P');
    final a = Engine(path, 'A');
    final bad = _u.v7();
    for (var i = 0; i < 500; i++) {
      if (i == 250) {
        a.save('products', bad, {for (var k = 0; k < 70; k++) 'f$k': k}); // too many fields -> rejected by rules
      } else {
        a.save('products', _u.v7(), {'name': 'ok $i'});
      }
    }
    var st = await a.pushAll(chaos);
    for (var r = 0; r < 10 && a.pendingCount > 0; r++) {
      final s2 = await a.pushAll(chaos);
      st.poisoned += s2.poisoned;
      st.batches += s2.batches;
    }
    expect(st.poisoned, 1);
    expect(a.pendingCount, 0);
    expect(a.attentionCount, 1);
    expect(remote.fs.writes, 499);
    print('S4-2 batches tried=${st.batches} committed=${st.committed} poisoned=${st.poisoned}');
  });

  test('S4-3: offline for days, 5,000 changes, then reconnect', () async {
    final (remote, _) = await freshShop('offline');
    final chaos = ChaosRemote(remote, Random(3), dropBefore: 0, dropAfter: 0, kill: 0)..down = true;
    final path = tmpDb('O');
    final a = Engine(path, 'A');
    for (var i = 0; i < 5000; i++) {
      a.save('bills', _u.v7(), {'number': 'A-$i', 'total': i});
    }
    final st1 = await a.pushAll(chaos);
    expect(st1.networkFailures, 1);
    expect(st1.backoff, isNotNull);
    expect(a.pendingCount, 5000);
    chaos.down = false;
    final sw = Stopwatch()..start();
    await a.pushAll(chaos);
    expect(a.pendingCount, 0);
    print('S4-3 5,000 bills uploaded in ${sw.elapsedMilliseconds} ms, server writes=${remote.fs.writes}');
    expect(remote.fs.writes, 5000);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('S4-4: two devices edit the same product; last writer (hybrid clock) wins, loser kept in history', () async {
    final (remote, _) = await freshShop('lww');
    final clean = ChaosRemote(remote, Random(4), dropBefore: 0, dropAfter: 0, kill: 0);
    final a = Engine(tmpDb('LA'), 'A');
    final b = Engine(tmpDb('LB'), 'B');
    final id = _u.v7();
    a.save('products', id, {'name': 'Wire', 'price': 100});
    await a.pushAll(clean);
    await b.pull(clean, colls);
    // both go "offline" and edit; B's PC clock is two days AHEAD (wrong clock)
    b.hlc.clock = () => DateTime.now().millisecondsSinceEpoch + 2 * 86400000;
    a.save('products', id, {'name': 'Wire 1.5', 'price': 110});
    b.save('products', id, {'name': 'Wire 1.5 sq', 'price': 120});
    await a.pushAll(clean);
    await b.pushAll(clean);
    await a.pull(clean, colls);
    await b.pull(clean, colls);
    expect(a.snapshot('products'), b.snapshot('products'), reason: 'devices converge');
    expect(b.db.select('SELECT COUNT(*) c FROM history').first['c'] + a.db.select('SELECT COUNT(*) c FROM history').first['c'], greaterThan(0), reason: 'losing version kept');
    print('S4-4 winner=${a.snapshot('products')[id]}');
    // clock-skew warning: B's skew is seen from server commit time
    expect(b.clockSkewWarning, true);
    expect(a.clockSkewWarning, false);
  });

  test('S4-5: two devices bill at once, no collisions, both see all', () async {
    final (remote, _) = await freshShop('two');
    final clean = ChaosRemote(remote, Random(5), dropBefore: 0.1, dropAfter: 0.1, kill: 0);
    final pa = tmpDb('TA'), pb = tmpDb('TB');
    var a = Engine(pa, 'A');
    var b = Engine(pb, 'B');
    for (var i = 1; i <= 300; i++) {
      a.save('bills', _u.v7(), {'number': 'A-$i', 'total': i});
      b.save('bills', _u.v7(), {'number': 'B-$i', 'total': i});
    }
    a = await drain(a, pa, 'A', clean);
    b = await drain(b, pb, 'B', clean);
    final ok = ChaosRemote(remote, Random(6), dropBefore: 0, dropAfter: 0, kill: 0);
    await a.pull(ok, colls);
    await b.pull(ok, colls);
    expect(a.snapshot('bills').length, 600);
    expect(a.snapshot('bills'), b.snapshot('bills'));
  });
}
