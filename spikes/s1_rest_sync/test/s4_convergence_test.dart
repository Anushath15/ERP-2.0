// Phase 0 follow-up: two devices work offline (bills, purchases, adjustments, opening stock,
// payments), sync in random order with lost, duplicated and delayed deliveries, and must end with
// identical stock, balances and totals. Stock and balances are DERIVED from synced records only.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:s1_rest_sync/engine.dart';
import 'package:s1_rest_sync/rest.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

const _u = Uuid();
final client = http.Client();
const colls = ['bills', 'purchases', 'stockMovements', 'payments', 'products', 'customers'];

/// Derived state, computed from records only (the rule for every screen).
class Derived {
  Derived(this.stock, this.balance, this.salesTotal, this.billCount);
  final Map<String, int> stock; // productId -> milli units
  final Map<String, int> balance; // customerId -> paise they owe
  final int salesTotal;
  final int billCount;
  @override
  String toString() => 'stock=$stock balance=$balance sales=$salesTotal bills=$billCount';
  @override
  bool operator ==(Object o) =>
      o is Derived &&
      _eq(stock, o.stock) &&
      _eq(balance, o.balance) &&
      salesTotal == o.salesTotal &&
      billCount == o.billCount;
  @override
  int get hashCode => Object.hash(salesTotal, billCount);
  static bool _eq(Map a, Map b) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

Derived derive(Engine e) {
  final stock = <String, int>{}, balance = <String, int>{};
  var sales = 0, bills = 0;
  Map<String, dynamic> j(String s) => jsonDecode(s) as Map<String, dynamic>;
  for (final r in e.db.select('SELECT coll,json FROM records')) {
    final c = r['coll'] as String;
    final d = j(r['json'] as String);
    switch (c) {
      case 'bills':
        bills++;
        sales += d['total'] as int;
        for (final l in (d['lines'] as List)) {
          stock.update(l['productId'], (v) => v - (l['qtyMilli'] as int), ifAbsent: () => -(l['qtyMilli'] as int));
        }
        balance.update(d['customerId'], (v) => v + (d['total'] as int) - (d['paid'] as int), ifAbsent: () => (d['total'] as int) - (d['paid'] as int));
      case 'purchases':
        for (final l in (d['lines'] as List)) {
          stock.update(l['productId'], (v) => v + (l['qtyMilli'] as int), ifAbsent: () => l['qtyMilli'] as int);
        }
      case 'stockMovements': // adjustment / opening
        stock.update(d['productId'], (v) => v + (d['qtyMilli'] as int), ifAbsent: () => d['qtyMilli'] as int);
      case 'payments':
        balance.update(d['customerId'], (v) => v - (d['amount'] as int), ifAbsent: () => -(d['amount'] as int));
    }
  }
  return Derived(stock, balance, sales, bills);
}

/// Remote that (1) drops requests, (2) loses replies, (3) later RE-SENDS an old batch (delayed duplicate).
class MessyRemote implements Remote {
  MessyRemote(this.inner, this.rnd);
  final Remote inner;
  final Random rnd;
  final old = <List<({String coll, String id, Map<String, Object?> data})>>[];
  bool online = true;
  int resent = 0;

  @override
  Future<DateTime> commit(List<({String coll, String id, Map<String, Object?> data})> docs) async {
    if (!online || rnd.nextDouble() < 0.2) throw FbException(0, 'NETWORK', 'down');
    final t = await inner.commit(docs);
    old.add(docs);
    if (old.length > 1 && rnd.nextDouble() < 0.4) {
      // a delayed, duplicated delivery of an OLDER batch arrives now
      await inner.commit(old[rnd.nextInt(old.length - 1)]);
      resent++;
    }
    if (rnd.nextDouble() < 0.2) throw FbException(0, 'NETWORK', 'reply lost');
    return t;
  }

