/// Barcodes for loose items (nails, nuts, pipe pieces) that come with no barcode of their own. Pure Dart.
library;

/// Can this text be printed as a Code 128 barcode? Code 128 holds the printable ASCII characters (letters without accents, digits, symbols).
/// A barcode with Tamil letters, accents or control characters cannot be drawn.
bool canMakeCode128(String text) {
  if (text.isEmpty || text.length > 40) return false;
  for (final u in text.codeUnits) {
    if (u < 32 || u > 126) return false;
  }
  return true;
}

/// The shop's own barcode for the [n]th product that needs one: ten digits starting with 2 (the range barcode standards keep free for
/// a shop's own use, so it can never clash with a manufacturer's code). Digits only, so any scanner types it correctly.
String shopBarcode(int n) => '2${n.toString().padLeft(9, '0')}';
