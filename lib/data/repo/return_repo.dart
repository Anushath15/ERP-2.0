/// Sales returns: goods a customer gives back from one saved bill. The rules (docs/data-model.md, "Sales returns"):
///  - only a bill that is not cancelled, only the quantity still with the customer (sold minus returned before);
///  - the refund of a line is its share of the line's total (the last part of a line takes what is left, so the parts always add up
///    exactly), and the return that brings back the LAST of a bill also takes the bill's round-off, so the customer gets back
///    exactly what the bill charged;
///  - stock goes back (a movement of kind 'return');
///  - a customer who still owes on that bill first gets the refund taken off that debt (the oldest rule of "credit note"), and what is
///    left is handed back (cash, UPI or card) or, if asked, kept as credit on the account;
///  - the day totals of the RETURN day are reduced; the bill and its own day stay as they were (append-only);
///  - everything is written in ONE transaction, with a number from a gapless counter and an idempotency key (a retry returns the same
///    return and writes nothing).
library;

import 'package:drift/drift.dart' show QueryRow;
import '../../core/money.dart';
import '../../domain/credit/account.dart';
import '../../domain/credit/ledger.dart';
import '../context.dart';
import '../db/app_database.dart';
import '../ids.dart';
import 'ledger_repo.dart';

/// A bill line as the return screen shows it.
class ReturnableLine {
  const ReturnableLine({required this.billLineId, required this.productId, required this.name, required this.unit, required this.soldMilli, required this.returnedMilli, required this.ratePaise, required this.discountBp, required this.totalPaise, this.returnedPaise = 0});
  final String billLineId, productId, name, unit;
  final int soldMilli, returnedMilli, ratePaise, discountBp, totalPaise;

  /// The refunds already made for this line.
  final int returnedPaise;
  int get remainingMilli => soldMilli - returnedMilli;
}

class ReturnableBill {
  const ReturnableBill({required this.billId, required this.number, required this.at, required this.customerId, required this.customerName, required this.totalPaise, required this.outstandingPaise, required this.lines, this.roundOffPaise = 0});
  final String billId, number, customerName;
  final String? customerId;
  final DateTime at;
  final int totalPaise;

  /// What the customer still owes on THIS bill (a refund is taken off it first).
  final int outstandingPaise;
  final List<ReturnableLine> lines;

  /// The bill's own round-off: it goes back with the last item.
  final int roundOffPaise;
  bool get anythingLeft => lines.any((l) => l.remainingMilli > 0);
}

/// What the person typed on the return screen.
class SaveReturnInput {
  const SaveReturnInput({required this.idemKey, required this.billId, required this.at, required this.lines, required this.reason, this.refundMode = 0, this.keepAsCredit = false});
  final String idemKey, billId, reason;
  final DateTime at;

  /// billLineId -> quantity coming back (thousandths). Zero and missing lines are ignored.
  final Map<String, int> lines;

  /// How a money refund is handed back: 0 cash, 1 UPI, 2 card.
  final int refundMode;

  /// A named customer only: keep what is left after their debt as credit on the account instead of handing it back.
  final bool keepAsCredit;
}

class SavedReturn {
  const SavedReturn({required this.id, required this.number, required this.billNo, required this.totalPaise, required this.dueReducedPaise, required this.creditKeptPaise, required this.refundedPaise, required this.replay});
  final String id, number, billNo;
  final int totalPaise, dueReducedPaise, creditKeptPaise, refundedPaise;
  final bool replay;
}

/// A line of the "Sales returns" list.
class ReturnRow {
  const ReturnRow({required this.id, required this.number, required this.billNo, required this.customerName, required this.at, required this.totalPaise, required this.reason, required this.dueReducedPaise, required this.creditKeptPaise, required this.refundedPaise, required this.items});
  final String id, number, billNo, customerName, reason;
  final DateTime at;
  final int totalPaise, dueReducedPaise, creditKeptPaise, refundedPaise, items;
}

class ReturnRepo {
  ReturnRepo(this.cx, this.ledger);
  final DataContext cx;
  final LedgerRepo ledger;
  AppDatabase get _db => cx.db;

  /// The id of the bill with this number (case does not matter), or null.
  Future<String?> billIdByNumber(String number) async {
    final r = await _db.row('SELECT id FROM bills WHERE number = ? COLLATE NOCASE', [number.trim()]);
    return r?.read<String>('id');
  }

  /// How much was given back so far from this bill.
  Future<int> returnedTotal(String billId) => _db.scalarInt('SELECT COALESCE(SUM(total_paise), 0) FROM sales_returns WHERE bill_id = ?', [billId]);

