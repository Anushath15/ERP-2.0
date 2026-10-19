/// Purchase returns: goods given back to a dealer from one RECEIVED purchase. The rules (docs/data-model.md, "Schema version 6"), the
/// same shape as sales returns:
///  - only what is still with the shop (bought minus returned before, per item) and only what is in stock now;
///  - the value of an item is its share of the item's total (the last part takes what is left, so the parts add up exactly);
///  - the stock goes OUT (a movement of kind 'purchase_return');
///  - what the shop still owes the dealer on that purchase is reduced first (a credit note on the dealer's account); the rest is paid
///    back by the dealer (cash, UPI or card) or, if asked, kept as credit with the dealer;
///  - one transaction, a gapless number, an idempotency key; final (never edited or reversed).
library;

import 'package:drift/drift.dart' show QueryRow;
import '../../core/money.dart';
import '../../domain/credit/account.dart';
import '../../domain/credit/dues.dart';
import '../../domain/credit/ledger.dart';
import '../context.dart';
import '../db/app_database.dart';
import '../ids.dart';
import 'ledger_repo.dart';
import 'return_repo.dart' show ReturnRepo;

class PurchaseReturnableLine {
  const PurchaseReturnableLine({required this.purchaseLineId, required this.productId, required this.name, required this.unit, required this.boughtMilli, required this.returnedMilli, required this.ratePaise, required this.gstBp, required this.totalPaise, required this.returnedPaise, required this.inStockMilli});
  final String purchaseLineId, productId, name, unit;
  final int boughtMilli, returnedMilli, ratePaise, gstBp, totalPaise, returnedPaise, inStockMilli;

  /// What can still go back: not more than is left of the purchase and not more than is in stock.
  int get remainingMilli => boughtMilli - returnedMilli;
  int get maxNowMilli => remainingMilli < inStockMilli ? remainingMilli : (inStockMilli < 0 ? 0 : inStockMilli);
}

class PurchaseReturnable {
  const PurchaseReturnable({required this.purchaseId, required this.number, required this.dealerId, required this.dealerName, required this.at, required this.received, required this.totalPaise, required this.outstandingPaise, required this.lines});
  final String purchaseId, number, dealerId, dealerName;
  final DateTime at;
  final bool received;
  final int totalPaise;

  /// What the shop still owes the dealer on THIS purchase (a return is taken off it first).
  final int outstandingPaise;
  final List<PurchaseReturnableLine> lines;
  bool get anythingLeft => lines.any((l) => l.remainingMilli > 0);
}

class SavePurchaseReturnInput {
  const SavePurchaseReturnInput({required this.idemKey, required this.purchaseId, required this.at, required this.lines, required this.reason, this.refundMode = 0, this.keepAsCredit = false});
  final String idemKey, purchaseId, reason;
  final DateTime at;

  /// purchaseLineId -> quantity going back (thousandths).
  final Map<String, int> lines;
  final int refundMode; // 0 cash, 1 UPI, 2 card
  final bool keepAsCredit;
}

class SavedPurchaseReturn {
  const SavedPurchaseReturn({required this.id, required this.number, required this.purchaseNo, required this.totalPaise, required this.dueReducedPaise, required this.creditKeptPaise, required this.refundedPaise, required this.replay});
  final String id, number, purchaseNo;
  final int totalPaise, dueReducedPaise, creditKeptPaise, refundedPaise;
  final bool replay;
}

class PurchaseReturnRow {
  const PurchaseReturnRow({required this.id, required this.number, required this.purchaseNo, required this.dealerName, required this.at, required this.totalPaise, required this.reason, required this.dueReducedPaise, required this.creditKeptPaise, required this.refundedPaise, required this.items});
  final String id, number, purchaseNo, dealerName, reason;
  final DateTime at;
  final int totalPaise, dueReducedPaise, creditKeptPaise, refundedPaise, items;
}

class PurchaseReturnRepo {
  PurchaseReturnRepo(this.cx, this.ledger);
  final DataContext cx;
  final LedgerRepo ledger;
  AppDatabase get _db => cx.db;

