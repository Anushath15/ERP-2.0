import 'dart:math';
import 'package:erp2/core/backoff.dart';
import 'package:erp2/core/cloud/sync_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'data/fake_cloud.dart';
import 'data/helpers.dart';

// What these tests prove: after each failure the wait doubles (never above the limit, never below the normal wait), one success puts it back,
// and the cloud sync really waits longer while the internet is down and returns to the normal rhythm when it is back.
void main() {
  group('the wait', () {
    test('normal while all is well, then doubling with the limit; a success starts over', () {
      final b = Backoff(random: Random(1));
      expect(b.delay, const Duration(seconds: 20));
      final waits = <int>[];
      for (var i = 0; i < 12; i++) {
        b.failure();
        waits.add(b.delay.inSeconds);
      }
      // each wait is within 20 percent of 20 s x 2^n, capped at 10 minutes
      for (var i = 0; i < waits.length; i++) {
        final ideal = min(600.0, 20.0 * pow(2, i + 1));
        expect(waits[i], inInclusiveRange((ideal * 0.8).floor().clamp(20, 600), (ideal * 1.2).ceil().clamp(20, 600)), reason: 'failure ${i + 1}');
      }
      expect(waits.last, lessThanOrEqualTo(600));
      expect(waits.last, greaterThanOrEqualTo(480), reason: 'at the limit');
      b.success();
      expect(b.delay, const Duration(seconds: 20));
    });

    test('never below the normal wait and never above the limit, whatever the random numbers are', () {
      for (var seed = 0; seed < 50; seed++) {
        final b = Backoff(base: const Duration(seconds: 5), max: const Duration(minutes: 2), random: Random(seed));
        for (var i = 0; i < 40; i++) {
          b.failure();
          expect(b.delay, greaterThanOrEqualTo(const Duration(seconds: 5)));
          expect(b.delay, lessThanOrEqualTo(const Duration(minutes: 2)));
        }
      }
    });
  });

  test('the cloud sync waits longer after each failure, tells when it will try again, and goes back to normal after one success', () async {
    final cloud = FakeCloud();
    final shop = memoryShop(device: 'dev-bo');
    final c = ProviderContainer();
    addTearDown(() async {
      c.dispose();
      await shop.close();
    });
    final ctl = c.read(syncProvider.notifier);
    ctl.startWith(shop, cloud.client('dev-bo'), timer: false);
    cloud.offline = true;
    await ctl.syncNow();
    await ctl.syncNow();
    await ctl.syncNow();
    expect(ctl.backoff.failures, 3);
    expect(c.read(syncProvider).phase, SyncPhase.offline);
    cloud.offline = false;
    await ctl.syncNow();
    expect(ctl.backoff.failures, 0);
    expect(c.read(syncProvider).phase, SyncPhase.idle);
    ctl.stop();
  });
}