  /// How many returns were made from this bill.
  Future<int> countForBill(String billId) => _db.scalarInt('SELECT COUNT(*) FROM sales_returns WHERE bill_id = ?', [billId]);

  /// The bill with, for each line, how much is still with the customer. Null when there is no such bill.
  Future<ReturnableBill?> returnable(String billId) async {
    final b = await _db.row('SELECT * FROM bills WHERE id = ?', [billId]);
    if (b == null) return null;
    final ls = await _db.rows(
        'SELECT l.*, COALESCE((SELECT SUM(r.qty_milli) FROM sales_return_lines r WHERE r.bill_line_id = l.id), 0) AS back, '
        'COALESCE((SELECT SUM(r.amount_paise) FROM sales_return_lines r WHERE r.bill_line_id = l.id), 0) AS back_amt FROM bill_lines l WHERE l.bill_id = ? ORDER BY l.line_no',
        [billId]);
    final customerId = b.readNullable<String>('customer_id');
    final number = b.read<String>('number');
    var outstanding = 0;
    if (customerId != null) {
      outstanding = await _db.scalarInt('SELECT COALESCE(SUM(total_paise - paid_paise), 0) FROM party_bills WHERE party_id = ? AND bill_no = ? AND cancelled = 0', [customerId, number]);
    }
    return ReturnableBill(
      billId: billId,
      number: number,
      at: DateTime.fromMillisecondsSinceEpoch(b.read<int>('billed_at')),
      customerId: customerId,
      customerName: b.read<String>('customer_name'),
      totalPaise: b.read<int>('total_paise'),
      outstandingPaise: outstanding,
      roundOffPaise: b.read<int>('round_off_paise'),
      lines: [
        for (final l in ls)
          ReturnableLine(
            billLineId: l.read<String>('id'),
            productId: l.read<String>('product_id'),
            name: l.read<String>('name'),
            unit: l.read<String>('unit'),
            soldMilli: l.read<int>('qty_milli'),
            returnedMilli: l.read<int>('back'),
            ratePaise: l.read<int>('rate_paise'),
            discountBp: l.read<int>('discount_bp'),
            totalPaise: l.read<int>('total_paise'),
            returnedPaise: l.read<int>('back_amt'),
          ),
      ],
    );
  }

  /// What a return would refund and how it would be settled, from the same rules the save uses (for the screen to show before saving).
  static ({int total, int dueReduced, int creditKept, int refunded}) preview(ReturnableBill b, Map<String, int> qty, {bool keepAsCredit = false}) {
    var total = 0;
    var allBack = true;
    for (final l in b.lines) {
      final q = qty[l.billLineId] ?? 0;
      if (q > 0) total += share(l.totalPaise, l.soldMilli, l.returnedPaise, l.returnedMilli, q);
      if (l.remainingMilli - q > 0) allBack = false;
    }
    if (total > 0 && allBack) total += b.roundOffPaise;
    if (total < 0) total = 0;
    if (b.customerId == null) return (total: total, dueReduced: 0, creditKept: 0, refunded: total);
    final due = total < b.outstandingPaise ? total : b.outstandingPaise;
    final rest = total - due;
    return (total: total, dueReduced: due, creditKept: keepAsCredit ? rest : 0, refunded: keepAsCredit ? 0 : rest);
  }

  /// The refund for taking back [qty] of a line: its share of the total, exact on the last part.
  static int share(int lineValue, int soldMilli, int alreadyBackValue, int alreadyBackMilli, int qty) {
    if (qty == soldMilli - alreadyBackMilli) return lineValue - alreadyBackValue; // the last part takes what is left
    return divRound(lineValue * qty, soldMilli);
  }

