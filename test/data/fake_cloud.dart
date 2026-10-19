import 'package:erp2/data/sync/sync_api.dart';
import 'package:erp2/data/sync/sync_triggers.dart';

/// The cloud copy in memory, behaving like Supabase push_docs / pull_docs: one row per (coll, id); append-only collections keep the first copy;
/// others keep the newer stamp; every accepted change gets the next position.
class FakeCloud {
  final Map<String, PulledDoc> docs = {};
  int _seq = 0;
  bool offline = false;
  int pushCalls = 0;

  /// Documents this pretend cloud refuses for good.
  bool Function(SyncDoc d)? reject;

  SyncApi client(String device) => _Client(this, device);

  void _push(String device, List<SyncDoc> list) {
    pushCalls++;
    if (list.length > 100) throw const SyncRejected('batch too big');
    if (list.any((d) => reject?.call(d) ?? false)) throw const SyncRejected('refused');
    for (final d in list) {
      final key = '${d.coll}/${d.id}';
      final old = docs[key];
      final append = syncTable(d.coll)?.appendOnly ?? false;
      if (old != null && (append || d.hlc.compareTo(old.hlc) <= 0)) continue;
      docs[key] = PulledDoc(seq: ++_seq, deviceId: device, coll: d.coll, id: d.id, data: d.data, hlc: d.hlc, deleted: d.deleted);
    }
  }
}

class _Client implements SyncApi {
  _Client(this.cloud, this.device);
  final FakeCloud cloud;
  final String device;

  @override
  Future<void> push(List<SyncDoc> docs) async {
    if (cloud.offline) throw const SyncOffline('no internet');
    cloud._push(device, docs);
  }

  @override
  Future<List<PulledDoc>> pull(int after, int limit) async {
    if (cloud.offline) throw const SyncOffline('no internet');
    final l = cloud.docs.values.where((d) => d.seq > after).toList()..sort((a, b) => a.seq.compareTo(b.seq));
    return l.take(limit).toList();
  }
}
