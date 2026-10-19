/// Pure Dart: the customer credit ledger. Append-only: entries are never edited or deleted; a mistake is fixed by a new
/// entry. Amounts are integer paise and SIGNED from the shop's point of view:
///   positive = the customer owes us more, negative = the customer owes us less (or has paid in advance).
/// Balance = sum of entries. A positive balance is "Money to collect"; a negative balance is an "Advance".
library;

/// A part of a payment applied to one bill.
class Allocation {
  const Allocation(this.billNo, this.paise);
  final String billNo;
  final int paise;
  @override
  String toString() => '$billNo:$paise';
}

enum LedgerKind {
  opening, // balance carried in (positive = owes, negative = advance)
  billCredit, // unpaid part of a bill, added to credit
  payment, // money received from the customer
  advance, // money received above the dues, kept on account
  returnCredit, // credit note for returned goods
  adjustment, // correction (either sign), with a reason; also how a wrong entry is reversed
  manualCredit, // credit added by hand (goods taken without a bill, an old debt), with a reason
  writeOff, // owner decided not to collect the rest (owner only, reason)
  billCancel, // reverses the credit of a cancelled bill
}

class LedgerEntry {
  const LedgerEntry({required this.id, required this.customerId, required this.kind, required this.amountPaise, required this.at, this.billNo, this.note = '', this.by = '', this.mode, this.reverses, this.allocations = const []});

  final String id, customerId;
  final LedgerKind kind;
  final int amountPaise; // signed, see above
  final DateTime at;
  final String? billNo; // bill this entry belongs to, when there is one
  final String note, by;
  final String? mode; // cash / upi / card for payments

  /// Set on a reversal: the id of the entry this one cancels out.
  final String? reverses;

  /// For payments and write-offs: which bills the money was applied to (so a reversal can put it back).
  final List<Allocation> allocations;

  // Factories force the right sign, so a caller cannot record a payment as a charge by mistake.
  factory LedgerEntry.opening({required String id, required String customerId, required int paise, required DateTime at, String by = ''}) =>
      LedgerEntry(id: id, customerId: customerId, kind: LedgerKind.opening, amountPaise: paise, at: at, note: 'Opening balance', by: by);

  factory LedgerEntry.billCredit({required String id, required String customerId, required int paise, required DateTime at, required String billNo, String by = ''}) {
    if (paise <= 0) throw ArgumentError.value(paise, 'paise', 'credit from a bill must be above zero');
    return LedgerEntry(id: id, customerId: customerId, kind: LedgerKind.billCredit, amountPaise: paise, at: at, billNo: billNo, by: by);
  }

  factory LedgerEntry.payment({required String id, required String customerId, required int paise, required DateTime at, String mode = 'cash', String note = '', String by = '', List<Allocation> allocations = const []}) {
    if (paise <= 0) throw ArgumentError.value(paise, 'paise', 'a payment must be above zero');
    return LedgerEntry(id: id, customerId: customerId, kind: LedgerKind.payment, amountPaise: -paise, at: at, mode: mode, note: note, by: by, allocations: allocations);
  }

  factory LedgerEntry.advance({required String id, required String customerId, required int paise, required DateTime at, String? billNo, String mode = 'cash', String note = '', String by = ''}) {
    if (paise <= 0) throw ArgumentError.value(paise, 'paise', 'an advance must be above zero');
    return LedgerEntry(id: id, customerId: customerId, kind: LedgerKind.advance, amountPaise: -paise, at: at, billNo: billNo, mode: mode, note: note, by: by);
  }

  factory LedgerEntry.returnCredit({required String id, required String customerId, required int paise, required DateTime at, String? billNo, String note = '', String by = ''}) {
    if (paise <= 0) throw ArgumentError.value(paise, 'paise', 'a credit note must be above zero');
    return LedgerEntry(id: id, customerId: customerId, kind: LedgerKind.returnCredit, amountPaise: -paise, at: at, billNo: billNo, note: note, by: by);
  }

  factory LedgerEntry.adjustment({required String id, required String customerId, required int signedPaise, required DateTime at, required String reason, String by = '', String? billNo, List<Allocation> allocations = const []}) {
    if (signedPaise == 0) throw ArgumentError.value(signedPaise, 'signedPaise', 'an adjustment cannot be zero');
    if (reason.trim().isEmpty) throw ArgumentError('an adjustment needs a reason');
    return LedgerEntry(id: id, customerId: customerId, kind: LedgerKind.adjustment, amountPaise: signedPaise, at: at, billNo: billNo, note: reason.trim(), by: by, allocations: allocations);
  }

  /// Credit added by hand: it increases what the customer owes. A reason is required.
  factory LedgerEntry.manualCredit({required String id, required String customerId, required int paise, required DateTime at, required String reason, required String by, String? billNo}) {
    if (paise <= 0) throw ArgumentError.value(paise, 'paise', 'manual credit must be above zero');
    if (reason.trim().isEmpty) throw ArgumentError('manual credit needs a reason');
    return LedgerEntry(id: id, customerId: customerId, kind: LedgerKind.manualCredit, amountPaise: paise, at: at, billNo: billNo, note: reason.trim(), by: by);
  }

