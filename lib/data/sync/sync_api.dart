/// One document as it travels to and from the cloud copy: a collection name (the table name), the id, the row as JSON, its version stamp.
class SyncDoc {
  const SyncDoc({required this.coll, required this.id, required this.data, required this.hlc, this.deleted = false});
  final String coll, id, hlc;
  final Map<String, Object?> data;
  final bool deleted;

  Map<String, Object?> toJson() => {'coll': coll, 'id': id, 'data': data, 'hlc': hlc, 'deleted': deleted};
}

/// A document pulled from the cloud, with its place in the cloud's order ([seq]) and the computer that sent it.
class PulledDoc extends SyncDoc {
  const PulledDoc({required this.seq, required this.deviceId, required super.coll, required super.id, required super.data, required super.hlc, super.deleted});
  final int seq;
  final String deviceId;
}

/// The two calls the sync needs from the cloud (Supabase `push_docs` / `pull_docs`); tests use an in-memory one.
abstract class SyncApi {
  /// Sends up to 100 documents in one all-or-nothing call.
  Future<void> push(List<SyncDoc> docs);

  /// False for a destination that only receives (another counter on the shop Wi-Fi): nothing is pulled from it.
  bool get canPull => true;

  /// Documents with a position after [after], oldest first, at most [limit].
  Future<List<PulledDoc>> pull(int after, int limit);
}

/// No internet, or the cloud did not answer: try again later; nothing is lost.
class SyncOffline implements Exception {
  const SyncOffline([this.message = '']);
  final String message;
  @override
  String toString() => 'SyncOffline($message)';
}

/// The sign-in is no longer accepted (expired, or the person was removed from the shop).
class SyncAuthFailed implements Exception {
  const SyncAuthFailed([this.message = '']);
  final String message;
  @override
  String toString() => 'SyncAuthFailed($message)';
}

/// The cloud refused these documents for good (not a connection problem).
class SyncRejected implements Exception {
  const SyncRejected(this.message);
  final String message;
  @override
  String toString() => 'SyncRejected($message)';
}
