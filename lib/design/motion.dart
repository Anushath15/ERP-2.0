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

/// Page transition used by every route: a soft fade with a short slide (120-200 ms), or an instant switch when Off.
Page<void> motionPage(BuildContext context, LocalKey? key, Widget child) {
  final m = context.motion;
  if (!m.transitions) return NoTransitionPage<void>(key: key, child: child);
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    transitionsBuilder: (ctx, anim, secondary, c) {
      final curved = CurvedAnimation(parent: anim, curve: Motion.out, reverseCurve: Curves.easeIn);
      return FadeTransition(opacity: curved, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.015, 0), end: Offset.zero).animate(curved), child: c));
    },
  );
}
