import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Curated accent colours. Every one is checked for 4.5:1 contrast in both themes (and 7:1 in high contrast)
/// by test/design_contrast_test.dart.
enum Accent {
  blue('Blue', Color(0xFF5BADFF), Color(0xFF0A58B0)),
  teal('Teal', Color(0xFF3FD0C2), Color(0xFF0B6B63)),
  green('Green', Color(0xFF66D98F), Color(0xFF17703F)),
  orange('Orange', Color(0xFFFFAA55), Color(0xFF9A4A00)),
  violet('Violet', Color(0xFFBBA2FF), Color(0xFF6A3FC4));

  const Accent(this.label, this.dark, this.light);
  final String label;
  final Color dark, light;
}

enum DensityMode { comfortable, normal, compact }

enum FontChoice { inter, atkinson }

extension FontChoiceInfo on FontChoice {
  String get family => this == FontChoice.inter ? 'Inter' : 'AtkinsonHyperlegibleNext';
  String get label => this == FontChoice.inter ? 'Inter (clean)' : 'Atkinson Hyperlegible (easy to read)';
}

/// Row heights and paddings for the three densities.
@immutable
class AppMetrics extends ThemeExtension<AppMetrics> {
  const AppMetrics(this.mode);
  final DensityMode mode;
  double get factor => switch (mode) { DensityMode.comfortable => 1.2, DensityMode.normal => 1.0, DensityMode.compact => 0.78 };
  double get rowHeight => (44 * factor).roundToDouble();
  double get padV => (9 * factor).roundToDouble();
  double get padH => (14 * factor).roundToDouble();
  double get gap => (12 * factor).roundToDouble();
  double get navTile => (42 * factor).roundToDouble();
  @override
  AppMetrics copyWith({DensityMode? mode}) => AppMetrics(mode ?? this.mode);
  @override
  AppMetrics lerp(ThemeExtension<AppMetrics>? other, double t) => this;
}

/// Design tokens. Every text/background pair is checked for WCAG 4.5:1 (7:1 in high contrast).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.highContrast,
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

  final Brightness brightness;
  final bool highContrast;
  final Color bg, surface, surfaceAlt, border, text, textMuted;
  final Color primary, onPrimary, success, onSuccess, warning, onWarning, danger, onDanger, info;
  final Color badgeBgSuccess, badgeBgWarning, badgeBgDanger, badgeBgInfo, rowSelected;
  final Color paper, onPaper; // print preview "paper" is always white

  /// Builds the colours for a theme, accent and contrast level.
  factory AppColors.build(Brightness b, {Accent accent = Accent.blue, bool highContrast = false}) {
    final dark = b == Brightness.dark;
    final bg = highContrast ? (dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF)) : (dark ? const Color(0xFF0E1318) : const Color(0xFFF2F5F8));
    final surface = highContrast ? (dark ? const Color(0xFF0A0D10) : const Color(0xFFFFFFFF)) : (dark ? const Color(0xFF161D25) : const Color(0xFFFFFFFF));
    final surfaceAlt = highContrast ? (dark ? const Color(0xFF181C20) : const Color(0xFFEDEDED)) : (dark ? const Color(0xFF1E2833) : const Color(0xFFE9EEF3));
    final text = highContrast ? (dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000)) : (dark ? const Color(0xFFEAF0F6) : const Color(0xFF111B26));
    final muted = highContrast ? (dark ? const Color(0xFFE8E8E8) : const Color(0xFF1C1C1C)) : (dark ? const Color(0xFFA8B5C2) : const Color(0xFF45525F));
    final border = highContrast ? (dark ? const Color(0xFFD0D7DE) : const Color(0xFF3A3A3A)) : (dark ? const Color(0xFF708195) : const Color(0xFF6B7A89));
    final target = highContrast ? 7.0 : 4.5;

    var primary = dark ? accent.dark : accent.light;
    if (highContrast) primary = ensureContrast(primary, surfaceAlt, 7.0, towardWhite: dark);
    final onPrimary = _bestOn(primary, dark ? const Color(0xFF031A30) : const Color(0xFFFFFFFF));

    Color tint(Color c, double a, Color base) => Color.alphaBlend(c.withValues(alpha: a), base);
    final okRaw = dark ? const Color(0xFF52D68F) : const Color(0xFF14683A);
    final warnRaw = dark ? const Color(0xFFF5BC45) : const Color(0xFF7A4E00);
    final badRaw = dark ? const Color(0xFFFF8A8A) : const Color(0xFFB3261E);
    final aSurf = dark ? 0.20 : 0.14;
    final bOk = tint(okRaw, aSurf, surface), bWarn = tint(warnRaw, aSurf, surface), bBad = tint(badRaw, aSurf, surface);
    final bInfo = tint(primary, aSurf, surface);
    final selected = tint(primary, highContrast ? 0.08 : (dark ? 0.16 : 0.10), surface);
    final ok = ensureContrast(okRaw, bOk, target, towardWhite: dark);
    final warn = ensureContrast(warnRaw, bWarn, target, towardWhite: dark);
    final bad = ensureContrast(badRaw, bBad, target, towardWhite: dark);
    final info = ensureContrast(primary, bInfo, target, towardWhite: dark);
    final surfaceBtn = dark ? const Color(0xFF031A30) : const Color(0xFFFFFFFF);
    return AppColors(
      brightness: b,
      highContrast: highContrast,
      bg: bg,
      surface: surface,
      surfaceAlt: surfaceAlt,
      border: border,
      text: text,
      textMuted: muted,
      primary: primary,
      onPrimary: onPrimary,
      success: ok,
      onSuccess: _bestOn(ok, surfaceBtn),
      warning: warn,
      onWarning: _bestOn(warn, surfaceBtn),
      danger: bad,
      onDanger: _bestOn(bad, surfaceBtn),
      info: info,
      badgeBgSuccess: bOk,
      badgeBgWarning: bWarn,
      badgeBgDanger: bBad,
      badgeBgInfo: bInfo,
      rowSelected: selected,
      paper: const Color(0xFFFFFFFF),
      onPaper: const Color(0xFF111111),
    );
  }

  static Color _bestOn(Color bg, Color preferred) => contrastRatio(preferred, bg) >= 4.5 ? preferred : (contrastRatio(Colors.black, bg) > contrastRatio(Colors.white, bg) ? Colors.black : Colors.white);

  /// All (foreground, background, label) pairs that must reach the contrast target.
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
        (primary, surfaceAlt, 'primary on surfaceAlt'),
        (success, badgeBgSuccess, 'success badge'),
        (warning, badgeBgWarning, 'warning badge'),
        (danger, badgeBgDanger, 'danger badge'),
        (info, badgeBgInfo, 'info badge'),
        (text, rowSelected, 'text on selected row'),
        (primary, rowSelected, 'primary on selected row'),
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

/// Moves [fg] toward white or black until it reaches [ratio] against [bg] (unchanged if it already does).
Color ensureContrast(Color fg, Color bg, double ratio, {required bool towardWhite}) {
  var c = fg;
  for (var i = 0; i < 40 && contrastRatio(c, bg) < ratio; i++) {
    c = Color.lerp(c, towardWhite ? Colors.white : Colors.black, 0.08)!;
  }
  return c;
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
  AppMetrics get metrics => Theme.of(this).extension<AppMetrics>() ?? const AppMetrics(DensityMode.normal);
}
