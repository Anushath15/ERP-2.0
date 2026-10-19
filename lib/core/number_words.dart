/// An amount in words, the Indian way (thousand, lakh, crore): 54000 paise -> "Rupees five hundred forty Only."
/// Used on the printed bill. Pure Dart.
library;

const _ones = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
const _tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];

String _below100(int n) => n < 20 ? _ones[n] : (n % 10 == 0 ? _tens[n ~/ 10] : '${_tens[n ~/ 10]} ${_ones[n % 10]}');

String _below1000(int n) {
  final h = n ~/ 100, r = n % 100;
  return [if (h > 0) '${_ones[h]} hundred', if (r > 0) _below100(r)].join(' ');
}

/// A whole number in words (0 to 99,99,99,999 and above in crores).
String numberInWords(int n) {
  if (n == 0) return 'zero';
  if (n < 0) return 'minus ${numberInWords(-n)}';
  final crore = n ~/ 10000000;
  final lakh = n % 10000000 ~/ 100000;
  final thousand = n % 100000 ~/ 1000;
  final rest = n % 1000;
  return [
    if (crore > 0) '${numberInWords(crore)} crore',
    if (lakh > 0) '${_below100(lakh)} lakh',
    if (thousand > 0) '${_below100(thousand)} thousand',
    if (rest > 0) _below1000(rest),
  ].join(' ');
}

/// "Rupees five hundred forty Only." and, with paise, "Rupees five hundred forty and fifty paise Only."
String rupeesInWords(int paise) {
  final p = paise < 0 ? -paise : paise;
  final rupees = p ~/ 100, ps = p % 100;
  final r = rupees == 0 && ps > 0 ? '' : numberInWords(rupees);
  final text = [if (r.isNotEmpty) r, if (ps > 0) '${r.isEmpty ? '' : 'and '}${numberInWords(ps)} paise'].join(' ');
  return 'Rupees $text Only.';
}
