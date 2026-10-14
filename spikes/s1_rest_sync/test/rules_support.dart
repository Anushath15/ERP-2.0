// Shared helpers for the security-rules tests (production rules in firebase/firestore.allowlist.rules, run on the emulator).
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:s1_rest_sync/rest.dart';
import 'package:test/test.dart';

final client = http.Client();
const shop = 'shops/s1';

/// The people of the test shop. Fresh addresses per run (the Auth emulator keeps accounts until it stops).
final run = DateTime.now().microsecondsSinceEpoch;
final ownerEmail = 'owner$run@example.com';
final manager1 = 'manager$run@example.com';
final cashier1 = 'cashier$run@example.com';
final cashier2 = 'cashier2$run@example.com';
final stranger = 'stranger$run@example.com';

String? original;

/// Loads the production rules with the test people. [caps] are the daily batch limits (owner, manager, cashier).
Future<void> loadRules({List<String> owners = const [], List<String> managers = const [], List<String> cashiers = const [], (int, int, int) caps = (24, 24, 20)}) async {
  original ??= File('../../firebase/firestore.rules').readAsStringSync();
  var t = File('../../firebase/firestore.allowlist.rules').readAsStringSync();
  String list(List<String> l) => l.map((e) => "'$e'").join(', ');
  t = t
      .replaceAll("/*OWNERS*/'__OWNER_EMAIL__'", list(owners.isEmpty ? [ownerEmail] : owners))
      .replaceAll('/*MANAGERS*/', list(managers.isEmpty ? [manager1] : managers))
      .replaceAll('/*CASHIERS*/', list(cashiers.isEmpty ? [cashier1, cashier2] : cashiers))
      .replaceAll('/*CAP_OWNER*/24', '${caps.$1}')
      .replaceAll('/*CAP_MANAGER*/24', '${caps.$2}')
      .replaceAll('/*CAP_CASHIER*/20', '${caps.$3}');
  final r = await client.put(Uri.parse('$fsBase/emulator/v1/projects/$projectId:securityRules'), body: jsonEncode({'rules': {'files': [{'name': 'firestore.rules', 'content': t}]}}));
  expect(r.statusCode, 200, reason: r.body);
}

Future<void> restoreRules() async {
  if (original == null) return;
  final r = await client.put(Uri.parse('$fsBase/emulator/v1/projects/$projectId:securityRules'), body: jsonEncode({'rules': {'files': [{'name': 'firestore.rules', 'content': original}]}}));
  expect(r.statusCode, 200, reason: r.body);
}

class Actor {
  Actor(this.email, this.fs, this.session);
  final String email;
  final FirestoreRest fs;
  final Session session;
  String get device => 'dev-${email.split('@').first}'.padRight(12, 'x');
}

final _actors = <String, Actor>{};

/// Signs the person up (verified e-mail) once per run.
Future<Actor> actor(String email, {bool verify = true}) async {
  final key = '$email/$verify';
  final c = _actors[key];
  if (c != null) return c;
  final a = AuthRest(client);
  final s = await a.signUp(email, 'secret-pass-1');
  if (verify) {
    await a.verifyEmailViaEmulator(s);
    await a.refresh(s);
  }
  return _actors[key] = Actor(email, FirestoreRest(client, s), s);
}

int nowMs() => DateTime.now().millisecondsSinceEpoch;

int dayNumber() {
  final n = DateTime.now().toUtc();
  return n.year * 10000 + n.month * 100 + n.day;
}

String usageId(String email) => '${email.toLowerCase()}_${dayNumber()}';

int _seq = 0;
String id(String prefix) => '$prefix-${run % 100000}-${_seq++}'.padRight(10, 'x');

/// A doc to write: path, data, whether the server stamp is added.
typedef W = ({String path, Map<String, Object?> data, bool stamp});
/// A doc whose id is made here and handed to [make], so the record's own id always matches its path.
W wn(String coll, String prefix, Map<String, Object?> Function(String) make, {bool stamp = true}) {
  final i = id(prefix);
  return w(coll, i, make(i), stamp: stamp);
}

W w(String coll, String docId, Map<String, Object?> data, {bool stamp = true}) => (path: '$shop/$coll/$docId', data: data, stamp: stamp);

Future<int> usageNow(Actor a) async {
  try {
    final d = await a.fs.get('$shop/usage/${usageId(a.email)}');
    return (d?['batches'] as int?) ?? 0;
  } catch (_) {
    return 0;
  }
}

