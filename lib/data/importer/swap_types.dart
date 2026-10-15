/// The data that was in use before a swap (an import or a go-back). Kept for 30 days so the owner can go back.
class PreviousData {
  PreviousData({required this.stamp, required this.at, required this.products, required this.customers, required this.bills, required this.bytes, required this.reason});
  final String stamp; // folder name, yyyymmdd-hhmmss
  final DateTime at;
  final int? products, customers, bills;
  final int bytes;
  final String reason;
  DateTime get offeredUntil => at.add(const Duration(days: 30));
}

/// What happened the last time the program swapped data files at start-up (shown on the Health page).
class SwapResult {
  SwapResult({required this.ok, required this.kind, required this.message, required this.at, this.prevStamp = '', this.counts = const {}});
  final bool ok;
  final String kind; // import | goback
  final String message;
  final DateTime at;
  final String prevStamp;
  final Map<String, int> counts;
}