  /// Cancels out a wrong entry with a NEW entry of the opposite amount (the wrong one stays in the ledger). Only entries
  /// for which [isReversible] is true; the caller must also check [reversedIds] so an entry is reversed only once.
  factory LedgerEntry.reversal({required String id, required String customerId, required LedgerEntry original, required DateTime at, required String reason, required String by}) {
    if (reason.trim().isEmpty) throw ArgumentError('a reversal needs a reason');
    if (!isReversible(original)) throw StateError('this entry cannot be reversed');
    return LedgerEntry(id: id, customerId: customerId, kind: LedgerKind.adjustment, amountPaise: -original.amountPaise, at: at, billNo: original.billNo, note: 'Reversal: ${reason.trim()}', by: by, reverses: original.id);
  }

  /// Owner only. Reduces what the customer owes; cannot take the balance below zero.
  factory LedgerEntry.writeOff({required String id, required String customerId, required int paise, required DateTime at, required String reason, required String by, List<Allocation> allocations = const []}) {
    if (paise <= 0) throw ArgumentError.value(paise, 'paise', 'a write-off must be above zero');
    if (reason.trim().isEmpty) throw ArgumentError('a write-off needs a reason');
    return LedgerEntry(id: id, customerId: customerId, kind: LedgerKind.writeOff, amountPaise: -paise, at: at, note: reason.trim(), by: by, allocations: allocations);
  }

  factory LedgerEntry.billCancel({required String id, required String customerId, required int paise, required DateTime at, required String billNo, required String reason, required String by}) {
    if (paise <= 0) throw ArgumentError.value(paise, 'paise', 'the reversal must be above zero');
    return LedgerEntry(id: id, customerId: customerId, kind: LedgerKind.billCancel, amountPaise: -paise, at: at, billNo: billNo, note: reason.trim(), by: by);
  }
}

/// Balance of a list of entries (positive = customer owes us).
int ledgerBalance(Iterable<LedgerEntry> entries) => entries.fold<int>(0, (s, e) => s + e.amountPaise);

/// One ledger line with the balance after it.
class LedgerLine {
  const LedgerLine(this.entry, this.runningPaise);
  final LedgerEntry entry;
  final int runningPaise;
}

/// Entries in date order (ties keep the order given) with a running balance.
List<LedgerLine> withRunningBalance(List<LedgerEntry> entries) {
  final sorted = [for (var i = 0; i < entries.length; i++) (i, entries[i])]..sort((a, b) {
      final c = a.$2.at.compareTo(b.$2.at);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  var run = 0;
  return [
    for (final e in sorted) LedgerLine(e.$2, run += e.$2.amountPaise),
  ];
}

/// The most that can be written off today: what the customer actually owes (never below zero).
int maxWriteOff(Iterable<LedgerEntry> entries) {
  final b = ledgerBalance(entries);
  return b > 0 ? b : 0;
}

/// Reverses the credit that a bill added. Throws if the bill never added credit or was already cancelled.
/// Money the customer paid LATER towards that bill is not touched, so the balance naturally ends lower (an advance
/// if they had paid more than they now owe).
LedgerEntry reverseBillCredit({required List<LedgerEntry> entries, required String customerId, required String billNo, required DateTime at, required String reason, required String by, required String entryId}) {
  if (reason.trim().isEmpty) throw ArgumentError('cancelling a bill needs a reason');
  final credit = entries.where((e) => e.billNo == billNo && e.kind == LedgerKind.billCredit).fold<int>(0, (s, e) => s + e.amountPaise);
  final reversed = entries.where((e) => e.billNo == billNo && e.kind == LedgerKind.billCancel).fold<int>(0, (s, e) => s - e.amountPaise);
  if (credit == 0) throw StateError('bill $billNo added no credit, nothing to reverse');
  if (reversed >= credit) throw StateError('bill $billNo is already cancelled');
  return LedgerEntry.billCancel(id: entryId, customerId: customerId, paise: credit - reversed, at: at, billNo: billNo, reason: reason, by: by);
}

/// Payments, advances, manual credit, write-offs, opening balances and adjustments can be reversed. Bills are cancelled through
/// the bill (with the stock effects), a bill cancellation is final, a sales return is final (the stock and the totals moved with
/// it), and a reversal is never reversed: make a new entry instead.
bool isReversible(LedgerEntry e) {
  if (e.reverses != null) return false;
  return switch (e.kind) {
    LedgerKind.billCredit || LedgerKind.billCancel || LedgerKind.returnCredit => false, // a return is final (its stock and totals moved with it)
    _ => true,
  };
}

/// The ids of entries that already have a reversal.
Set<String> reversedIds(Iterable<LedgerEntry> entries) => {for (final e in entries) if (e.reverses != null) e.reverses!};
