/// Spike S1: Firebase Auth + Firestore through the plain REST APIs.
/// This is the fallback if the official Windows SDK is unreliable, and it is
/// also the transport the S4 sync chaos tests run on.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

const projectId = 'demo-erp2';
const authBase = 'http://127.0.0.1:9099';
const fsBase = 'http://127.0.0.1:8080';

class FbException implements Exception {
  FbException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
  bool get isPermissionDenied => code == 'PERMISSION_DENIED';
  bool get isNetwork => status == 0;
  @override
  String toString() => 'FbException($status $code: $message)';
}

class Session {
  Session(this.idToken, this.refreshToken, this.uid, this.email);
  String idToken;
  String refreshToken;
  final String uid;
  final String email;
}

class AuthRest {
  AuthRest(this.client);
  final http.Client client;

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final r = await client.post(Uri.parse('$authBase/$path?key=fake-key'),
        headers: {'content-type': 'application/json'}, body: jsonEncode(body));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) {
      throw FbException(r.statusCode, (j['error']?['message'] ?? 'ERR').toString(), r.body);
    }
    return j;
  }

  Future<Session> signUp(String email, String password) async {
    final j = await _post('identitytoolkit.googleapis.com/v1/accounts:signUp',
        {'email': email, 'password': password, 'returnSecureToken': true});
    return Session(j['idToken'], j['refreshToken'], j['localId'], email);
  }

  Future<Session> signIn(String email, String password) async {
    final j = await _post('identitytoolkit.googleapis.com/v1/accounts:signInWithPassword',
        {'email': email, 'password': password, 'returnSecureToken': true});
    return Session(j['idToken'], j['refreshToken'], j['localId'], email);
  }

  /// Sends the verification mail; in the emulator reads the code and confirms it.
  Future<void> verifyEmailViaEmulator(Session s) async {
    await _post('identitytoolkit.googleapis.com/v1/accounts:sendOobCode',
        {'requestType': 'VERIFY_EMAIL', 'idToken': s.idToken});
    final r = await client.get(Uri.parse('$authBase/emulator/v1/projects/$projectId/oobCodes'));
    final codes = (jsonDecode(r.body)['oobCodes'] as List).cast<Map<String, dynamic>>();
    final mine = codes.lastWhere((c) => c['email'] == s.email && c['requestType'] == 'VERIFY_EMAIL');
    await _post('identitytoolkit.googleapis.com/v1/accounts:update', {'oobCode': mine['oobCode']});
  }

  Future<void> refresh(Session s) async {
    final r = await client.post(
        Uri.parse('$authBase/securetoken.googleapis.com/v1/token?key=fake-key'),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: {'grant_type': 'refresh_token', 'refresh_token': s.refreshToken});
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw FbException(r.statusCode, 'REFRESH', r.body);
    s.idToken = j['id_token'];
    s.refreshToken = j['refresh_token'];
  }
}

// ---------- Firestore value encoding ----------
Map<String, dynamic> encodeValue(Object? v) {
  if (v == null) return {'nullValue': null};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': v.toString()};
  if (v is double) return {'doubleValue': v};
  if (v is String) return {'stringValue': v};
  if (v is List) return {'arrayValue': {'values': v.map(encodeValue).toList()}};
  if (v is Map) {
    return {'mapValue': {'fields': v.map((k, x) => MapEntry(k as String, encodeValue(x)))}};
  }
  throw ArgumentError('unsupported ${v.runtimeType}');
}

Object? decodeValue(Map<String, dynamic> v) {
  if (v.containsKey('nullValue')) return null;
  if (v.containsKey('booleanValue')) return v['booleanValue'];
  if (v.containsKey('integerValue')) return int.parse(v['integerValue']);
  if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
  if (v.containsKey('stringValue')) return v['stringValue'];
  if (v.containsKey('timestampValue')) return v['timestampValue'];
  if (v.containsKey('arrayValue')) {
    return ((v['arrayValue']['values'] ?? []) as List).map((e) => decodeValue(e)).toList();
  }
  if (v.containsKey('mapValue')) {
    return ((v['mapValue']['fields'] ?? {}) as Map)
        .map((k, x) => MapEntry(k as String, decodeValue(x)));
  }
  throw ArgumentError('unknown value $v');
}