/// One batch exactly as the app sends it: the business documents plus the bump of today's counter. [bump] false = forget the counter.
Future<void> send(Actor a, List<W> docs, {bool bump = true, int? bumpBy, String? usageEmail}) async {
  final all = [...docs];
  if (bump) {
    final n = await usageNow(a);
    final e = usageEmail ?? a.email;
    all.add((path: '$shop/usage/${usageId(e)}', data: {'email': e.toLowerCase(), 'day': dayNumber(), 'batches': n + (bumpBy ?? 1)}, stamp: false));
  }
  await a.fs.commitMixed(all);
}

/// A device that the owner has approved for [a] (the pending record is made by the person, the approval by the owner).
Future<void> approvedDevice(Actor a, Actor owner) async {
  final devId = a.device;
  final created = nowMs();
  await a.fs.commitMixed([
    w('devices', devId, {'id': devId, 'ownerEmail': a.email, 'name': 'Test PC of ${a.email.split('@').first}', 'platform': 'windows', 'status': 'pending', 'createdAt': created}),
  ]);
  await owner.fs.commitMixed([
    w('devices', devId, {'id': devId, 'ownerEmail': a.email, 'name': 'Test PC of ${a.email.split('@').first}', 'platform': 'windows', 'status': 'approved', 'createdAt': created, 'approvedBy': owner.email, 'approvedAt': nowMs()}),
  ]);
}

// ------------------------------------------------------------------ valid documents
Map<String, Object?> baseDoc(String docId, Actor a, {bool editable = false}) => {'id': docId, 'deviceId': a.device, 'createdBy': a.email, if (editable) 'updatedBy': a.email, 'updatedAt': nowMs(), if (editable) 'version': 1};

Map<String, Object?> bill(String docId, Actor a, {int total = 15000, int received = 15000, String? customerId}) =>
    {...baseDoc(docId, a), 'number': 'A-${docId.hashCode.abs() % 1000000}', 'status': 0, 'totalPaise': total, 'receivedPaise': received, 'balancePaise': total > received ? total - received : 0, 'taxPaise': total * 18 ~/ 118, 'payMode': 0, 'billedAt': nowMs(), 'day': '2026-10-14', 'idemKey': docId, if (customerId != null) 'customerId': customerId};

Map<String, Object?> product(String docId, Actor a, {int price = 15000, int? cost = 9000}) =>
    {...baseDoc(docId, a, editable: true), 'name': 'Hacksaw blade', 'pricePaise': price, if (cost != null) 'costPaise': cost, 'gstBp': 1800, 'unit': 'pcs', 'minQtyMilli': 5000, 'active': true};

Map<String, Object?> customer(String docId, Actor a, {int limit = 0, String name = 'New Customer'}) => {...baseDoc(docId, a, editable: true), 'name': name, 'creditLimitPaise': limit, 'phone': '9876543210'};

Map<String, Object?> payment(String docId, Actor a, {int amount = 5000}) => {...baseDoc(docId, a), 'amountPaise': amount, 'mode': 'cash', 'date': nowMs(), 'advancePaise': 0, 'customerId': 'c1'};

Map<String, Object?> ledger(String docId, Actor a, {String kind = 'billCredit', int amount = 5000}) => {...baseDoc(docId, a), 'partyId': 'c1', 'kind': kind, 'amountPaise': amount, 'at': nowMs()};

Map<String, Object?> movement(String docId, Actor a, {int qty = -1000, String kind = 'sale'}) => {...baseDoc(docId, a), 'productId': 'p1', 'qtyMilli': qty, 'kind': kind, 'at': nowMs()};

Map<String, Object?> audit(String docId, Actor a, {required String action, required String entity, required String entityId, required String field, Object? oldValue, Object? newValue}) =>
    {...baseDoc(docId, a), 'action': action, 'entity': entity, 'entityId': entityId, 'field': field, 'oldValue': oldValue, 'newValue': newValue, 'by': a.email, 'at': nowMs()};

/// Expect the write to be refused by the rules.
Future<void> refused(Future<void> f, {String? reason}) async {
  try {
    await f;
  } on FbException catch (e) {
    expect(e.code == 'PERMISSION_DENIED' || e.status == 403 || e.status == 400 || e.status == 500, isTrue, reason: 'expected a refusal, got ${e.status} ${e.code}');
    return;
  }
  fail('the write was accepted but must be refused${reason == null ? '' : ': $reason'}');
}
