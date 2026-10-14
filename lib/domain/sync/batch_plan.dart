/// How the app groups documents into commits (Phase 2 uploader uses this). The Firestore rules count COMMITS per person
/// per day, not documents, and cannot see how many documents a commit holds, so the program keeps commits few and
/// bounded. A modified program is not bound by this; see docs/threat-model.md (finding 9).
const maxDocsPerBatch = 100;

/// Longest a pending change waits before it is sent even if fewer than [maxDocsPerBatch] are waiting.
const flushAfter = Duration(minutes: 90);

/// Cuts [items] into commits of at most [maxDocsPerBatch], keeping the order.
List<List<T>> splitBatches<T>(List<T> items) => [for (var i = 0; i < items.length; i += maxDocsPerBatch) items.sublist(i, i + maxDocsPerBatch > items.length ? items.length : i + maxDocsPerBatch)];

/// Whether to send now: when a full batch is waiting, when the oldest change has waited [flushAfter], or when the person forces
/// it (Copy now, app closing, internet back). Never when nothing is waiting.
bool shouldFlush({required int pending, required DateTime? oldestWaiting, required DateTime now, bool force = false}) {
  if (pending <= 0) return false;
  if (force || pending >= maxDocsPerBatch) return true;
  return oldestWaiting != null && now.difference(oldestWaiting) >= flushAfter;
}

/// Commits needed in a working day with [documents] changed documents spread over [hours]: either full batches or one every
/// [flushAfter], whichever is more, plus a few forced ones (close, internet back).
int dailyBatches({required int documents, required int hours, int forced = 4}) {
  final bySize = (documents / maxDocsPerBatch).ceil();
  final byTime = (hours * 60 / flushAfter.inMinutes).ceil();
  return (bySize > byTime ? bySize : byTime) + forced;
}
