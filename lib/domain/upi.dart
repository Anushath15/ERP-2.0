/// The UPI payment link a QR code carries (the same link every UPI app understands): who to pay, how much, and what for.
/// Pure Dart, integer paise. A customer scans it with PhonePe, Google Pay, Paytm or any bank app and only has to confirm.
library;

import '../core/validators.dart';

/// Is this a usable UPI id (like `shopname@okbank`)? Empty is not usable.
bool isUpiId(String upiId) => upiId.trim().isNotEmpty && checkText(TextKind.upi, upiId.trim()) == null;

String _plain(String s, int max) {
  final t = s.replaceAll(RegExp(r'[^A-Za-z0-9 .\-]'), ' ').replaceAll(RegExp(r' +'), ' ').trim();
  return t.length > max ? t.substring(0, max).trim() : t;
}

/// `upi://pay?pa=<id>&pn=<shop>&am=<rupees>&cu=INR&tn=<note>`, or null when there is no usable UPI id or nothing to pay.
/// The amount is written in rupees with two decimals (what the UPI apps expect); the shop name and note are kept short and plain.
String? upiPayUri({required String upiId, required String payeeName, required int amountPaise, String note = ''}) {
  if (!isUpiId(upiId) || amountPaise <= 0) return null;
  final rupees = '${amountPaise ~/ 100}.${(amountPaise % 100).toString().padLeft(2, '0')}';
  final pn = _plain(payeeName, 40);
  final tn = _plain(note, 40);
  // The id is written as it is, with its @: only letters, digits . _ - and one @ can get here (checked above), and the UPI apps expect
  // `pa=name@bank`, which is how bank and shop QR codes are normally written.
  return 'upi://pay?pa=${upiId.trim()}${pn.isEmpty ? '' : '&pn=${Uri.encodeComponent(pn)}'}&am=$rupees&cu=INR${tn.isEmpty ? '' : '&tn=${Uri.encodeComponent(tn)}'}';
}
