import 'package:flutter/material.dart';

/// Text-size steps used by the slider, the A-/A+ buttons and Ctrl+Plus / Ctrl+Minus.
class TextZoom {
  static const min = 0.8, max = 2.0, step = 0.05;

  /// The named presets, from small to huge.
  static const presets = <(String, double)>[('Small', 0.9), ('Normal', 1.0), ('Large', 1.25), ('Extra large', 1.5), ('Huge', 2.0)];

  static const _stops = [0.8, 0.9, 1.0, 1.1, 1.25, 1.4, 1.5, 1.75, 2.0];

  static double up(double v) => _stops.firstWhere((s) => s > v + 0.001, orElse: () => max);
  static double down(double v) => _stops.lastWhere((s) => s < v - 0.001, orElse: () => min);

  static String label(double v) => '${(v * 100).round()}%';
}

/// Multiplies the text size for everything below it (used for the billing tables, which have their own size setting).
class TextScaleBy extends StatelessWidget {
  const TextScaleBy({super.key, required this.factor, required this.child});
  final double factor;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (factor == 1.0) return child;
    final mq = MediaQuery.of(context);
    return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * factor)), child: child);
  }
}
