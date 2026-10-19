import '../context.dart';

/// The upload queue as the Health page sees it.
class OutboxRepo {
  OutboxRepo(this.cx);
  final DataContext cx;

  Future<({int pending, int attention})> counts() async => (
        pending: await cx.db.scalarInt("SELECT COUNT(*) FROM outbox WHERE chan = 'cloud' AND state = 'pending'"),
        attention: await cx.db.scalarInt("SELECT COUNT(*) FROM outbox WHERE chan = 'cloud' AND state = 'attention'"),
      );
}
