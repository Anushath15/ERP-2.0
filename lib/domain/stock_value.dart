/// "What is my stock worth?" in ONE place. The Inventory screen, the Health screen, exports and the ERP 1 import report all call [StockValuation.compute]
/// with the same lines, so the numbers cannot disagree.
///
/// Rules the shop can choose between (setting `valuation.rule`):
///  - average: the average buying cost where it is known, else the latest buying price  (recommended until the shop chooses)
///  - buying: the latest buying price
///  - selling: the selling price
///
/// What is counted and what is shown apart:
///  - Counted: products that are not deleted, with stock above zero and a known cost. Active ones form the main line, inactive ones a separate line
///    that is INCLUDED in the total.
///  - "Cost not set": stock above zero but no buying price and no average cost. Shown on its own line with quantity only. Never valued at the selling price,
///    never as 0 inside a total; it is NOT in the total, and the screen says so.
///  - Negative stock counts as 0 and is listed as an error to fix.
library;

enum ValuationRule { average, buying, selling }

/// The rule used when the shop has not chosen yet.
const ValuationRule recommendedRule = ValuationRule.average;

ValuationRule? ruleFromSetting(String? v) {
  for (final r in ValuationRule.values) {
    if (r.name == v) return r;
  }
  return null;
}

class StockLine {
  const StockLine({required this.id, required this.name, required this.active, required this.stockMilli, required this.sellPaise, required this.buyPaise, required this.avgPaise});
  final String id, name;
  final bool active;
  final int stockMilli, sellPaise, buyPaise, avgPaise;

  /// The unit cost under the cost-based rules, or null when no cost is known.
  int? unitValue(ValuationRule rule) {
    switch (rule) {
      case ValuationRule.selling:
        return sellPaise;
      case ValuationRule.buying:
        return buyPaise > 0 ? buyPaise : null;
      case ValuationRule.average:
        return avgPaise > 0 ? avgPaise : (buyPaise > 0 ? buyPaise : null);
    }
  }

  bool get costKnown => avgPaise > 0 || buyPaise > 0;
}

class NegativeStock {
  const NegativeStock(this.id, this.name, this.stockMilli);
  final String id, name;
  final int stockMilli;
}

class StockValuation {
  StockValuation._(this.activeValue, this.inactiveValue, this.activeProducts, this.inactiveProducts, this.activeQtyMilli, this.inactiveQtyMilli, this.unpricedProducts, this.unpricedQtyMilli, this.negatives, this.chosen);

  /// Value per rule of the active, costed products with stock above zero.
  final Map<ValuationRule, int> activeValue;

  /// Value per rule of the inactive, costed products with stock above zero (a separate line, included in [total]).
  final Map<ValuationRule, int> inactiveValue;
  final int activeProducts, inactiveProducts, activeQtyMilli, inactiveQtyMilli;

  /// Stock above zero with no cost known: quantity only, not in any total.
  final int unpricedProducts, unpricedQtyMilli;

  /// Products with stock below zero: counted as 0 and listed so they can be fixed.
  final List<NegativeStock> negatives;

  /// The rule the shop chose, or null if it has not chosen yet.
  final ValuationRule? chosen;

  /// The rule whose number is shown as THE stock value: the chosen one, else the recommended one.
  ValuationRule get shown => chosen ?? recommendedRule;
  bool get isChosen => chosen != null;

  int total(ValuationRule rule) => activeValue[rule]! + inactiveValue[rule]!;
  int get shownTotal => total(shown);

  static StockValuation compute(Iterable<StockLine> lines, {ValuationRule? chosen}) {
    final active = {for (final r in ValuationRule.values) r: 0};
    final inactive = {for (final r in ValuationRule.values) r: 0};
    var ap = 0, ip = 0, aq = 0, iq = 0, up = 0, uq = 0;
    final neg = <NegativeStock>[];
    for (final l in lines) {
      if (l.stockMilli < 0) {
        neg.add(NegativeStock(l.id, l.name, l.stockMilli));
        continue;
      }
      if (l.stockMilli == 0) continue;
      if (!l.costKnown) {
        up++;
        uq += l.stockMilli;
        continue;
      }
      final target = l.active ? active : inactive;
      for (final r in ValuationRule.values) {
        // a product with a buying price but no average, or the reverse, still has a value under every cost rule: a rule that has no number for it falls back
        // to the cost it does have, so the three totals always cover the same products
        final unit = l.unitValue(r) ?? (l.avgPaise > 0 ? l.avgPaise : l.buyPaise);
        target[r] = target[r]! + _value(unit, l.stockMilli);
      }
      if (l.active) {
        ap++;
        aq += l.stockMilli;
      } else {
        ip++;
        iq += l.stockMilli;
      }
    }
    return StockValuation._(active, inactive, ap, ip, aq, iq, up, uq, neg, chosen);
  }

  static int _value(int unitPaise, int qtyMilli) => (unitPaise * qtyMilli / 1000).round();
}
