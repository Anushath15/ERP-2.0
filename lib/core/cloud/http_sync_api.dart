import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/sync/sync_api.dart';
import 'cloud_config.dart';

/// The two Supabase functions the sync uses (`push_docs`, `pull_docs`, supabase/migrations), over plain HTTPS.
/// [credentials] gives a valid token and the shop id each time (or null when signed out); [onUnauthorized] is told when the cloud
/// said the token is no good, so the next call asks for a new one.
class HttpSyncApi implements SyncApi {
  HttpSyncApi(this.config, this.deviceId, this.credentials, {http.Client? client, this.onUnauthorized}) : _http = client ?? http.Client();

  final CloudConfig config;
  final String deviceId;
  final Future<({String token, String shopId})?> Function() credentials;
  final void Function()? onUnauthorized;
  final http.Client _http;

  Future<Object?> _rpc(String fn, Map<String, Object?> body) async {
    final c = await credentials();
    if (c == null) throw const SyncAuthFailed('signed out');
    final payload = {'p_shop': c.shopId, ...body};
    http.Response r;
    try {
      r = await _http
          .post(Uri.parse('${config.base}/rest/v1/rpc/$fn'),
              headers: {'apikey': config.key, 'Authorization': 'Bearer ${c.token}', 'Content-Type': 'application/json'}, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 40));
    } catch (e) {
      throw SyncOffline('$e');
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      final text = utf8.decode(r.bodyBytes);
      return text.isEmpty ? null : jsonDecode(text);
    }
    String code = '', message = '';
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map) {
        code = '${j['code'] ?? ''}';
        message = '${j['message'] ?? ''}';
      }
    } catch (_) {}
    if (r.statusCode == 401 || (r.statusCode == 400 && message.contains('JWT'))) {
      onUnauthorized?.call();
      throw SyncAuthFailed(message);
    }
    if (r.statusCode >= 500 || r.statusCode == 408 || r.statusCode == 429) throw SyncOffline('${r.statusCode} $message');
    // 42501: not allowed. "not a member" / "removed" = this sign-in or computer lost access; anything else is about that document
    if (code == '42501' && (message.contains('not a member') || message.contains('removed'))) throw SyncAuthFailed(message);
    throw SyncRejected(message.isEmpty ? 'HTTP ${r.statusCode}' : message);
  }

  @override
  Future<void> push(List<SyncDoc> docs) async {
    await _rpc('push_docs', {'p_device': deviceId, 'p_docs': [for (final d in docs) d.toJson()]});
  }

  @override
  Future<List<PulledDoc>> pull(int after, int limit) async {
    final j = await _rpc('pull_docs', {'p_after': after, 'p_limit': limit});
    if (j is! List) return const [];
    return [
      for (final x in j)
        if (x is Map)
          PulledDoc(
            seq: (x['seq'] as num).toInt(),
            deviceId: '${x['device_id'] ?? ''}',
            coll: '${x['coll']}',
            id: '${x['id']}',
            data: x['data'] is Map ? (x['data'] as Map).cast<String, Object?>() : <String, Object?>{},
            hlc: '${x['hlc'] ?? ''}',
            deleted: x['deleted'] == true,
          ),
    ];
  }
}
