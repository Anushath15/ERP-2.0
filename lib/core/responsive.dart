import 'dart:math' as math;
import 'package:flutter/widgets.dart';

enum ScreenSize { phone, tablet, desktop }

/// Breakpoints: under 700 = phone, 700-1099 = tablet, 1100+ = desktop.
ScreenSize screenSizeOf(double width) => width < 700 ? ScreenSize.phone : (width < 1100 ? ScreenSize.tablet : ScreenSize.desktop);

extension ResponsiveContext on BuildContext {
  /// The window width as the TEXT sees it: with bigger text there is less room, so 1280 px at 200% text counts as 640 px
  /// and the app switches to the roomier phone layout (cards, bottom bar) instead of squeezing a table.
  double get effectiveWidth => MediaQuery.sizeOf(this).width / math.max(1.0, MediaQuery.textScalerOf(this).scale(1));
  double get textFactor => math.max(1.0, MediaQuery.textScalerOf(this).scale(1));
  ScreenSize get screen => screenSizeOf(effectiveWidth);
  bool get isPhone => screen == ScreenSize.phone;
  bool get isDesktop => screen == ScreenSize.desktop;
}