  @override
  Future<List<Map<String, Object?>>> pull(String coll, ({String ts, String id})? c, int limit) async {
    if (!online || rnd.nextDouble() < 0.15) throw FbException(0, 'NETWORK', 'down');
    return inner.pull(coll, c, limit);
  }
}

Future<RestRemote> shop() async {
  final a = AuthRest(client);
  final email = 'conv${DateTime.now().microsecondsSinceEpoch}@example.com';
  final s = await a.signUp(email, 'secret-pass-1');
  await a.verifyEmailViaEmulator(s);
  await a.refresh(s);
  final sh = 'shop-conv-${DateTime.now().microsecondsSinceEpoch}';
  const base = 'projects/$projectId/databases/(default)/documents';
  final r = await client.post(Uri.parse('$fsBase/v1/$base:commit'),
      headers: {'content-type': 'application/json', 'authorization': 'Bearer ${s.idToken}'},
      body: '{"writes":[{"update":{"name":"$base/shops/$sh","fields":{"ownerEmail":{"stringValue":"$email"}}}},'
          '{"update":{"name":"$base/shops/$sh/members/$email","fields":{"role":{"stringValue":"owner"}}}}]}');
  expect(r.statusCode, 200, reason: r.body);
  return RestRemote(FirestoreRest(client, s), sh);
}

Future<void> syncRound(Engine e, Remote r) async {
  try {
    await e.pushAll(r);
  } on FbException {/* ignored: retried next round */}
  try {
    await e.pull(r, colls);
  } on FbException {/* ignored */}
}

String tmp(String n) => '${Directory.systemTemp.path}\\conv_${n}_${DateTime.now().microsecondsSinceEpoch}.sqlite';

void main() {
  for (final seed in [11, 22, 33]) {
    test('convergence, seed $seed: opening stock, bills, purchases, adjustments, payments, chaos', () async {
      final rnd = Random(seed);
      final remote = await shop();
      final msy = MessyRemote(remote, rnd);
      final a = Engine(tmp('A$seed'), 'A', batchSize: 40, pageSize: 50);
      final b = Engine(tmp('B$seed'), 'B', batchSize: 40, pageSize: 50);
      final prods = [for (var i = 0; i < 30; i++) _u.v7()];
      final custs = [for (var i = 0; i < 20; i++) _u.v7()];

      // Device A records the opening stock BEFORE anything else; B learns it by sync.
      for (final p in prods) {
        a.save('stockMovements', _u.v7(), {'productId': p, 'qtyMilli': 100000, 'kind': 'opening'});
      }
      var seqA = 0, seqB = 0;
      void act(Engine e, String dev) {
        final k = rnd.nextInt(10);
        if (k < 5) {
          final n = dev == 'A' ? ++seqA : ++seqB;
          final lines = [
            for (var i = 0; i < 1 + rnd.nextInt(4); i++)
              {'productId': prods[rnd.nextInt(30)], 'qtyMilli': 1000 * (1 + rnd.nextInt(5)), 'amountPaise': 100 * (1 + rnd.nextInt(900))}
          ];
          final total = lines.fold<int>(0, (s, l) => s + (l['amountPaise'] as int));
          e.save('bills', _u.v7(), {'number': '$dev-$n', 'customerId': custs[rnd.nextInt(20)], 'lines': lines, 'total': total, 'paid': rnd.nextBool() ? total : 0});
        } else if (k < 7) {
          e.save('purchases', _u.v7(), {'lines': [{'productId': prods[rnd.nextInt(30)], 'qtyMilli': 10000 * (1 + rnd.nextInt(5))}]});
        } else if (k < 8) {
          e.save('stockMovements', _u.v7(), {'productId': prods[rnd.nextInt(30)], 'qtyMilli': (rnd.nextBool() ? 1 : -1) * 1000 * (1 + rnd.nextInt(3)), 'kind': 'adjustment'});
        } else {
          e.save('payments', _u.v7(), {'customerId': custs[rnd.nextInt(20)], 'amount': 100 * (1 + rnd.nextInt(500))});
        }
      }

      // Phase 1: both devices work offline, interleaved, with occasional random syncs.
      for (var i = 0; i < 150; i++) {
        act(a, 'A');
        act(b, 'B');
        if (rnd.nextDouble() < 0.2) await syncRound(rnd.nextBool() ? a : b, msy);
      }
      // Phase 2: sync in random order, with chaos, until both are quiet.
      for (var i = 0; i < 400 && (a.pendingCount > 0 || b.pendingCount > 0); i++) {
        await syncRound(rnd.nextBool() ? a : b, msy);
      }
      expect(a.pendingCount + b.pendingCount, 0, reason: 'everything uploaded');
      // Phase 3: calm network, final pulls.
      msy.online = true;
      final calm = RestRemote(remote.fs, remote.shop);
      await a.pull(calm, colls);
      await b.pull(calm, colls);

      final da = derive(a), db = derive(b);
      expect(da, db, reason: 'both devices derive the same stock, balances and totals');
      // Independent truth: derive from a THIRD fresh device that only restores from the cloud.
      final c = Engine(tmp('C$seed'), 'C');
      await c.pull(calm, colls);
      expect(derive(c), da, reason: 'a fresh device restores to the same numbers');
      expect(da.billCount, greaterThan(100));
      final nums = a.db.select("SELECT json_extract(json,'\$.number') n FROM records WHERE coll='bills' AND json_extract(json,'\$.number') NOT LIKE '-%'").map((r) => r['n']).toList();
      expect(nums.toSet().length, nums.length, reason: 'no invoice number repeated');
      print('seed $seed: bills=${da.billCount} sales=${da.salesTotal} delayedDuplicates=${msy.resent} server writes=${remote.fs.writes}');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
