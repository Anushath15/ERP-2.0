import 'dart:typed_data';
import '../app_data.dart';
import '../context.dart';
import '../../core/lan/lan_crypto.dart';
import '../../core/lan/lan_transport.dart';
import 'sync_api.dart';
import 'sync_engine.dart';

/// Another counter of the shop that this computer sends its changes to.
class LanPeer {
  const LanPeer({required this.chan, required this.host, required this.port, required this.deviceId, required this.name});
  final String chan, host, deviceId, name;
  final int port;
}

/// Sends changes to ONE other counter over the shop Wi-Fi (the receiving counter applies them like cloud ones). Send-only from this
/// side: what the other counter changed arrives because it sends to us the same way.
class LanPeerApi implements SyncApi {
  LanPeerApi(this.net, this.key, this.host, this.port, this.fromDevice);
  final LanTransport net;
  final LanKey key;
  final String host, fromDevice;
  final int port;

  @override
  bool get canPull => false;

  @override
  Future<List<PulledDoc>> pull(int after, int limit) async => const [];

  @override
  Future<void> push(List<SyncDoc> docs) async {
    const path = '/lan/v1/push';
    final body = await lanSeal(key, {'path': path, 'from': fromDevice, 'docs': [for (final d in docs) d.toJson()]});
    ({int status, Uint8List body}) r;
    try {
      r = await net.post(host, port, path, body);
    } catch (e) {
      throw SyncOffline('$e');
    }
    if (r.status == 200) {
      // the answer must be sealed by the real counter and name THIS request (a recorded or made-up "200" proves nothing)
      try {
        final ok = await lanOpen(key, r.body);
        if (ok['re'] != lanNonce(body)) throw const LanSealException();
      } on LanSealException {
        throw const SyncAuthFailed('the answer was not from the linked counter');
      }
      return;
    }
    if (r.status == 401) throw const SyncAuthFailed('wrong counter-link key');
    if (r.status >= 500 || r.status == 408) throw SyncOffline('${r.status}');
    throw SyncRejected('HTTP ${r.status}');
  }
}

enum LanLinkProblem { badAddress, unreachable, wrongKey, thisComputer }

class LanLinkException implements Exception {
  const LanLinkException(this.problem);
  final LanLinkProblem problem;
  @override
  String toString() => 'LanLinkException($problem)';
}

class _NoApi implements SyncApi {
  @override
  bool get canPull => false;
  @override
  Future<List<PulledDoc>> pull(int after, int limit) async => const [];
  @override
  Future<void> push(List<SyncDoc> docs) async {}
}

/// The counter link of this computer: answers the other counters and sends them our changes. Pure logic over [LanTransport]; the timer and
/// the screen are in `lan_controller.dart`.
class LanLink {
  LanLink(this.data, this.net, this.key, {this.name = '', this.port = lanPort, this.onChanged});
  final AppData data;
  final LanTransport net;
  final LanKey key;
  final String name;
  final int port;

  /// Called when another counter's changes were applied here (the screens are then older than the database).
  final void Function()? onChanged;

  late final SyncEngine _receiver = SyncEngine(data.cx, _NoApi(), onChanged: onChanged);

  /// SECURITY: a message recorded on the Wi-Fi and sent again is refused (each sealed message has its own nonce).
  final _replay = LanReplayGuard();

  /// chan -> '' (fine) or the problem, from the last round.
  final Map<String, String> status = {};

  String get deviceId => data.cx.deviceId;

  Future<void> start() => net.serve(port, _handle);
  Future<void> stop() => net.stopServing();

  Future<Uint8List> _reply(Map<String, Object?> m, String re) => lanSeal(key, {...m, 're': re});

