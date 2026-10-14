import 'package:drift/drift.dart';
import '../../core/money.dart' show divRound;
import '../../domain/bill_math.dart';
import '../../domain/credit/account.dart';
import '../../domain/credit/payment_split.dart';
import '../context.dart';
import '../db/app_database.dart';
import '../ids.dart';
import 'ledger_repo.dart';

class BillLineInput {
  const BillLineInput({required this.productId, required this.name, required this.unit, required this.qtyMilli, required this.ratePaise, required this.gstBp, this.discountBp = 0, this.costPaise = 0});
  final String productId, name, unit;
  final int qtyMilli, ratePaise, gstBp, discountBp;

  /// What the product cost per unit when sold (for the profit figure). Zero when unknown.
  final int costPaise;
}

/// What the billing screen hands over when "Save bill" is pressed.
class SaveBillInput {
  const SaveBillInput({
    required this.idemKey,
    required this.at,
    required this.lines,
    this.customerId,
    this.customerName = '',
    this.payMode = 0,
    this.receivedPaise,
    this.keepAdvance = false,
    this.pricesIncludeGst = true,
    this.interState = false,
    this.note = '',
    this.oldBillNo,
    this.fromEstimate,
  });

  /// When this bill is made from a saved estimate: its number. The estimate is marked converted in the same transaction (a second conversion is refused).
  final String? fromEstimate;

  /// Made once per bill on the screen: pressing Save twice, or a retry after a crash, returns the same bill.
  final String idemKey;
  final DateTime at;
  final List<BillLineInput> lines;
  final String? customerId;
  final String customerName;
  final int payMode; // 0 cash, 1 upi, 2 card / other
  final int? receivedPaise; // null = exactly the total
  final bool keepAdvance;
  final bool pricesIncludeGst, interState;
  final String note;
  final String? oldBillNo;
}

class SavedBill {
  const SavedBill({required this.id, required this.number, required this.at, required this.totalPaise, required this.receivedPaise, required this.balancePaise, required this.changePaise, required this.advanceKeptPaise, required this.replay});
  final String id, number;
  final DateTime at;
  final int totalPaise, receivedPaise, balancePaise, changePaise, advanceKeptPaise;

  /// True when this was a repeat of a bill that was already saved (nothing was written again).
  final bool replay;
}

/// A line of the sales register.
class BillRow {
  const BillRow({required this.id, required this.number, required this.at, required this.customerName, required this.customerId, required this.items, required this.totalPaise, required this.balancePaise, required this.payMode, required this.cancelled, this.oldBillNo});
  final String id, number, customerName;
  final String? customerId, oldBillNo;
  final DateTime at;
  final int items, totalPaise, balancePaise, payMode;
  final bool cancelled;
  int get paidPaise => totalPaise - balancePaise;
}

/// Where the next page of the register starts (keyset paging: never OFFSET).
class BillCursor {
  const BillCursor(this.billedAt, this.id, [this.totalPaise = 0]);
  final int billedAt;
  final String id;

  /// Only used when the register is sorted by amount.
  final int totalPaise;
}

class BillDetail {
  const BillDetail({required this.row, required this.lines, required this.received, required this.change, required this.advanceKept, required this.taxable, required this.cgst, required this.sgst, required this.igst, required this.discount, required this.roundOff, required this.pricesIncludeGst, required this.cancelReason, required this.note});
  final BillRow row;
  final List<BillLineRow> lines;
  final int received, change, advanceKept, taxable, cgst, sgst, igst, discount, roundOff;
  final bool pricesIncludeGst;
  final String? cancelReason;
  final String note;
}

class BillLineRow {
  const BillLineRow({required this.productId, required this.name, required this.unit, required this.qtyMilli, required this.ratePaise, required this.discountBp, required this.gstBp, required this.totalPaise});
  final String productId, name, unit;
  final int qtyMilli, ratePaise, discountBp, gstBp, totalPaise;
}

class BillRepo {
  BillRepo(this.cx, this.ledger);
  final DataContext cx;
  final LedgerRepo ledger;

  AppDatabase get _db => cx.db;

