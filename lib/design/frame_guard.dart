import 'motion_level.dart';

/// Watches how long frames take. If the app stays under 45 frames per second for several seconds while something is
/// animating, it asks to drop one motion level (Full -> Gentle -> Off) for this device. An idle app produces no frames,
/// so it can never trigger by itself.
class FrameGuard {
  FrameGuard({required this.onReduce, this.budgetMs = 1000 / 45, this.windowMs = 3000, this.minFrames = 40, this.cooldownMs = 8000});
  final void Function() onReduce;
  final double budgetMs;
  final int windowMs, minFrames, cooldownMs;
  final List<(int, double)> _frames = []; // (time ms, frame ms)
  int _cooldownUntil = 0;

  /// Feed one frame. [nowMs] is a monotonic clock in ms, [frameMs] the frame's total build + raster time.
  void onFrame(int nowMs, double frameMs) {
    _frames.add((nowMs, frameMs));
    _frames.removeWhere((f) => f.$1 < nowMs - windowMs);
    if (nowMs < _cooldownUntil || _frames.length < minFrames) return;
    // The whole window must be slow: first sample at least ~windowMs old, and the average over it above budget.
    if (nowMs - _frames.first.$1 < windowMs * 0.9) return;
    final avg = _frames.fold<double>(0, (s, f) => s + f.$2) / _frames.length;
    if (avg > budgetMs) {
      _frames.clear();
      _cooldownUntil = nowMs + cooldownMs;
      onReduce();
    }
  }

  /// The next level down, or null when already Off.
  static MotionLevel? lower(MotionLevel l) => switch (l) { MotionLevel.full => MotionLevel.gentle, MotionLevel.gentle => MotionLevel.off, MotionLevel.off => null };
}