  Future<Uint8List> _handle(String path, Uint8List body, String ip) async {
    final Map<String, Object?> msg;
    try {
      msg = await lanOpen(key, body);
    } on LanSealException {
      throw const LanRefused(401);
    }
    // SECURITY: the sealed message names the address it was meant for (a message for one cannot be used on another), and it is used once only
    if (msg['path'] != path || !_replay.fresh(lanNonce(body))) throw const LanRefused(401);
    final re = lanNonce(body);
    switch (path) {
      case '/lan/v1/hello':
        return _reply({'deviceId': deviceId, 'name': name}, re);
      case '/lan/v1/link':
        final id = '${msg['deviceId'] ?? ''}';
        if (id.isEmpty || id == deviceId) throw const LanRefused(400);
        await _savePeer(LanPeer(chan: 'lan-$id', host: ip, port: (msg['port'] as num?)?.toInt() ?? lanPort, deviceId: id, name: '${msg['name'] ?? ''}'));
        return _reply({'deviceId': deviceId, 'name': name}, re);
      case '/lan/v1/push':
        final from = '${msg['from'] ?? ''}';
        final list = msg['docs'];
        if (list is! List) throw const LanRefused(400);
        final docs = <PulledDoc>[
          for (final x in list)
            if (x is Map)
              PulledDoc(
                seq: 0,
                deviceId: from,
                coll: '${x['coll']}',
                id: '${x['id']}',
                data: x['data'] is Map ? (x['data'] as Map).cast<String, Object?>() : <String, Object?>{},
                hlc: '${x['hlc'] ?? ''}',
                deleted: x['deleted'] == true,
              ),
        ];
        final n = await _receiver.applyIncoming(docs);
        return _reply({'applied': n}, re);
      default:
        throw const LanRefused(404);
    }
  }

  Future<void> _savePeer(LanPeer p) => data.db.exec(
      'INSERT INTO lan_peers(chan, host, port, device_id, name, created_at) VALUES (?,?,?,?,?,?) ON CONFLICT(chan) DO UPDATE SET host = excluded.host, port = excluded.port, name = excluded.name',
      [p.chan, p.host, p.port, p.deviceId, p.name, data.cx.nowMs()]);

  Future<List<LanPeer>> peers() async => [
        for (final r in await data.db.rows('SELECT chan, host, port, device_id, name FROM lan_peers ORDER BY created_at'))
          LanPeer(chan: r.read<String>('chan'), host: r.read<String>('host'), port: r.read<int>('port'), deviceId: r.read<String>('device_id'), name: r.read<String>('name')),
      ];

  /// Links with the counter at [host]: checks the key against it, remembers it, and tells it to remember this computer too.
  /// Throws [LanLinkException].
  Future<LanPeer> addPeer(String host, {int? port}) async {
    final p = port ?? lanPort;
    final mine = this.port;
    final h = host.trim();
    if (!RegExp(r'^[0-9A-Za-z.\-]{1,100}$').hasMatch(h)) throw const LanLinkException(LanLinkProblem.badAddress);
    Future<Map<String, Object?>> call(String path, Map<String, Object?> m) async {
      ({int status, Uint8List body}) r;
      final sealed = await lanSeal(key, {...m, 'path': path});
      try {
        r = await net.post(h, p, path, sealed);
      } catch (_) {
        throw const LanLinkException(LanLinkProblem.unreachable);
      }
      if (r.status == 401) throw const LanLinkException(LanLinkProblem.wrongKey);
      if (r.status != 200) throw const LanLinkException(LanLinkProblem.unreachable);
      try {
        final answer = await lanOpen(key, r.body);
        if (answer['re'] != lanNonce(sealed)) throw const LanSealException(); // an old answer played back
        return answer;
      } on LanSealException {
        throw const LanLinkException(LanLinkProblem.wrongKey);
      }
    }

    final hello = await call('/lan/v1/hello', {});
    final id = '${hello['deviceId'] ?? ''}';
    if (id.isEmpty) throw const LanLinkException(LanLinkProblem.unreachable);
    if (id == deviceId) throw const LanLinkException(LanLinkProblem.thisComputer);
    final peer = LanPeer(chan: 'lan-$id', host: h, port: p, deviceId: id, name: '${hello['name'] ?? ''}');
    await call('/lan/v1/link', {'deviceId': deviceId, 'name': name, 'port': mine});
    await _savePeer(peer);
    return peer;
  }

  Future<void> removePeer(String chan) async {
    await data.db.transaction(() async {
      await data.db.exec('DELETE FROM lan_peers WHERE chan = ?', [chan]);
      await data.db.exec('DELETE FROM outbox WHERE chan = ?', [chan]);
      await data.db.exec('DELETE FROM sync_meta WHERE name = ?', ['backfilled:$chan']);
    });
    status.remove(chan);
  }

  /// One round to every linked counter. Never throws; [status] says which counters could not be reached.
  Future<void> syncOnce() async {
    for (final p in await peers()) {
      final e = SyncEngine(data.cx, LanPeerApi(net, key, p.host, p.port, deviceId), chan: p.chan);
      try {
        await e.run();
        status[p.chan] = '';
      } on SyncOffline catch (x) {
        status[p.chan] = x.message.isEmpty ? 'offline' : x.message;
      } on SyncAuthFailed {
        status[p.chan] = 'wrong key';
      } catch (x) {
        status[p.chan] = '$x';
      }
    }
  }
}