  /// The shop's own prefix text (optional) and this device's series letter. A device letter is never shared with another device.
  String invoicePrefix = '';
  String series = 'A';

  String numberFor(int seq) => '$invoicePrefix$series-${seq.toString().padLeft(6, '0')}';

  /// The number the NEXT bill will get (shown on the screen before saving; the real number is taken inside the save).
  Future<String> peekNextNumber() async => numberFor(await _db.scalarInt('SELECT value FROM counters WHERE name = ?', ['inv.$series']) + 1);

  // ---------------------------------------------------------------- save

  /// Saves a bill: the bill, its lines, the stock movements and stock figures, the ledger entries and balance, the day and
  /// product-month summaries and the upload queue row, all in ONE transaction. Either every part is there or none is.
  Future<SavedBill> saveBill(SaveBillInput input) async {
    if (input.lines.isEmpty) throw ArgumentError('A bill needs at least one line.');
    for (final l in input.lines) {
      if (l.qtyMilli <= 0) throw ArgumentError('Quantity must be above zero.');
      if (l.ratePaise < 0) throw ArgumentError('Rate cannot be negative.');
    }
    return _db.transaction(() async {
      final dup = await _db.row('SELECT * FROM bills WHERE idem_key = ?', [input.idemKey]);
      if (dup != null) return _saved(dup, replay: true);

      final calc = calcBillIn([for (final l in input.lines) CalcLineIn(rate: l.ratePaise, qtyMilli: l.qtyMilli, gstBp: l.gstBp, discountBp: l.discountBp)], inclusive: input.pricesIncludeGst, interState: input.interState);
      final total = calc.grandTotal;
      final received = input.receivedPaise ?? total;
      final split = splitPayment(total: total, received: received);
      if (split.balance > 0 && input.customerId == null) throw StateError('A bill with money left to pay needs a customer.');
      final advance = input.customerId != null && input.keepAdvance ? split.change : 0;
      final change = advance > 0 ? 0 : split.change;

      final seq = await nextCounter(_db, 'inv.$series');
      final number = numberFor(seq);
      final id = newId();
      final at = input.at.millisecondsSinceEpoch;
      final day = DataContext.dayOf(input.at);
      await _db.exec(
        'INSERT INTO bills(id, number, series, seq, billed_at, day, customer_id, customer_name, total_paise, received_paise, balance_paise, change_paise, advance_kept_paise, taxable_paise, cgst_paise, sgst_paise, igst_paise, discount_paise, round_off_paise, pay_mode, item_count, prices_include_gst, idem_key, old_bill_no, note, created_by, created_at, device_id) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [id, number, series, seq, at, day, input.customerId, input.customerName, total, split.received, split.balance, change, advance, calc.taxable, calc.cgst, calc.sgst, calc.igst, calc.discount, calc.roundOff, input.payMode, input.lines.length, input.pricesIncludeGst ? 1 : 0, input.idemKey, input.oldBillNo, input.note, cx.actor.name, cx.nowMs(), cx.deviceId],
      );

      final month = DataContext.monthOf(input.at);
      for (var i = 0; i < input.lines.length; i++) {
        final l = input.lines[i];
        final c = calc.lines[i];
        await _db.exec(
          'INSERT INTO bill_lines(id, bill_id, line_no, product_id, name, unit, qty_milli, rate_paise, cost_paise, discount_bp, gst_bp, gross_paise, discount_paise, taxable_paise, tax_paise, total_paise) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
          [newId(), id, i + 1, l.productId, l.name, l.unit, l.qtyMilli, l.ratePaise, l.costPaise, l.discountBp, l.gstBp, c.gross, c.discount, c.taxable, c.tax, c.total],
        );
        await _stockMove(l.productId, -l.qtyMilli, 'sale', id, at);
        await _db.exec(
          'INSERT INTO product_month(product_id, month, qty_milli, amount_paise) VALUES (?,?,?,?) ON CONFLICT(product_id, month) DO UPDATE SET qty_milli = qty_milli + excluded.qty_milli, amount_paise = amount_paise + excluded.amount_paise',
          [l.productId, month, l.qtyMilli, c.total],
        );
      }

      if (input.customerId != null) {
        await ledger.addBillCredit(_db, PartyKind.customer, partyId: input.customerId!, billNo: number, at: input.at, total: total, received: split.received, advance: advance);
      }
      var cost = 0;
      for (final l in input.lines) {
        cost += divRound(l.costPaise * l.qtyMilli, 1000);
      }
      await _dayTotals(day, sign: 1, total: total, taxable: calc.taxable, cost: cost, tax: calc.tax, balance: split.balance, mode: input.payMode);
      if (input.fromEstimate != null) {
        final e = await _db.row('SELECT id, converted_bill_id FROM estimations WHERE number = ?', [input.fromEstimate]);
        if (e == null) throw StateError('No such estimate.');
        if (e.readNullable<String>('converted_bill_id') != null) throw StateError('This estimate was already converted.');
        await _db.exec('UPDATE estimations SET converted_bill_id = ?, updated_at = ?, version = version + 1, hlc = ? WHERE id = ?', [number, cx.nowMs(), cx.hlc.next(), e.read<String>('id')]);
        await enqueue(cx, _db, 'estimations', e.read<String>('id'));
      }
      await enqueue(cx, _db, 'bills', id);
      final row = await _db.row('SELECT * FROM bills WHERE id = ?', [id]);
      return _saved(row!, replay: false);
    });
  }

