/// Keeping the shop's margin when the buying price moves. Pure Dart, integer paise.
///
/// The selling price was set against the old buying price, so it carries a margin (selling / buying). When a purchase brings a new
/// buying price, the selling price moves by the same ratio: dearer stock raises it, cheaper stock lowers it, and the margin stays
/// the same. (If the shop later types its own selling price in the product page, that price and the current buying price are the new
/// base for the next purchase.)
library;

import '../core/money.dart';

/// The selling price after the buying price went from [oldCost] to [newCost], keeping the margin of [oldSell]. Both costs are in the
/// same form (without GST); the selling price is whatever form the shop keeps (the ratio is the same either way).
/// Unchanged when there is nothing to base it on: no old buying price, no selling price, or the buying price did not change.
/// Rounded to the nearest 50 paise (to the paisa under Rs. 10) so the price stays a price a person would say.
int sellingPriceKeepingMargin({required int oldCost, required int newCost, required int oldSell}) {
  if (oldCost <= 0 || newCost <= 0 || oldSell <= 0 || oldCost == newCost) return oldSell;
  final raw = divRound(oldSell * newCost, oldCost);
  if (raw < 1000) return raw < 1 ? 1 : raw;
  return divRound(raw, 50) * 50;
}
