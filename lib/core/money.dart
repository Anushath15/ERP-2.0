/// Money is always integer paise. Formatting uses Indian digit grouping (12,34,567.89).
String groupIndian(int whole) {
  final s = whole.abs().toString();
  var out = s;
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    out = '${parts.join(',')},$last3';
  }
  return whole < 0 ? '-$out' : out;
}

/// `1234567` paise -> `12,345.67`.
String formatPaise(int paise, {bool symbol = false, bool trimZeros = false}) {
  final neg = paise < 0;
  final p = paise.abs();
  final whole = groupIndian(p ~/ 100);
  final frac = (p % 100).toString().padLeft(2, '0');
  final body = trimZeros && frac == '00' ? whole : '$whole.$frac';
  return '${neg ? '-' : ''}${symbol ? '₹' : ''}$body';
}

/// Quantity stored in thousandths: 25500 -> `25.5`, 2000 -> `2`.
String formatQty(int milli) {
  if (milli % 1000 == 0) return (milli ~/ 1000).toString();
  var s = (milli / 1000).toStringAsFixed(3);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Round-half-up integer division for non-negative values.
int divRound(int numerator, int denominator) => (numerator * 2 + denominator) ~/ (denominator * 2);

/// A value in paise from price (paise) x quantity (milli), rounded half-up to a paisa.
int lineAmount(int pricePaise, int qtyMilli) => divRound(pricePaise * qtyMilli, 1000);