Map<String, Object?> decodeDoc(Map<String, dynamic> d) =>
    ((d['fields'] ?? {}) as Map).map((k, v) => MapEntry(k as String, decodeValue(v)));

class FirestoreRest {
  FirestoreRest(this.client, this.session);
  final http.Client client;
  Session session;
  int reads = 0;
  int writes = 0;

  String get _db => 'projects/$projectId/databases/(default)/documents';

  Map<String, String> get _h => {
        'content-type': 'application/json',
        'authorization': 'Bearer ${session.idToken}',
      };

  Never _fail(http.Response r) {
    String code = 'UNKNOWN', msg = r.body;
    try {
      final j = jsonDecode(r.body);
      final e = (j is List ? j.first : j)['error'];
      code = e['status'] ?? code;
      msg = e['message'] ?? msg;
    } catch (_) {}
    throw FbException(r.statusCode, code, msg);
  }

  Map<String, dynamic> _write(String path, Map<String, Object?> data,
      {bool stamp = true}) {
    final w = <String, dynamic>{
      'update': {'name': '$_db/$path', 'fields': data.map((k, v) => MapEntry(k, encodeValue(v)))},
    };
    if (stamp) {
      w['updateTransforms'] = [
        {'fieldPath': 'serverAt', 'setToServerValue': 'REQUEST_TIME'}
      ];
    }
    return w;
  }

  /// One atomic commit (max 500 writes). Throws FbException on any failure.
  Future<DateTime> commit(List<({String path, Map<String, Object?> data})> docs) async {
    if (docs.length > 500) throw ArgumentError('max 500 per batch');
    final r = await client.post(Uri.parse('$fsBase/v1/$_db:commit'),
        headers: _h, body: jsonEncode({'writes': docs.map((d) => _write(d.path, d.data)).toList()}));
    if (r.statusCode != 200) _fail(r);
    writes += docs.length;
    return DateTime.parse(jsonDecode(r.body)["commitTime"] as String);
  }

  /// Like [commit], but each document says whether the server stamp (serverAt) is added.
  Future<DateTime> commitMixed(List<({String path, Map<String, Object?> data, bool stamp})> docs) async {
    final r = await client.post(Uri.parse('$fsBase/v1/$_db:commit'),
        headers: _h, body: jsonEncode({'writes': docs.map((d) => _write(d.path, d.data, stamp: d.stamp)).toList()}));
    if (r.statusCode != 200) _fail(r);
    writes += docs.length;
    return DateTime.parse(jsonDecode(r.body)["commitTime"] as String);
  }

  Future<Map<String, Object?>?> get(String path) async {
    final r = await client.get(Uri.parse('$fsBase/v1/$_db/$path'), headers: _h);
    reads++;
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) _fail(r);
    return decodeDoc(jsonDecode(r.body));
  }

  /// Documents of [coll] after [cursor] = (serverAt, id), oldest first. The cursor is a
  /// PAIR because one batch commit gives up to 500 documents the same timestamp; a
  /// timestamp-only cursor would skip some of them (found by test S1).
  Future<List<Map<String, Object?>>> pullAfter(String parentPath, String coll,
      ({String ts, String id})? cursor,
      {int limit = 300}) async {
    final q = <String, dynamic>{
      'from': [
        {'collectionId': coll}
      ],
      'orderBy': [
        {'field': {'fieldPath': 'serverAt'}, 'direction': 'ASCENDING'},
        {'field': {'fieldPath': '__name__'}, 'direction': 'ASCENDING'},
      ],
      'limit': limit,
    };
    if (cursor != null) {
      q['startAt'] = {
        'before': false,
        'values': [
          {'timestampValue': cursor.ts},
          {'referenceValue': '$_db/$parentPath/$coll/${cursor.id}'},
        ]
      };
    }
    final r = await client.post(Uri.parse('$fsBase/v1/$_db/$parentPath:runQuery'),
        headers: _h, body: jsonEncode({'structuredQuery': q}));
    if (r.statusCode != 200) _fail(r);
    final rows = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
    final out = <Map<String, Object?>>[];
    for (final row in rows) {
      if (row['document'] != null) out.add(decodeDoc(row['document']));
    }
    reads += out.isEmpty ? 1 : out.length;
    return out;
  }
}