  Future<String?> purchaseIdByNumber(String number) async => (await _db.row('SELECT id FROM purchases WHERE number = ? COLLATE NOCASE', [number.trim()]))?.read<String>('id');

  Future<int> returnedTotal(String purchaseId) => _db.scalarInt('SELECT COALESCE(SUM(total_paise), 0) FROM purchase_returns WHERE purchase_id = ?', [purchaseId]);

  Future<PurchaseReturnable?> returnable(String purchaseId) async {
    final p = await _db.row('SELECT * FROM purchases WHERE id = ?', [purchaseId]);
    if (p == null) return null;
    final ls = await _db.rows(
        'SELECT l.*, COALESCE((SELECT SUM(r.qty_milli) FROM purchase_return_lines r WHERE r.purchase_line_id = l.id), 0) AS back, '
        'COALESCE((SELECT SUM(r.amount_paise) FROM purchase_return_lines r WHERE r.purchase_line_id = l.id), 0) AS back_amt, '
        'COALESCE((SELECT qty_milli FROM stock_cache s WHERE s.product_id = l.product_id), 0) AS in_stock '
        'FROM purchase_lines l WHERE l.purchase_id = ? ORDER BY l.line_no',
        [purchaseId]);
    final dealerId = p.read<String>('dealer_id');
    final number = p.read<String>('number');
    final outstanding = await _db.scalarInt('SELECT COALESCE(SUM(total_paise - paid_paise), 0) FROM party_bills WHERE party_id = ? AND bill_no = ? AND cancelled = 0', [dealerId, number]);
    return PurchaseReturnable(
      purchaseId: purchaseId,
      number: number,
      dealerId: dealerId,
      dealerName: p.read<String>('dealer_name'),
      at: DateTime.fromMillisecondsSinceEpoch(p.read<int>('purchased_at')),
      received: p.read<int>('status') == 1,
      totalPaise: p.read<int>('total_paise'),
      outstandingPaise: outstanding,
      lines: [
        for (final l in ls)
          PurchaseReturnableLine(
            purchaseLineId: l.read<String>('id'),
            productId: l.read<String>('product_id'),
            name: l.read<String>('name'),
            unit: l.read<String>('unit'),
            boughtMilli: l.read<int>('qty_milli'),
            returnedMilli: l.read<int>('back'),
            ratePaise: l.read<int>('rate_paise'),
            gstBp: l.read<int>('gst_bp'),
            totalPaise: l.read<int>('total_paise'),
            returnedPaise: l.read<int>('back_amt'),
            inStockMilli: l.read<int>('in_stock'),
          ),
      ],
    );
  }

  /// What a return would be worth and how it would be settled (for the screen to show before saving; same rules as the save).
  static ({int total, int dueReduced, int creditKept, int refunded}) preview(PurchaseReturnable p, Map<String, int> qty, {bool keepAsCredit = false}) {
    var total = 0;
    for (final l in p.lines) {
      final q = qty[l.purchaseLineId] ?? 0;
      if (q > 0) total += ReturnRepo.share(l.totalPaise, l.boughtMilli, l.returnedPaise, l.returnedMilli, q);
    }
    final due = total < p.outstandingPaise ? total : p.outstandingPaise;
    final rest = total - due;
    return (total: total, dueReduced: due, creditKept: keepAsCredit ? rest : 0, refunded: keepAsCredit ? 0 : rest);
  }

