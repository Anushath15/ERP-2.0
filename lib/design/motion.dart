import 'package:flutter/material.dart';
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
