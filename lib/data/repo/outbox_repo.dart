import '../context.dart';

/// The upload queue as the Health page sees it.
class OutboxRepo {
  OutboxRepo(this.cx);
  final DataContext cx;

  /// Documents the cloud refused for good: which kind, which one, and why (the words the cloud gave).
  Future<List<({String coll, String docId, String error, int attempts})>> refused({int limit = 50}) async => [
        for (final r in await cx.db.rows("SELECT coll, doc_id, last_error, attempts FROM outbox WHERE chan = 'cloud' AND state = 'attention' ORDER BY seq LIMIT ?", [limit]))
          (coll: r.read<String>('coll'), docId: r.read<String>('doc_id'), error: r.readNullable<String>('last_error') ?? '', attempts: r.read<int>('attempts')),
      ];

  /// Puts every refused document back in the queue (after the cause was dealt with, for example a person's role changed). Returns how many.
  Future<int> retryRefused() async {
    await cx.db.exec("UPDATE outbox SET state = 'pending', attempts = 0, last_error = NULL WHERE chan = 'cloud' AND state = 'attention'");
    return cx.db.scalarInt('SELECT changes()');
  }

  /// How many documents were sent to the cloud today.
  Future<int> sentToday() async {
    final day = DateTime.fromMillisecondsSinceEpoch(cx.nowMs()).toIso8601String().substring(0, 10);
    final r = await cx.db.row('SELECT value FROM sync_meta WHERE name = ?', ['sent.$day']);
    return int.tryParse(r?.read<String>('value') ?? '') ?? 0;
  }

  Future<({int pending, int attention})> counts() async => (
        pending: await cx.db.scalarInt("SELECT COUNT(*) FROM outbox WHERE chan = 'cloud' AND state = 'pending'"),
        attention: await cx.db.scalarInt("SELECT COUNT(*) FROM outbox WHERE chan = 'cloud' AND state = 'attention'"),
      );
}