  Future<SavedReturn> saveReturn(SaveReturnInput input) async {
    if (input.reason.trim().isEmpty) throw ArgumentError('A return needs a reason.');
    if (input.refundMode < 0 || input.refundMode > 2) throw ArgumentError('Unknown refund method.');
    return _db.transaction(() async {
      final dup = await _db.row('SELECT * FROM sales_returns WHERE idem_key = ?', [input.idemKey]);
      if (dup != null) return _saved(dup, replay: true);

      final b = await _db.row('SELECT * FROM bills WHERE id = ?', [input.billId]);
      if (b == null) throw StateError('No such bill.');
      if (b.read<int>('cancelled') == 1) throw StateError('This bill was cancelled, so nothing can be returned from it.');
      final billNo = b.read<String>('number');
      final customerId = b.readNullable<String>('customer_id');
      final at = input.at.millisecondsSinceEpoch;
      final day = DataContext.dayOf(input.at);
      final month = DataContext.monthOf(input.at);

      final ls = await _db.rows(
          'SELECT l.*, COALESCE((SELECT SUM(r.qty_milli) FROM sales_return_lines r WHERE r.bill_line_id = l.id), 0) AS back_qty, '
          'COALESCE((SELECT SUM(r.amount_paise) FROM sales_return_lines r WHERE r.bill_line_id = l.id), 0) AS back_amt, '
          'COALESCE((SELECT SUM(r.taxable_paise) FROM sales_return_lines r WHERE r.bill_line_id = l.id), 0) AS back_tax_base '
          'FROM bill_lines l WHERE l.bill_id = ? ORDER BY l.line_no',
          [input.billId]);
      final byId = {for (final l in ls) l.read<String>('id'): l};
      for (final id in input.lines.keys) {
        if (!byId.containsKey(id)) throw StateError('A line does not belong to this bill.');
      }

      final picked = <({QueryRow l, int qty, int amount, int taxable, int cost})>[];
      var allBack = true;
      for (final l in ls) {
        final id = l.read<String>('id');
        final sold = l.read<int>('qty_milli');
        final back = l.read<int>('back_qty');
        final qty = input.lines[id] ?? 0;
        if (qty < 0) throw ArgumentError('A quantity cannot be negative.');
        if (qty > sold - back) throw StateError('More than what is left with the customer cannot be returned (${l.read<String>('name')}).');
        if (qty > 0) {
          final amount = share(l.read<int>('total_paise'), sold, l.read<int>('back_amt'), back, qty);
          final taxable = share(l.read<int>('taxable_paise'), sold, l.read<int>('back_tax_base'), back, qty);
          picked.add((l: l, qty: qty, amount: amount, taxable: taxable, cost: divRound(l.read<int>('cost_paise') * qty, 1000)));
        }
        if (sold - back - qty > 0) allBack = false;
      }
      if (picked.isEmpty) throw ArgumentError('Choose at least one item to return.');

      var total = 0, taxable = 0, cost = 0;
      for (final p in picked) {
        total += p.amount;
        taxable += p.taxable;
        cost += p.cost;
      }
      final roundOff = allBack ? b.read<int>('round_off_paise') : 0; // the bill's round-off goes back with its last item
      total += roundOff;
      if (total < 0) total = 0;
      final tax = total - roundOff - taxable;
      if (tax < 0) throw StateError('The return does not add up; nothing was saved.');
      final igstBill = b.read<int>('igst_paise'), billTax = b.read<int>('cgst_paise') + b.read<int>('sgst_paise') + igstBill;
      final igst = billTax == 0 ? 0 : (igstBill == billTax ? tax : 0);
      final cgst = igst > 0 ? 0 : divRound(tax, 2);
      final sgst = igst > 0 ? 0 : tax - cgst;

      // who gets what
      var dueReduced = 0, creditKept = 0, refunded = total;
      if (customerId != null) {
        final outstanding = await _db.scalarInt('SELECT COALESCE(SUM(total_paise - paid_paise), 0) FROM party_bills WHERE party_id = ? AND bill_no = ? AND cancelled = 0', [customerId, billNo]);
        dueReduced = total < outstanding ? total : outstanding;
        final rest = total - dueReduced;
        if (input.keepAsCredit) {
          creditKept = rest;
          refunded = 0;
        } else {
          refunded = rest;
        }
      }

      final id = newId();
      final number = 'SRT-${(await nextCounter(_db, 'rec.salesReturns')).toString().padLeft(4, '0')}';
      await _db.exec(
        'INSERT INTO sales_returns(id, number, bill_id, bill_no, customer_id, customer_name, returned_at, day, total_paise, taxable_paise, cgst_paise, sgst_paise, igst_paise, cost_paise, round_off_paise, due_reduced_paise, credit_kept_paise, refunded_paise, refund_mode, reason, by_name, idem_key, created_at, device_id) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [id, number, input.billId, billNo, customerId, b.read<String>('customer_name'), at, day, total, taxable, cgst, sgst, igst, cost, roundOff, dueReduced, creditKept, refunded, input.refundMode, input.reason.trim(), cx.actor.name, input.idemKey, cx.nowMs(), cx.deviceId],
      );
      for (final p in picked) {
        final l = p.l;
        await _db.exec(
          'INSERT INTO sales_return_lines(id, return_id, bill_line_id, product_id, name, unit, qty_milli, amount_paise, taxable_paise, tax_paise, cost_paise) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
          [newId(), id, l.read<String>('id'), l.read<String>('product_id'), l.read<String>('name'), l.read<String>('unit'), p.qty, p.amount, p.taxable, p.amount - p.taxable, p.cost],
        );
        final pid = l.read<String>('product_id');
        await _db.exec('INSERT INTO stock_movements(id, product_id, qty_milli, kind, ref_id, unit_cost_paise, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?)', [newId(), pid, p.qty, 'return', id, l.read<int>('cost_paise'), at, cx.nowMs(), cx.deviceId]);
        await _db.exec('INSERT INTO stock_cache(product_id, qty_milli) VALUES (?,?) ON CONFLICT(product_id) DO UPDATE SET qty_milli = qty_milli + excluded.qty_milli', [pid, p.qty]);
        await _db.exec(
          'INSERT INTO product_month(product_id, month, qty_milli, amount_paise) VALUES (?,?,?,?) ON CONFLICT(product_id, month) DO UPDATE SET qty_milli = qty_milli + excluded.qty_milli, amount_paise = amount_paise + excluded.amount_paise',
          [pid, month, -p.qty, -p.amount],
        );
      }

      final cash = input.refundMode == 0 ? refunded : 0, upi = input.refundMode == 1 ? refunded : 0, card = input.refundMode == 2 ? refunded : 0;
      await _db.exec(
        'INSERT INTO day_totals(day, bills, sales_paise, taxable_paise, cost_paise, tax_paise, cash_paise, upi_paise, card_paise, credit_paise) VALUES (?,0,?,?,?,?,?,?,?,?) '
        'ON CONFLICT(day) DO UPDATE SET sales_paise = sales_paise + excluded.sales_paise, taxable_paise = taxable_paise + excluded.taxable_paise, cost_paise = cost_paise + excluded.cost_paise, tax_paise = tax_paise + excluded.tax_paise, '
        'cash_paise = cash_paise + excluded.cash_paise, upi_paise = upi_paise + excluded.upi_paise, card_paise = card_paise + excluded.card_paise, credit_paise = credit_paise + excluded.credit_paise',
        [day, -total, -taxable, -cost, -tax, -cash, -upi, -card, -dueReduced],
      );

      if (customerId != null && dueReduced + creditKept > 0) {
        final entry = LedgerEntry(
          id: newId(),
          customerId: customerId,
          kind: LedgerKind.returnCredit,
          amountPaise: -(dueReduced + creditKept),
          at: input.at,
          billNo: billNo,
          note: '$number: ${input.reason.trim()}',
          by: cx.actor.name,
          allocations: dueReduced > 0 ? [Allocation(billNo, dueReduced)] : const [],
        );
        await ledger.addEntry(_db, PartyKind.customer, entry, refId: id, upload: true);
        if (dueReduced > 0) {
          final open = await ledger.dues(customerId, tx: _db, openOnly: true);
          await ledger.putDue(_db, PartyKind.customer, customerId, open.firstWhere((d) => d.billNo == billNo).paid(dueReduced));
        }
      }

      await enqueue(cx, _db, 'salesReturns', id);
      await _db.exec(
        'INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)',
        [newId(), 'salesReturn', 'bill', input.billId, 'return', '', '$number ${input.reason.trim()}', cx.actor.name, cx.nowMs(), cx.deviceId],
      );
      final row = await _db.row('SELECT * FROM sales_returns WHERE id = ?', [id]);
      return _saved(row!, replay: false);
    });
  }

