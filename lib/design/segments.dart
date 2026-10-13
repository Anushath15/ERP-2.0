import 'package:flutter/material.dart';
import 'motion.dart';
import 'tokens.dart';

/// A segmented control with a sliding selection indicator. Labels shrink to fit instead of overflowing, so it still works at
/// 200% text size and on narrow phones. One tap target per segment (48 px high at least).
class SlideSegments<T> extends StatelessWidget {
  const SlideSegments({super.key, required this.options, required this.selected, required this.onChanged, this.height = 48});
  final List<(T, String, IconData?)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final n = options.length;
    final idx = options.indexWhere((o) => o.$1 == selected).clamp(0, n - 1);
    final th = Theme.of(context).textTheme;
    final dur = context.motion.t(180);
    return Container(
      height: height,
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: c.border)),
      padding: const EdgeInsets.all(3),
      child: Stack(children: [
        AnimatedAlign(
          duration: dur,
          curve: Motion.out,
          alignment: Alignment(n == 1 ? 0 : -1 + 2 * idx / (n - 1), 0),
          child: FractionallySizedBox(
            widthFactor: 1 / n,
            heightFactor: 1,
            child: DecoratedBox(decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(Radii.m - 3))),
          ),
        ),
        Row(children: [
          for (final o in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: o.$1 == selected,
                label: o.$2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.m - 3),
                  onTap: () => onChanged(o.$1),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (o.$3 != null) ...[Icon(o.$3, size: 18, color: o.$1 == selected ? c.onPrimary : c.text), const SizedBox(width: 6)],
                          Text(o.$2, style: th.labelLarge?.copyWith(color: o.$1 == selected ? c.onPrimary : c.text)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}
