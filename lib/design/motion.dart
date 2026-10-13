import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'motion_level.dart';

/// The motion rules for this device. Animations never delay work: they only play after an action has already happened.
///  * Full   : everything (billing flashes, number tweens, hover lift, success check, skeletons, empty-state fade)
///  * Gentle : page/dialog/tab transitions and press/hover/focus effects only
///  * Off    : nothing moves (also chosen automatically by the operating system's reduce-motion setting)
@immutable
class Motion {
  const Motion(this.level);
  final MotionLevel level;

  /// Transitions and press effects (Gentle and Full).
  bool get transitions => level != MotionLevel.off;

  /// Extra effects (Full only).
  bool get effects => level == MotionLevel.full;

  /// A transition-class duration (zero when Off).
  Duration t(int ms) => transitions ? Duration(milliseconds: ms) : Duration.zero;

  /// An effect-class duration (zero unless Full).
  Duration fx(int ms) => effects ? Duration(milliseconds: ms) : Duration.zero;

  static const Curve out = Curves.easeOutCubic;
  static const Curve inOut = Curves.easeInOutCubic;

  /// The level that really applies: the chosen level, forced to Off when the system asks for reduced motion.
  static MotionLevel resolve({required MotionLevel chosen, required bool followSystem, required bool systemReduces}) => followSystem && systemReduces ? MotionLevel.off : chosen;
}

class MotionScope extends InheritedWidget {
  const MotionScope({super.key, required this.motion, required super.child});
  final Motion motion;

  static Motion of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<MotionScope>()?.motion ?? const Motion(MotionLevel.gentle);

  @override
  bool updateShouldNotify(MotionScope old) => old.motion.level != motion.level;
}

extension MotionContext on BuildContext {
  Motion get motion => MotionScope.of(this);
}

/// Animation style for dialogs and bottom sheets: a short scale/slide in, or none when motion is Off.
AnimationStyle dialogStyle(BuildContext context) {
  final m = context.motion;
  if (!m.transitions) return AnimationStyle.noAnimation;
  return const AnimationStyle(duration: Duration(milliseconds: 170), reverseDuration: Duration(milliseconds: 120), curve: Motion.out, reverseCurve: Curves.easeIn);
}

/// Page change used by every route. The page is swapped at once (NoTransitionPage), so the old page is never in the picture
/// together with the new one: a Navigator transition keeps the old page underneath while the new one fades in, which looked like
/// a slide show. The new page may fade in a little (from 55% to 100% in 100 ms, so its content is visible in the very first frame);
/// when motion is Off nothing animates.
Page<void> motionPage(BuildContext context, LocalKey? key, Widget child) {
  return NoTransitionPage<void>(key: key, child: _PageFadeIn(child: child));
}

class _PageFadeIn extends StatefulWidget {
  const _PageFadeIn({required this.child});
  final Widget child;
  @override
  State<_PageFadeIn> createState() => _PageFadeInState();
}

class _PageFadeInState extends State<_PageFadeIn> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final m = context.motion;
    if (!m.transitions) return;
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 100))..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    return FadeTransition(opacity: Tween<double>(begin: 0.55, end: 1).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)), child: widget.child);
  }
}
