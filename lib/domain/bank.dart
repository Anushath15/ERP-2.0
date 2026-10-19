/// The shop's bank details as separate pieces (name, account number, IFSC code), and how the old single "Bank details" text is split into them.
/// Pure Dart.
library;

final _ifsc = RegExp(r'^[A-Za-z]{4}0[A-Za-z0-9]{6}$');

/// An IFSC code: 4 letters, a zero, then 6 letters or digits (SBIN0003780).
bool validIfsc(String s) => _ifsc.hasMatch(s.trim());

/// An account number: 6 to 18 digits.
bool validAccount(String s) => RegExp(r'^[0-9]{6,18}$').hasMatch(s.trim());

class BankParts {
  const BankParts({this.name = '', this.account = '', this.ifsc = ''});
  final String name, account, ifsc;
}

/// The old single text ("State Bank Of India, 44131804620, SBIN0003780", or with labels like "A/c" and "IFSC") split into its pieces: the part that looks like an
/// IFSC code, the part that is only an account-number-sized run of digits, and whatever is left is the bank name.
BankParts parseBankDetails(String text) {
  var name = <String>[];
  var account = '', ifsc = '';
  for (var part in text.split(RegExp(r'[\r\n,;]+'))) {
    part = part.trim();
    if (part.isEmpty) continue;
    final cleaned = part.replaceAll(RegExp(r'\b(ifsc( code)?|a/c( no\.?)?|account( no\.?| number)?|acc( no\.?)?)\b[:.\- ]*', caseSensitive: false), '').trim();
    if (ifsc.isEmpty && validIfsc(cleaned)) {
      ifsc = cleaned.toUpperCase();
    } else if (account.isEmpty && validAccount(cleaned.replaceAll(RegExp(r'[\s-]'), ''))) {
      account = cleaned.replaceAll(RegExp(r'[\s-]'), '');
    } else {
      name.add(part);
    }
  }
  return BankParts(name: name.join(', '), account: account, ifsc: ifsc);
}
