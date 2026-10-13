import 'package:flutter/material.dart';
import 'tokens.dart';


ThemeData buildTheme(
  Brightness b, {
  Accent accent = Accent.blue,
  bool highContrast = false,
  FontChoice font = FontChoice.inter,
  DensityMode density = DensityMode.normal,
  bool ripple = true,
}) {
  final c = AppColors.build(b, accent: accent, highContrast: highContrast);
  final latin = font.family;
  final scheme = ColorScheme(
    brightness: b,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.primary,
    onSecondary: c.onPrimary,
    error: c.danger,
    onError: c.onDanger,
    surface: c.surface,
    onSurface: c.text,
    surfaceContainerHighest: c.surfaceAlt,
    outline: c.border,
    outlineVariant: c.border,
  );
  TextStyle t(double size, FontWeight w, {Color? color}) => TextStyle(
        fontFamily: latin,
        fontSize: size,
        fontWeight: w,
        color: color ?? c.text,
        height: 1.35,
      );
  final text = TextTheme(
    displaySmall: t(28, FontWeight.w700),
    headlineMedium: t(24, FontWeight.w700),
    headlineSmall: t(20, FontWeight.w700),
    titleLarge: t(18, FontWeight.w700),
    titleMedium: t(16, FontWeight.w700),
    titleSmall: t(14, FontWeight.w700),
    bodyLarge: t(16, FontWeight.w400),
    bodyMedium: t(14, FontWeight.w400),
    bodySmall: t(12, FontWeight.w400, color: c.textMuted),
    labelLarge: t(15, FontWeight.w700),
    labelMedium: t(13, FontWeight.w600),
    labelSmall: t(12, FontWeight.w600, color: c.textMuted),
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.m),
    borderSide: BorderSide(color: c.border),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.surface,
    fontFamily: latin,
    textTheme: text,
    primaryTextTheme: text,
    extensions: [c, AppMetrics(density)],
    dividerColor: c.border,
    dividerTheme: DividerThemeData(color: c.border.withValues(alpha: 0.6), space: 1, thickness: 1),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        side: BorderSide(color: c.border.withValues(alpha: 0.7)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: c.primary, width: 2)),
      errorBorder: border.copyWith(borderSide: BorderSide(color: c.danger)),
      labelStyle: TextStyle(color: c.textMuted),
      hintStyle: TextStyle(color: c.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      isDense: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        minimumSize: const Size(64, Sizes.touch),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.m)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        minimumSize: const Size(64, Sizes.touch),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: BorderSide(color: c.border),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.m)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        minimumSize: const Size(48, Sizes.touch),
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceAlt,
      selectedColor: c.rowSelected,
      side: BorderSide(color: c.border),
      labelStyle: text.labelMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.l)),
      titleTextStyle: text.titleLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      modalBackgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.l))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surfaceAlt,
      contentTextStyle: text.bodyMedium,
      behavior: SnackBarBehavior.floating,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.rowSelected,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(textStyle: text.bodyLarge),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(6), border: Border.all(color: c.border)),
      textStyle: text.bodyMedium,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onPrimary : c.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceAlt),
    ),
    visualDensity: switch (density) { DensityMode.comfortable => VisualDensity.comfortable, DensityMode.normal => VisualDensity.standard, DensityMode.compact => VisualDensity.compact },
    splashFactory: ripple ? InkRipple.splashFactory : NoSplash.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _NoTransition(),
      TargetPlatform.windows: _NoTransition(),
      TargetPlatform.macOS: _NoTransition(),
      TargetPlatform.linux: _NoTransition(),
      TargetPlatform.iOS: _NoTransition(),
    }),
  );
}

class _NoTransition extends PageTransitionsBuilder {
  const _NoTransition();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      child;
}
