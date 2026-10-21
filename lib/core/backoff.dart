import 'dart:math';

/// How long to wait before the next try after something failed: the normal wait while all is well, then twice as long after each failure
/// (20 s, 40 s, 80 s ... up to [max]), a little randomised so two computers do not knock at the same moment, and back to normal after one success.
/// Used for the cloud sync and the counter link, so a dead internet line is asked less and less often instead of every few seconds all day.
class Backoff {
  Backoff({this.base = const Duration(seconds: 20), this.max = const Duration(minutes: 10), Random? random}) : _random = random ?? Random();

  final Duration base, max;
  final Random _random;
  int failures = 0;

  void success() => failures = 0;
  void failure() {
    if (failures < 30) failures++;
  }

  /// The wait before the next try: [base] while there were no failures, then doubling, never above [max]; +/- 20 percent after a failure.
  Duration get delay {
    if (failures == 0) return base;
    final ms = min(max.inMilliseconds.toDouble(), base.inMilliseconds * pow(2, failures));
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    return Duration(milliseconds: (ms * jitter).round().clamp(base.inMilliseconds, max.inMilliseconds));
  }
}
