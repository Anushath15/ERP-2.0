/// Pure Dart (no Flutter): how a bill's money splits into "received", "balance added to credit" and "change".
/// All amounts are integer paise. No floating point anywhere.
library;

class PaymentSplit {
  const PaymentSplit._(this.total, this.received, this.balance, this.change);

  /// Grand total of the bill.
  final int total;

  /// What the customer handed over (>= 0).
  final int received;

  /// Part of the bill still unpaid: it is added to the customer's credit account.
  final int balance;

  /// Money received above the total: given back as change, or kept as an advance for a named customer.
  final int change;

  /// Part of the bill that is settled by this payment (never more than the total).
  int get settled => received < total ? received : total;

  bool get isFullyPaid => balance == 0;
  bool get isUnpaid => received == 0 && total > 0;
  bool get isPartPaid => received > 0 && balance > 0;
  bool get hasOverpayment => change > 0;

  @override
  String toString() => 'PaymentSplit(total=$total, received=$received, balance=$balance, change=$change)';
}

/// Splits [received] against [total]. Invariants (property-tested):
///  * `settled + balance == total`
///  * `received == settled + change`
///  * `balance >= 0` and `change >= 0`, and at most one of them is above zero.
PaymentSplit splitPayment({required int total, required int received}) {
  if (total < 0) throw ArgumentError.value(total, 'total', 'must not be negative');
  if (received < 0) throw ArgumentError.value(received, 'received', 'must not be negative');
  final balance = received >= total ? 0 : total - received;
  final change = received > total ? received - total : 0;
  return PaymentSplit._(total, received, balance, change);
}

/// Parses text typed in the "Amount received" box ("150", "150.5", "1,250.75", "₹ 99") into paise, or null if it is not a
/// valid amount. Uses integer maths on the digits only: "150.5" is 15050 paise, never a double. More than two decimals is rejected.
int? parseRupeesToPaise(String input) {
  var s = input.trim().replaceAll('₹', '').replaceAll(',', '').replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (!RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(s) || s == '.') return null;
  final parts = s.split('.');
  final whole = parts[0].isEmpty ? '0' : parts[0];
  var frac = parts.length > 1 ? parts[1] : '';
  if (frac.length > 2) return null;
  frac = frac.padRight(2, '0');
  if (whole.length > 15) return null; // far beyond any real bill; keeps the result inside 64 bits
  return int.parse(whole) * 100 + int.parse(frac);
}
