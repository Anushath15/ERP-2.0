import 'package:flutter/widgets.dart';

/// Ties a percent box to a price box and the MRP box: typing the percent makes the price (MRP 100 and 50 gives 50), typing the price gives the percent back,
/// and changing the MRP keeps the percent and moves the price (or, with no percent yet, works the percent out). [onChanged] runs after the program (not
/// the person) changed a box. Only a real change of the text counts: a tap into a box also notifies, and must not rewrite anything.
void linkPercent({required TextEditingController base, required TextEditingController pct, required TextEditingController target, VoidCallback? onChanged}) {
  var busy = false;
  String pctOf(double t, double b) => (t / b * 100).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  void fillTarget() {
    final b = double.tryParse(base.text), p = double.tryParse(pct.text);
    if (b == null || p == null) return;
    busy = true;
    target.text = (b * p / 100).toStringAsFixed(2);
    busy = false;
    onChanged?.call();
  }

  void fillPercent() {
    final b = double.tryParse(base.text), t = double.tryParse(target.text);
    if (b == null || b <= 0 || t == null) return;
    busy = true;
    pct.text = pctOf(t, b);
    busy = false;
  }

  void watch(TextEditingController c, void Function() act) {
    var seen = c.text;
    c.addListener(() {
      if (busy || seen == c.text) return;
      seen = c.text;
      act();
    });
  }

  watch(pct, fillTarget);
  watch(target, fillPercent);
  watch(base, () => pct.text.isNotEmpty ? fillTarget() : fillPercent());
  if (pct.text.isEmpty && base.text.isNotEmpty && target.text.isNotEmpty) fillPercent();
}