  SavedReturn _saved(QueryRow r, {required bool replay}) => SavedReturn(
        id: r.read<String>('id'),
        number: r.read<String>('number'),
        billNo: r.read<String>('bill_no'),
        totalPaise: r.read<int>('total_paise'),
        dueReducedPaise: r.read<int>('due_reduced_paise'),
        creditKeptPaise: r.read<int>('credit_kept_paise'),
        refundedPaise: r.read<int>('refunded_paise'),
        replay: replay,
      );

  /// The newest returns first.
  Future<List<ReturnRow>> list({int limit = 1000}) async {
    final r = await _db.rows(
        'SELECT r.*, (SELECT COUNT(*) FROM sales_return_lines l WHERE l.return_id = r.id) AS items FROM sales_returns r ORDER BY r.returned_at DESC, r.id DESC LIMIT ?',
        [limit]);
    return [
      for (final x in r)
        ReturnRow(
          id: x.read<String>('id'),
          number: x.read<String>('number'),
          billNo: x.read<String>('bill_no'),
          customerName: x.read<String>('customer_name'),
          at: DateTime.fromMillisecondsSinceEpoch(x.read<int>('returned_at')),
          totalPaise: x.read<int>('total_paise'),
          reason: x.read<String>('reason'),
          dueReducedPaise: x.read<int>('due_reduced_paise'),
          creditKeptPaise: x.read<int>('credit_kept_paise'),
          refundedPaise: x.read<int>('refunded_paise'),
          items: x.read<int>('items'),
        ),
    ];
  }
}
