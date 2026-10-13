import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/design/tokens.dart';

void main() {
  for (final b in [Brightness.dark, Brightness.light]) {
    for (final accent in Accent.values) {
      for (final high in [false, true]) {
        final name = '${b.name} / ${accent.name} / ${high ? 'high contrast' : 'normal'}';
        test('$name: every text pair reaches ${high ? '7' : '4.5'}:1', () {
          final c = AppColors.build(b, accent: accent, highContrast: high);
          for (final (fg, bg, label) in c.textPairs) {
            expect(contrastRatio(fg, bg), greaterThanOrEqualTo(high ? 7.0 : 4.5), reason: '$name: $label (${contrastRatio(fg, bg).toStringAsFixed(2)})');
          }
        });
        test('$name: borders are visible (3:1) against surfaces', () {
          final c = AppColors.build(b, accent: accent, highContrast: high);
          expect(contrastRatio(c.border, c.surface), greaterThanOrEqualTo(3.0));
          expect(contrastRatio(c.border, c.bg), greaterThanOrEqualTo(3.0));
        });
      }
    }
  }
}
