import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/domain/sync/batch_plan.dart';

// SECURITY / QUOTA: the app itself never sends more than maxDocsPerBatch documents in one commit and does not send many tiny
// commits either (the rules count commits per person per day). The rules cannot enforce the size: a modified program could send more.
void main() {
  test('the limits are the documented ones', () {
    expect(maxDocsPerBatch, 100);
    expect(flushAfter, const Duration(minutes: 90));
  });

  test('a list is cut into batches of at most 100, in order, nothing lost or repeated', () {
    for (final n in [0, 1, 99, 100, 101, 250, 1000]) {
      final items = List.generate(n, (i) => i);
      final b = splitBatches(items);
      expect(b.every((x) => x.isNotEmpty && x.length <= maxDocsPerBatch), isTrue, reason: 'n=$n');
      expect([for (final x in b) ...x], items, reason: 'n=$n');
      expect(b.length, (n / maxDocsPerBatch).ceil(), reason: 'n=$n');
    }
  });

  test('it sends when 100 are waiting, or when the oldest has waited 90 minutes, or when the owner forces it; never when nothing waits', () {
    final t = DateTime(2026, 10, 14, 12);
    bool go(int pending, Duration age, {bool force = false}) => shouldFlush(pending: pending, oldestWaiting: pending == 0 ? null : t.subtract(age), now: t, force: force);
    expect(go(0, Duration.zero, force: true), isFalse);
    expect(go(5, const Duration(minutes: 10)), isFalse, reason: 'few and fresh: wait, so batches stay few');
    expect(go(100, Duration.zero), isTrue);
    expect(go(5, const Duration(minutes: 90)), isTrue);
    expect(go(5, const Duration(minutes: 89)), isFalse);
    expect(go(5, Duration.zero, force: true), isTrue, reason: 'Copy now, app closing, network back');
  });

  test('a normal busy day stays far under the daily batch cap, and the worst a modified program could do is known', () {
    // 550 bills a day at the 1,000,000-bill scale is about 1,100 documents with payments, reminders and edits
    expect(dailyBatches(documents: 1100, hours: 12), lessThanOrEqualTo(16), reason: 'cashier cap');
    expect(dailyBatches(documents: 2000, hours: 12), lessThanOrEqualTo(24), reason: 'worst legitimate day, owner and manager cap');
  });
}