  Future<void> _stockMove(String productId, int qtyMilli, String kind, String refId, int at, {int unitCost = 0}) async {
    await _db.exec('INSERT INTO stock_movements(id, product_id, qty_milli, kind, ref_id, unit_cost_paise, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?)', [newId(), productId, qtyMilli, kind, refId, unitCost, at, cx.nowMs(), cx.deviceId]);
    await _db.exec('INSERT INTO stock_cache(product_id, qty_milli) VALUES (?,?) ON CONFLICT(product_id) DO UPDATE SET qty_milli = qty_milli + excluded.qty_milli', [productId, qtyMilli]);
  }

  Future<void> _dayTotals(String day, {required int sign, required int total, required int taxable, required int cost, required int tax, required int balance, required int mode}) async {
    final settled = total - balance;
    final cash = mode == 0 ? settled : 0, upi = mode == 1 ? settled : 0, card = mode >= 2 ? settled : 0;
    await _db.exec(
      'INSERT INTO day_totals(day, bills, sales_paise, taxable_paise, cost_paise, tax_paise, cash_paise, upi_paise, card_paise, credit_paise) VALUES (?,?,?,?,?,?,?,?,?,?) '
      'ON CONFLICT(day) DO UPDATE SET bills = bills + excluded.bills, sales_paise = sales_paise + excluded.sales_paise, taxable_paise = taxable_paise + excluded.taxable_paise, cost_paise = cost_paise + excluded.cost_paise, tax_paise = tax_paise + excluded.tax_paise, '
      'cash_paise = cash_paise + excluded.cash_paise, upi_paise = upi_paise + excluded.upi_paise, card_paise = card_paise + excluded.card_paise, credit_paise = credit_paise + excluded.credit_paise',
      [day, sign, sign * total, sign * taxable, sign * cost, sign * tax, sign * cash, sign * upi, sign * card, sign * balance],
    );
  }

  SavedBill _saved(QueryRow r, {required bool replay}) => SavedBill(
        id: r.read<String>('id'),
        number: r.read<String>('number'),
        at: DateTime.fromMillisecondsSinceEpoch(r.read<int>('billed_at')),
        totalPaise: r.read<int>('total_paise'),
        receivedPaise: r.read<int>('received_paise'),
        balancePaise: r.read<int>('balance_paise'),
        changePaise: r.read<int>('change_paise'),
        advanceKeptPaise: r.read<int>('advance_kept_paise'),
        replay: replay,
      );

  // ---------------------------------------------------------------- cancel

