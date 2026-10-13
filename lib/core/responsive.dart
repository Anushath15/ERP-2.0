import 'package:flutter/widgets.dart';

enum ScreenSize { phone, tablet, desktop }

/// Breakpoints: under 700 = phone, 700-1099 = tablet, 1100+ = desktop.
ScreenSize screenSizeOf(double width) =>
    width < 700 ? ScreenSize.phone : (width < 1100 ? ScreenSize.tablet : ScreenSize.desktop);

extension ResponsiveContext on BuildContext {
  ScreenSize get screen => screenSizeOf(MediaQuery.sizeOf(this).width);
  bool get isPhone => screen == ScreenSize.phone;
  bool get isDesktop => screen == ScreenSize.desktop;
}