  Future<SavedPurchaseReturn> saveReturn(SavePurchaseReturnInput input) async {
    if (input.reason.trim().isEmpty) throw ArgumentError('A return needs a reason.');
    if (input.refundMode < 0 || input.refundMode > 2) throw ArgumentError('Unknown refund method.');
    return _db.transaction(() async {
      final dup = await _db.row('SELECT * FROM purchase_returns WHERE idem_key = ?', [input.idemKey]);
      if (dup != null) return _saved(dup, replay: true);

      final p = await _db.row('SELECT * FROM purchases WHERE id = ?', [input.purchaseId]);
      if (p == null) throw StateError('No such purchase.');
      if (p.read<int>('status') != 1) throw StateError('This purchase has not been received yet, so nothing can be returned from it.');
      final purchaseNo = p.read<String>('number');
      final dealerId = p.read<String>('dealer_id');
      final at = input.at.millisecondsSinceEpoch;

      final ls = await _db.rows(
          'SELECT l.*, COALESCE((SELECT SUM(r.qty_milli) FROM purchase_return_lines r WHERE r.purchase_line_id = l.id), 0) AS back_qty, '
          'COALESCE((SELECT SUM(r.amount_paise) FROM purchase_return_lines r WHERE r.purchase_line_id = l.id), 0) AS back_amt, '
          'COALESCE((SELECT SUM(r.taxable_paise) FROM purchase_return_lines r WHERE r.purchase_line_id = l.id), 0) AS back_taxable '
          'FROM purchase_lines l WHERE l.purchase_id = ? ORDER BY l.line_no',
          [input.purchaseId]);
      final byId = {for (final l in ls) l.read<String>('id'): l};
      for (final id in input.lines.keys) {
        if (!byId.containsKey(id)) throw StateError('A line does not belong to this purchase.');
      }
      final picked = <({QueryRow l, int qty, int amount, int taxable})>[];
      final perProduct = <String, int>{};
      for (final l in ls) {
        final id = l.read<String>('id');
        final bought = l.read<int>('qty_milli');
        final back = l.read<int>('back_qty');
        final qty = input.lines[id] ?? 0;
        if (qty < 0) throw ArgumentError('A quantity cannot be negative.');
        if (qty > bought - back) throw StateError('More than what is left of the purchase cannot be returned (${l.read<String>('name')}).');
        if (qty > 0) {
          picked.add((
            l: l,
            qty: qty,
            amount: ReturnRepo.share(l.read<int>('total_paise'), bought, l.read<int>('back_amt'), back, qty),
            taxable: ReturnRepo.share(l.read<int>('taxable_paise'), bought, l.read<int>('back_taxable'), back, qty),
          ));
          perProduct[l.read<String>('product_id')] = (perProduct[l.read<String>('product_id')] ?? 0) + qty;
        }
      }
      if (picked.isEmpty) throw ArgumentError('Choose at least one item to return.');
      for (final e in perProduct.entries) {
        final have = await _db.scalarInt('SELECT COALESCE(qty_milli, 0) FROM stock_cache WHERE product_id = ?', [e.key]);
        if (e.value > have) {
          final name = picked.firstWhere((x) => x.l.read<String>('product_id') == e.key).l.read<String>('name');
          throw StateError('Only ${formatQty(have < 0 ? 0 : have)} of $name is in stock, so ${formatQty(e.value)} cannot be returned.');
        }
      }

      var total = 0, taxable = 0;
      for (final x in picked) {
        total += x.amount;
        taxable += x.taxable;
      }
      final tax = total - taxable;
      if (tax < 0) throw StateError('The return does not add up; nothing was saved.');

      final outstanding = await _db.scalarInt('SELECT COALESCE(SUM(total_paise - paid_paise), 0) FROM party_bills WHERE party_id = ? AND bill_no = ? AND cancelled = 0', [dealerId, purchaseNo]);
      final dueReduced = total < outstanding ? total : outstanding;
      final rest = total - dueReduced;
      final creditKept = input.keepAsCredit ? rest : 0;
      final refunded = input.keepAsCredit ? 0 : rest;

      final id = newId();
      final legacy = await _db.scalarInt("SELECT COUNT(*) FROM records WHERE kind = 'purchaseReturns'");
      await _db.exec("INSERT INTO counters(name, value) VALUES ('rec.purchaseReturns', ?) ON CONFLICT(name) DO UPDATE SET value = MAX(value, excluded.value)", [legacy]);
      final number = 'PRT-${(await nextCounter(_db, 'rec.purchaseReturns')).toString().padLeft(4, '0')}';
      await _db.exec(
        'INSERT INTO purchase_returns(id, number, purchase_id, purchase_no, dealer_id, dealer_name, returned_at, day, total_paise, taxable_paise, tax_paise, due_reduced_paise, credit_kept_paise, refunded_paise, refund_mode, reason, by_name, idem_key, created_at, device_id) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [id, number, input.purchaseId, purchaseNo, dealerId, p.read<String>('dealer_name'), at, DataContext.dayOf(input.at), total, taxable, tax, dueReduced, creditKept, refunded, input.refundMode, input.reason.trim(), cx.actor.name, input.idemKey, cx.nowMs(), cx.deviceId],
      );
      for (final x in picked) {
        final l = x.l;
        final pid = l.read<String>('product_id');
        await _db.exec(
          'INSERT INTO purchase_return_lines(id, return_id, purchase_line_id, product_id, name, unit, qty_milli, amount_paise, taxable_paise, tax_paise) VALUES (?,?,?,?,?,?,?,?,?,?)',
          [newId(), id, l.read<String>('id'), pid, l.read<String>('name'), l.read<String>('unit'), x.qty, x.amount, x.taxable, x.amount - x.taxable],
        );
        await _db.exec('INSERT INTO stock_movements(id, product_id, qty_milli, kind, ref_id, unit_cost_paise, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?)', [newId(), pid, -x.qty, 'purchase_return', id, l.read<int>('rate_paise'), at, cx.nowMs(), cx.deviceId]);
        await _db.exec('INSERT INTO stock_cache(product_id, qty_milli) VALUES (?,?) ON CONFLICT(product_id) DO UPDATE SET qty_milli = qty_milli + excluded.qty_milli', [pid, -x.qty]);
      }

      if (dueReduced + creditKept > 0) {
        final entry = LedgerEntry(
          id: newId(),
          customerId: dealerId,
          kind: LedgerKind.returnCredit,
          amountPaise: -(dueReduced + creditKept),
          at: input.at,
          billNo: purchaseNo,
          note: '$number: ${input.reason.trim()}',
          by: cx.actor.name,
          allocations: dueReduced > 0 ? [Allocation(purchaseNo, dueReduced)] : const [],
        );
        await ledger.addEntry(_db, PartyKind.dealer, entry, refId: id, upload: true);
        if (dueReduced > 0) {
          final open = await ledger.dues(dealerId, tx: _db, openOnly: true);
          final BillDue due = open.firstWhere((d) => d.billNo == purchaseNo);
          await ledger.putDue(_db, PartyKind.dealer, dealerId, due.paid(dueReduced));
        }
      }

      await enqueue(cx, _db, 'purchaseReturns', id);
      await _db.exec(
        'INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)',
        [newId(), 'purchaseReturn', 'purchase', input.purchaseId, 'return', '', '$number ${input.reason.trim()}', cx.actor.name, cx.nowMs(), cx.deviceId],
      );
      return _saved((await _db.row('SELECT * FROM purchase_returns WHERE id = ?', [id]))!, replay: false);
    });
  }

  SavedPurchaseReturn _saved(QueryRow r, {required bool replay}) => SavedPurchaseReturn(
        id: r.read<String>('id'),
        number: r.read<String>('number'),
        purchaseNo: r.read<String>('purchase_no'),
        totalPaise: r.read<int>('total_paise'),
        dueReducedPaise: r.read<int>('due_reduced_paise'),
        creditKeptPaise: r.read<int>('credit_kept_paise'),
        refundedPaise: r.read<int>('refunded_paise'),
        replay: replay,
      );

  Future<List<PurchaseReturnRow>> list({int limit = 1000}) async {
    final r = await _db.rows(
        'SELECT r.*, (SELECT COUNT(*) FROM purchase_return_lines l WHERE l.return_id = r.id) AS items FROM purchase_returns r ORDER BY r.returned_at DESC, r.id DESC LIMIT ?',
        [limit]);
    return [
      for (final x in r)
        PurchaseReturnRow(
          id: x.read<String>('id'),
          number: x.read<String>('number'),
          purchaseNo: x.read<String>('purchase_no'),
          dealerName: x.read<String>('dealer_name'),
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