  /// Cancels a bill (owner, with a reason): a cancellation record, the stock put back, the credit reversed, the summaries corrected.
  /// The bill itself stays. Cannot be undone. Returns false when it was already cancelled.
  Future<bool> cancelBill(String billId, {required String reason, DateTime? at}) async {
    if (reason.trim().isEmpty) throw ArgumentError('Cancelling a bill needs a reason.');
    return _db.transaction(() async {
      final b = await _db.row('SELECT * FROM bills WHERE id = ?', [billId]);
      if (b == null) throw StateError('No such bill.');
      if (b.read<int>('cancelled') == 1) return false;
      final when = at ?? cx.now();
      final number = b.read<String>('number');
      await _db.exec('INSERT INTO bill_cancellations(id, bill_id, bill_no, reason, by_name, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?)', [newId(), billId, number, reason.trim(), cx.actor.name, when.millisecondsSinceEpoch, cx.nowMs(), cx.deviceId]);
      await _db.exec('UPDATE bills SET cancelled = 1 WHERE id = ?', [billId]);
      final lines = await _db.rows('SELECT product_id, qty_milli, total_paise, cost_paise FROM bill_lines WHERE bill_id = ?', [billId]);
      var cost = 0;
      final billedAt = DateTime.fromMillisecondsSinceEpoch(b.read<int>('billed_at'));
      final month = DataContext.monthOf(billedAt);
      for (final l in lines) {
        cost += divRound(l.read<int>('cost_paise') * l.read<int>('qty_milli'), 1000);
        await _stockMove(l.read<String>('product_id'), l.read<int>('qty_milli'), 'cancel', billId, when.millisecondsSinceEpoch);
        await _db.exec('UPDATE product_month SET qty_milli = qty_milli - ?, amount_paise = amount_paise - ? WHERE product_id = ? AND month = ?', [l.read<int>('qty_milli'), l.read<int>('total_paise'), l.read<String>('product_id'), month]);
      }
      final customerId = b.readNullable<String>('customer_id');
      if (customerId != null) await ledger.cancelBillCredit(_db, PartyKind.customer, partyId: customerId, billNo: number, at: when, reason: reason.trim());
      final tax = b.read<int>('cgst_paise') + b.read<int>('sgst_paise') + b.read<int>('igst_paise');
      final day = b.read<String>('day');
      await _dayTotals(day, sign: -1, total: b.read<int>('total_paise'), taxable: b.read<int>('taxable_paise'), cost: cost, tax: tax, balance: b.read<int>('balance_paise'), mode: b.read<int>('pay_mode'));
      await _db.exec('UPDATE day_totals SET cancelled_bills = cancelled_bills + 1, cancelled_paise = cancelled_paise + ? WHERE day = ?', [b.read<int>('total_paise'), day]);
      await enqueue(cx, _db, 'billCancellations', (await _db.row('SELECT id FROM bill_cancellations WHERE bill_id = ?', [billId]))!.read<String>('id'));
      await _db.exec(
        'INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)',
        [newId(), 'cancelBill', 'bill', billId, 'status', 'active', 'cancelled: ${reason.trim()}', cx.actor.name, cx.nowMs(), cx.deviceId],
      );
      return true;
    });
  }

  // ---------------------------------------------------------------- reading

  static BillRow _row(QueryRow r) => BillRow(
        id: r.read<String>('id'),
        number: r.read<String>('number'),
        at: DateTime.fromMillisecondsSinceEpoch(r.read<int>('billed_at')),
        customerName: r.read<String>('customer_name'),
        customerId: r.readNullable<String>('customer_id'),
        items: r.read<int>('item_count'),
        totalPaise: r.read<int>('total_paise'),
        balancePaise: r.read<int>('balance_paise'),
        payMode: r.read<int>('pay_mode'),
        cancelled: r.read<int>('cancelled') == 1,
        oldBillNo: r.readNullable<String>('old_bill_no'),
      );

