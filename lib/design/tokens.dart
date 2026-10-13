import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Design tokens. Every text/background pair is checked for WCAG 4.5:1 by test/design_contrast_test.dart.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
    required this.info,
    required this.badgeBgSuccess,
    required this.badgeBgWarning,
    required this.badgeBgDanger,
    required this.badgeBgInfo,
    required this.rowSelected,
    required this.paper,
    required this.onPaper,
  });

  final Color bg, surface, surfaceAlt, border, text, textMuted;
  final Color primary, onPrimary, success, onSuccess, warning, onWarning, danger, onDanger, info;
  final Color badgeBgSuccess, badgeBgWarning, badgeBgDanger, badgeBgInfo, rowSelected;
  final Color paper, onPaper; // print preview "paper" is always white

  static const dark = AppColors(
    bg: Color(0xFF0E1318),
    surface: Color(0xFF161D25),
    surfaceAlt: Color(0xFF1E2833),
    border: Color(0xFF708195),
    text: Color(0xFFEAF0F6),
    textMuted: Color(0xFFA8B5C2),
    primary: Color(0xFF5BADFF),
    onPrimary: Color(0xFF031A30),
    success: Color(0xFF52D68F),
    onSuccess: Color(0xFF03210F),
    warning: Color(0xFFF5BC45),
    onWarning: Color(0xFF2A1B00),
    danger: Color(0xFFFF8A8A),
    onDanger: Color(0xFF3A0505),
    info: Color(0xFF8CC4FF),
    badgeBgSuccess: Color(0xFF12361F),
    badgeBgWarning: Color(0xFF3B2E0B),
    badgeBgDanger: Color(0xFF4A1818),
    badgeBgInfo: Color(0xFF14304A),
    rowSelected: Color(0xFF1B3550),
    paper: Color(0xFFFFFFFF),
    onPaper: Color(0xFF111111),
  );

  static const light = AppColors(
    bg: Color(0xFFF2F5F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE9EEF3),
    border: Color(0xFF8795A3),
    text: Color(0xFF111B26),
    textMuted: Color(0xFF45525F),
    primary: Color(0xFF0A58B0),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF14683A),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFF7A4E00),
    onWarning: Color(0xFFFFFFFF),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    info: Color(0xFF0A58B0),
    badgeBgSuccess: Color(0xFFD9F2E3),
    badgeBgWarning: Color(0xFFFCEBC2),
    badgeBgDanger: Color(0xFFFBDADA),
    badgeBgInfo: Color(0xFFDCEAFB),
    rowSelected: Color(0xFFD8E8FA),
    paper: Color(0xFFFFFFFF),
    onPaper: Color(0xFF111111),
  );

  /// All (foreground, background, label) pairs that must reach 4.5:1.
  List<(Color, Color, String)> get textPairs => [
        (text, bg, 'text on bg'),
        (text, surface, 'text on surface'),
        (text, surfaceAlt, 'text on surfaceAlt'),
        (textMuted, bg, 'muted on bg'),
        (textMuted, surface, 'muted on surface'),
        (textMuted, surfaceAlt, 'muted on surfaceAlt'),
        (onPrimary, primary, 'onPrimary on primary'),
        (onSuccess, success, 'onSuccess on success'),
        (onWarning, warning, 'onWarning on warning'),
        (onDanger, danger, 'onDanger on danger'),
        (primary, surface, 'primary on surface'),
        (primary, bg, 'primary on bg'),
        (success, badgeBgSuccess, 'success badge'),
        (warning, badgeBgWarning, 'warning badge'),
        (danger, badgeBgDanger, 'danger badge'),
        (info, badgeBgInfo, 'info badge'),
        (text, rowSelected, 'text on selected row'),
        (onPaper, paper, 'paper text'),
      ];

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => this;
}

/// WCAG contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final la = lum(a), lb = lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Spacing, radius, sizes.
class Gap {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32;
}

class Radii {
  static const double s = 6, m = 10, l = 14;
}

class Sizes {
  static const double touch = 48; // minimum touch target
  static const double rowHeight = 44;
  static const double navRailWidth = 232;
  static const double navRailCollapsed = 72;
}

extension AppColorsContext on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}
