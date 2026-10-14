import 'dart:async';

/// All database writes the screens start go through one queue, in the order they were made. A screen can fire a write and carry on
/// (small edits), or await its result (a bill, a payment: nothing is shown as done until the database says so).
class WriteQueue {
  WriteQueue({this.onError});

  /// Called when a fire-and-forget write fails, so the screen can say so plainly (disk full, file locked...).
  void Function(Object error, StackTrace stack)? onError;

  Future<void> _tail = Future.value();
  int pending = 0;

  /// Runs [job] after everything queued before it and returns its result (or rethrows its error to the caller).
  Future<T> run<T>(Future<T> Function() job) {
    final done = Completer<T>();
    pending++;
    _tail = _tail.then((_) async {
      try {
        done.complete(await job());
      } catch (e, s) {
        done.completeError(e, s);
      } finally {
        pending--;
      }
    });
    return done.future;
  }

  /// Queues [job] and does not wait; a failure goes to [onError].
  void add(Future<void> Function() job) {
    unawaited(run(job).catchError((Object e, StackTrace s) {
      onError?.call(e, s);
    }));
  }

  /// Completes when everything queued so far is on disk (before a backup, a restore, closing the program).
  Future<void> flush() => run(() async {});
}