  /// One page of the register, newest first. [after] is the cursor of the last row of the previous page. [search] matches the bill
  /// number, the old (ERP 1) bill number or the customer name. [from] and [to] bound the date.
  /// [status]: 0 all, 1 paid, 2 part paid, 3 unpaid (on credit), 4 cancelled. [byAmount] sorts the biggest bill first instead of the newest.
  Future<List<BillRow>> page({BillCursor? after, String? customerId, String search = '', DateTime? from, DateTime? to, bool onlyCancelled = false, bool onlyDue = false, int status = 0, bool byAmount = false, int limit = 50}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (customerId != null) {
      where.add('customer_id = ?');
      args.add(customerId);
    }
    final q = search.trim();
    if (q.isNotEmpty) {
      where.add("(number LIKE ? ESCAPE '\\' OR old_bill_no LIKE ? ESCAPE '\\' OR customer_name LIKE ? ESCAPE '\\')");
      final like = '%${q.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
      args.addAll([like, like, like]);
    }
    if (from != null) {
      where.add('billed_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('billed_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (onlyCancelled || status == 4) where.add('cancelled = 1');
    if (status == 1) where.add('cancelled = 0 AND balance_paise = 0');
    if (status == 2) where.add('cancelled = 0 AND balance_paise > 0 AND balance_paise < total_paise');
    if (status == 3) where.add('cancelled = 0 AND balance_paise > 0 AND balance_paise >= total_paise');
    if (onlyDue) where.add('balance_paise > 0 AND cancelled = 0');
    if (after != null) {
      if (byAmount) {
        where.add('(total_paise < ? OR (total_paise = ? AND id < ?))');
        args.addAll([after.totalPaise, after.totalPaise, after.id]);
      } else {
        where.add('(billed_at < ? OR (billed_at = ? AND id < ?))');
        args.addAll([after.billedAt, after.billedAt, after.id]);
      }
    }
    final r = await _db.rows('SELECT * FROM bills ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY ${byAmount ? 'total_paise DESC, id DESC' : 'billed_at DESC, id DESC'} LIMIT ?', [...args, limit]);
    return [for (final x in r) _row(x)];
  }

  static BillCursor cursorOf(BillRow r) => BillCursor(r.at.millisecondsSinceEpoch, r.id, r.totalPaise);

  Future<int> count({bool includeCancelled = true}) => _db.scalarInt('SELECT COUNT(*) FROM bills ${includeCancelled ? '' : 'WHERE cancelled = 0'}');

  /// Bills and cancelled bills together, from the day summaries (a few thousand rows however many bills there are).
  Future<int> countFast() => _db.scalarInt('SELECT COALESCE(SUM(bills + cancelled_bills), 0) FROM day_totals');

  Future<BillDetail?> detail(String billId) async {
    final b = await _db.row('SELECT * FROM bills WHERE id = ?', [billId]);
    if (b == null) return null;
    final ls = await _db.rows('SELECT * FROM bill_lines WHERE bill_id = ? ORDER BY line_no', [billId]);
    final c = await _db.row('SELECT reason FROM bill_cancellations WHERE bill_id = ?', [billId]);
    return BillDetail(
      row: _row(b),
      lines: [for (final l in ls) BillLineRow(productId: l.read<String>('product_id'), name: l.read<String>('name'), unit: l.read<String>('unit'), qtyMilli: l.read<int>('qty_milli'), ratePaise: l.read<int>('rate_paise'), discountBp: l.read<int>('discount_bp'), gstBp: l.read<int>('gst_bp'), totalPaise: l.read<int>('total_paise'))],
      received: b.read<int>('received_paise'),
      change: b.read<int>('change_paise'),
      advanceKept: b.read<int>('advance_kept_paise'),
      taxable: b.read<int>('taxable_paise'),
      cgst: b.read<int>('cgst_paise'),
      sgst: b.read<int>('sgst_paise'),
      igst: b.read<int>('igst_paise'),
      discount: b.read<int>('discount_paise'),
      roundOff: b.read<int>('round_off_paise'),
      pricesIncludeGst: b.read<int>('prices_include_gst') == 1,
      cancelReason: c?.read<String>('reason'),
      note: b.read<String>('note'),
    );
  }

  Future<BillRow?> byNumber(String number) async {
    final r = await _db.row('SELECT * FROM bills WHERE number = ?', [number]);
    return r == null ? null : _row(r);
  }
}
