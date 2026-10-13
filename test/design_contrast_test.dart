import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/design/tokens.dart';

void main() {
  for (final entry in {'dark': AppColors.dark, 'light': AppColors.light}.entries) {
    test('${entry.key} theme: every text pair reaches WCAG 4.5:1', () {
      for (final (fg, bg, label) in entry.value.textPairs) {
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5), reason: '${entry.key}: $label');
      }
    });
  }
  test('borders are visible (3:1) against surfaces', () {
    for (final c in [AppColors.dark, AppColors.light]) {
      expect(contrastRatio(c.border, c.surface), greaterThanOrEqualTo(3.0));
    }
  });
}
