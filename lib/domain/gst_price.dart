/// A price typed with or without GST, turned into the figure the program keeps. Integer paise, half-up. Pure Dart.
///  - Selling price: kept the way the SHOP prices things (Shop profile > "Prices already include GST"), so a bill adds up the same
///    whichever way the person typed it.
///  - Buying price: kept WITHOUT GST (profit is worked out on the value before tax).
library;

import '../core/money.dart';

int _addGst(int paise, int gstBp) => divRound(paise * (10000 + gstBp), 10000);
int _removeGst(int paise, int gstBp) => divRound(paise * 10000, 10000 + gstBp);

/// The selling price to keep.
int sellingPriceToStore({required int enteredPaise, required bool enteredIncludesGst, required bool shopPricesIncludeGst, required int gstBp}) {
  if (enteredIncludesGst == shopPricesIncludeGst) return enteredPaise;
  return enteredIncludesGst ? _removeGst(enteredPaise, gstBp) : _addGst(enteredPaise, gstBp);
}

/// The buying price to keep (always without GST).
int buyingPriceToStore({required int enteredPaise, required bool enteredIncludesGst, required int gstBp}) =>
    enteredIncludesGst ? _removeGst(enteredPaise, gstBp) : enteredPaise;
