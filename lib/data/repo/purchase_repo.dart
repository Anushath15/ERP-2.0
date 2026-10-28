/// Purchases from dealers with their items. The rules (docs/data-model.md, "Schema version 5"):
///  - a rate is per unit WITHOUT GST; an item's total is quantity x rate plus its GST, a purchase's total is the sum of its items;
///  - a RECEIVED purchase puts the stock in (a movement of kind 'purchase') and the unpaid part on the dealer's account; a PENDING one
///    does neither until it is marked received (then it does both, on that day);
///  - optionally the rates become the products' buying price (kept without GST);
///  - everything in ONE transaction, with a gapless number from the counter and an idempotency key (a retry writes nothing);
///  - what the shop paid before is remembered: for any product, the last rate and the cheapest other dealer can be looked up.
library;

import 'package:drift/drift.dart' show QueryRow;
import '../../core/money.dart';
import '../../domain/credit/account.dart';
import '../context.dart';
import '../db/app_database.dart';
import '../../domain/average_cost.dart';
import '../../domain/margin.dart';
import '../ids.dart';
import 'ledger_repo.dart';

class PurchaseLineInput {
  const PurchaseLineInput({required this.productId, required this.name, required this.unit, required this.qtyMilli, required this.ratePaise, required this.gstBp, this.grossPaise, this.sellPaise, this.mrpPaise});
  final String productId, name, unit;

  /// A selling price and an MRP the person typed for this item (null = leave it: the selling price then follows the buying price by the old margin). They are
  /// set on the product when the purchase is received.
  final int? sellPaise, mrpPaise;
  final int qtyMilli, ratePaise, gstBp;

  /// What the line costs WITH GST, exactly as typed (quantity x the rate typed with GST), when the rates were typed with GST. The rate kept without GST is
  /// rounded to the paisa, so working the line back from it can be a few paise off; the line is worked from this figure instead.
  final int? grossPaise;

  int get total => grossPaise ?? taxable + tax;
  int get taxable => grossPaise == null ? lineAmount(ratePaise, qtyMilli) : divRound(grossPaise! * 10000, 10000 + gstBp);
  int get tax => grossPaise == null ? divRound(lineAmount(ratePaise, qtyMilli) * gstBp, 10000) : grossPaise! - taxable;
}

class SavePurchaseInput {
  const SavePurchaseInput({required this.idemKey, required this.dealerId, required this.at, required this.lines, this.invoiceNo = '', this.paidPaise = 0, this.received = true, this.updateCost = true, this.note = '', this.payMode = 0});
  final String idemKey, dealerId, invoiceNo, note;
  final DateTime at;
  final List<PurchaseLineInput> lines;

  /// Money paid to the dealer now (0 up to the total); the rest goes on the dealer's account when the purchase is received.
  final int paidPaise;
  final bool received;

  /// Make these rates the products' buying price when the stock comes in.
  final bool updateCost;

  /// How the money paid now was paid: 0 cash, 1 UPI, 2 card, 3 bank transfer (the day's cash book counts only the cash).
  final int payMode;

  int get total => lines.fold<int>(0, (s, l) => s + l.total);
}

class SavedPurchase {
  const SavedPurchase({required this.id, required this.number, required this.totalPaise, required this.paidPaise, required this.received, required this.replay});
  final String id, number;
  final int totalPaise, paidPaise;
  final bool received, replay;
}

/// A line of the purchases list.
class PurchaseRow {
  const PurchaseRow({required this.id, required this.number, required this.dealerId, required this.dealerName, required this.invoiceNo, required this.at, required this.totalPaise, required this.paidPaise, required this.received, required this.items});
  final String id, number, dealerId, dealerName, invoiceNo;
  final DateTime at;
  final int totalPaise, paidPaise, items;
  final bool received;
  int get unpaidPaise => totalPaise - paidPaise;
}

/// A rate the shop paid (or was quoted) for a product.
class RateNote {
  const RateNote({required this.dealerId, required this.dealerName, required this.ratePaise, required this.at});
  final String dealerId, dealerName;
  final int ratePaise;
  final DateTime at;
}

class PurchaseLineView {
  const PurchaseLineView({required this.productId, required this.name, required this.unit, required this.qtyMilli, required this.ratePaise, required this.gstBp, required this.totalPaise, required this.sellingPaise, required this.lastBefore, required this.cheaper});
  final String productId, name, unit;
  final int qtyMilli, ratePaise, gstBp, totalPaise;

  /// The product's selling price now (what the shop marked), 0 when the product is gone.
  final int sellingPaise;

  /// The rate paid the time before (any dealer), and the cheapest other dealer's latest rate when it is lower than this one.
  final RateNote? lastBefore, cheaper;
}

class PurchaseDetail {
  const PurchaseDetail({required this.row, required this.lines, required this.note, required this.receivedAt, required this.taxPaise, this.updateCost = true, this.payMode = 0});
  final PurchaseRow row;
  final List<PurchaseLineView> lines;
  final String note;
  final DateTime? receivedAt;
  final int taxPaise;

  /// Whether the buying prices followed this purchase's rates.
  final bool updateCost;
  final int payMode;
}

class DealerSummary {
  const DealerSummary({required this.purchases, required this.pending, required this.boughtPaise, required this.paidPaise, required this.lastAt});
  final int purchases, pending, boughtPaise, paidPaise;
  final DateTime? lastAt;
}

class PurchaseRepo {
  PurchaseRepo(this.cx, this.ledger);
  final DataContext cx;
  final LedgerRepo ledger;
  AppDatabase get _db => cx.db;

  static DateTime _at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

  static PurchaseRow _row(QueryRow r) => PurchaseRow(
        id: r.read<String>('id'),
        number: r.read<String>('number'),
        dealerId: r.read<String>('dealer_id'),
        dealerName: r.read<String>('dealer_name'),
        invoiceNo: r.read<String>('invoice_no'),
        at: _at(r.read<int>('purchased_at')),
        totalPaise: r.read<int>('total_paise'),
        paidPaise: r.read<int>('paid_paise'),
        received: r.read<int>('status') == 1,
        items: r.read<int>('items'),
      );

  static const _rowSelect = 'SELECT p.*, (SELECT COUNT(*) FROM purchase_lines l WHERE l.purchase_id = p.id) AS items FROM purchases p';

  Future<SavedPurchase> savePurchase(SavePurchaseInput input) async {
    if (input.lines.isEmpty) throw ArgumentError('Add at least one item to the purchase.');
    for (final l in input.lines) {
      if (l.qtyMilli <= 0) throw ArgumentError('The quantity of ${l.name} must be above zero.');
      if (l.ratePaise < 0) throw ArgumentError('The rate of ${l.name} cannot be negative.');
    }
    final total = input.total;
    if (input.paidPaise < 0 || input.paidPaise > total) throw ArgumentError('The money paid must be between zero and the total.');
    return _db.transaction(() async {
      final dup = await _db.row('$_rowSelect WHERE p.idem_key = ?', [input.idemKey]);
      if (dup != null) return _saved(dup, replay: true);

      final dealer = await _db.row('SELECT id, name FROM dealers WHERE id = ?', [input.dealerId]);
      if (dealer == null) throw StateError('No such dealer.');
      // the legacy list (older notes) already used some numbers: the new ones carry on after them
      final legacy = await _db.scalarInt("SELECT COUNT(*) FROM records WHERE kind = 'purchases'");
      await _db.exec("INSERT INTO counters(name, value) VALUES ('rec.purchases', ?) ON CONFLICT(name) DO UPDATE SET value = MAX(value, excluded.value)", [legacy]);
      String fmt(int n) => 'PUR-${n.toString().padLeft(5, '0')}';
      final number = fmt(await nextFreeNumber(_db, 'rec.purchases', table: 'purchases', format: fmt));
      final id = newId();
      final at = input.at.millisecondsSinceEpoch;
      final taxable = input.lines.fold<int>(0, (s, l) => s + l.taxable);
      await _db.exec(
        'INSERT INTO purchases(id, number, dealer_id, dealer_name, invoice_no, purchased_at, day, total_paise, taxable_paise, tax_paise, paid_paise, status, update_cost, note, idem_key, by_name, created_at, device_id, line_count, pay_mode) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,0,?,?,?,?,?,?,?,?)',
        [id, number, input.dealerId, dealer.read<String>('name'), input.invoiceNo.trim(), at, DataContext.dayOf(input.at), total, taxable, total - taxable, input.paidPaise, input.updateCost ? 1 : 0, input.note.trim(), input.idemKey, cx.actor.name, cx.nowMs(), cx.deviceId, input.lines.length, input.payMode],
      );
      for (var i = 0; i < input.lines.length; i++) {
        final l = input.lines[i];
        await _db.exec(
          'INSERT INTO purchase_lines(id, purchase_id, line_no, product_id, name, unit, qty_milli, rate_paise, gst_bp, taxable_paise, tax_paise, total_paise) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
          [newId(), id, i + 1, l.productId, l.name, l.unit, l.qtyMilli, l.ratePaise, l.gstBp, l.taxable, l.tax, l.total],
        );
      }
      if (input.received) {
        await _receive(id, input.at);
        await _applyPrices(input.lines);
      }
      await enqueue(cx, _db, 'purchases', id);
      await _db.exec(
        'INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)',
        [newId(), 'purchase', 'purchase', id, 'status', '', input.received ? 'received' : 'pending', cx.actor.name, cx.nowMs(), cx.deviceId],
      );
      return _saved((await _db.row('$_rowSelect WHERE p.id = ?', [id]))!, replay: false);
    });
  }

  /// The stock comes in, the buying prices follow when asked, and the unpaid part goes on the dealer's account.
  Future<void> _receive(String id, DateTime when) async {
    final p = (await _db.row('SELECT * FROM purchases WHERE id = ?', [id]))!;
    final lines = await _db.rows('SELECT * FROM purchase_lines WHERE purchase_id = ? ORDER BY line_no', [id]);
    final ms = when.millisecondsSinceEpoch;
    for (final l in lines) {
      final pid = l.read<String>('product_id');
      final qty = l.read<int>('qty_milli');
      await _applyAverage(pid, qty, l.read<int>('rate_paise')); // before the stock goes up: the average is of what was there and what comes in
      await _db.exec('INSERT INTO stock_movements(id, product_id, qty_milli, kind, ref_id, unit_cost_paise, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?)', [newId(), pid, qty, 'purchase', id, l.read<int>('rate_paise'), ms, cx.nowMs(), cx.deviceId]);
      await _db.exec('INSERT INTO stock_cache(product_id, qty_milli) VALUES (?,?) ON CONFLICT(product_id) DO UPDATE SET qty_milli = qty_milli + excluded.qty_milli', [pid, qty]);
      if (p.read<int>('update_cost') == 1) await _applyCost(pid, l.read<int>('rate_paise'));
    }
    await ledger.addBillCredit(_db, PartyKind.dealer, partyId: p.read<String>('dealer_id'), billNo: p.read<String>('number'), at: when, total: p.read<int>('total_paise'), received: p.read<int>('paid_paise'));
    await _db.exec('UPDATE purchases SET status = 1, received_at = ? WHERE id = ?', [ms, id]);
  }

  /// The moving-average buying cost (what Tally, Zoho Inventory and ERPNext value stock at): when [inQty] comes in at [rate], the average becomes
  /// (stock now x average + inQty x rate) / (stock now + inQty), to the paisa. With no stock in hand (or less) the new rate is the average; with no
  /// average known yet the latest buying price stands in for it. Selling does not change the average; only buying does.
  Future<void> _applyAverage(String pid, int inQty, int rate) async {
    if (inQty <= 0 || rate <= 0) return;
    final row = await _db.row('SELECT p.avg_cost_paise AS avg_c, p.cost_paise AS cost, COALESCE(s.qty_milli, 0) AS qty FROM products p LEFT JOIN stock_cache s ON s.product_id = p.id WHERE p.id = ?', [pid]);
    if (row == null) return;
    final have = row.read<int>('qty');
    final base = row.read<int>('avg_c') > 0 ? row.read<int>('avg_c') : row.read<int>('cost');
    final next = movingAverage(haveMilli: have, haveCost: base, inMilli: inQty, inCost: rate);
    if (next == row.read<int>('avg_c')) return;
    await _db.exec('UPDATE products SET avg_cost_paise = ?, updated_at = ?, version = version + 1, hlc = ?, device_id = ? WHERE id = ?', [next, cx.nowMs(), cx.hlc.next(), cx.deviceId, pid]);
    await enqueue(cx, _db, 'products', pid);
  }

  /// The selling price and the MRP typed on the purchase become the product's own (after the buying price has moved the selling price by the old margin,
  /// so what was typed wins). Each change is written to the audit trail.
  Future<void> _applyPrices(List<PurchaseLineInput> lines) async {
    for (final l in lines) {
      if (l.sellPaise == null && l.mrpPaise == null) continue;
      final row = await _db.row('SELECT price_paise, mrp_paise FROM products WHERE id = ?', [l.productId]);
      if (row == null) continue;
      var changed = false;
      Future<void> set(String col, String field, int old, int? now) async {
        if (now == null || now < 0 || now == old) return;
        await _db.exec('UPDATE products SET $col = ?, updated_at = ?, version = version + 1, hlc = ?, device_id = ? WHERE id = ?', [now, cx.nowMs(), cx.hlc.next(), cx.deviceId, l.productId]);
        await _db.exec('INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)', [newId(), field, 'product', l.productId, field, '$old', '$now', cx.actor.name, cx.nowMs(), cx.deviceId]);
        changed = true;
      }

      await set('price_paise', 'price', row.read<int>('price_paise'), l.sellPaise);
      await set('mrp_paise', 'mrp', row.read<int>('mrp_paise'), l.mrpPaise);
      if (changed) await enqueue(cx, _db, 'products', l.productId);
    }
  }

  /// The product's buying price becomes [rate] (without GST) and its selling price follows by the same ratio, so the margin stays what it was. Does nothing when
  /// the buying price already is [rate].
  Future<void> _applyCost(String pid, int rate) async {
    final before = await _db.scalarInt('SELECT cost_paise FROM products WHERE id = ?', [pid]);
    if (before == rate) return;
    await _db.exec('UPDATE products SET cost_paise = ?, updated_at = ?, version = version + 1, hlc = ?, device_id = ? WHERE id = ?', [rate, cx.nowMs(), cx.hlc.next(), cx.deviceId, pid]);
    await _db.exec('INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)', [newId(), 'cost', 'product', pid, 'cost', '$before', '$rate', cx.actor.name, cx.nowMs(), cx.deviceId]);
    final oldSell = await _db.scalarInt('SELECT price_paise FROM products WHERE id = ?', [pid]);
    final newSell = sellingPriceKeepingMargin(oldCost: before, newCost: rate, oldSell: oldSell);
    if (newSell != oldSell) {
      await _db.exec('UPDATE products SET price_paise = ? WHERE id = ?', [newSell, pid]);
      await _db.exec('INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)', [newId(), 'price', 'product', pid, 'price', '$oldSell', '$newSell', cx.actor.name, cx.nowMs(), cx.deviceId]);
    }
    await enqueue(cx, _db, 'products', pid);
  }

  /// Changes a saved purchase in place (the same number): the items, rates, invoice number, note, what was paid. The dealer cannot be changed.
  ///  * A PENDING purchase has had no effect yet, so it is simply replaced.
  ///  * A RECEIVED one: the stock moves by the DIFFERENCE per product (a stock change, never an edit of the figure), the buying price follows the changed
  ///    rates when asked, and the dealer's account moves by the difference in what is still owed (a credit or a correction on the same bill).
  ///  * A purchase that already has a return keeps its items (the return refers to them): only the invoice number and the note can change.
  ///  * Payments made to the dealer since then count: the new total cannot be below what has been paid in all.
  Future<SavedPurchase> editPurchase(String purchaseId, SavePurchaseInput input) async {
    if (input.lines.isEmpty) throw ArgumentError('Add at least one item to the purchase.');
    for (final l in input.lines) {
      if (l.qtyMilli <= 0) throw ArgumentError('The quantity of ${l.name} must be above zero.');
      if (l.ratePaise < 0) throw ArgumentError('The rate of ${l.name} cannot be negative.');
    }
    final newTotal = input.total;
    if (input.paidPaise < 0 || input.paidPaise > newTotal) throw ArgumentError('The money paid must be between zero and the total.');
    return _db.transaction(() async {
      final p = await _db.row('SELECT * FROM purchases WHERE id = ?', [purchaseId]);
      if (p == null) throw StateError('No such purchase.');
      final dealerId = p.read<String>('dealer_id');
      if (dealerId != input.dealerId) throw StateError('The dealer of a purchase cannot be changed. Make a return and a new purchase instead.');
      final received = p.read<int>('status') == 1;
      final number = p.read<String>('number');
      final oldLines = await _db.rows('SELECT * FROM purchase_lines WHERE purchase_id = ? ORDER BY line_no', [purchaseId]);

      bool same() {
        if (oldLines.length != input.lines.length) return false;
        for (var i = 0; i < oldLines.length; i++) {
          final o = oldLines[i], n = input.lines[i];
          if (o.read<String>('product_id') != n.productId || o.read<int>('qty_milli') != n.qtyMilli || o.read<int>('rate_paise') != n.ratePaise || o.read<int>('gst_bp') != n.gstBp || o.read<int>('total_paise') != n.total) return false;
        }
        return true;
      }

      final linesSame = same();
      if (!linesSame && await _db.scalarInt('SELECT COUNT(*) FROM purchase_returns WHERE purchase_id = ?', [purchaseId]) > 0) {
        throw StateError('This purchase already has a return, so its items cannot be changed. You can still change the invoice number and the note.');
      }
      final oldTotal = p.read<int>('total_paise'), oldPaid = p.read<int>('paid_paise');
      final taxable = input.lines.fold<int>(0, (s, l) => s + l.taxable);
      final at = p.read<int>('purchased_at');
      final when = _at(at);

      if (received && (oldTotal != newTotal || oldPaid != input.paidPaise || !linesSame)) {
        // what the dealer has been paid since, through the bill-wise payments (reversed payments do not count)
        final later = await _db.scalarInt(
            r"SELECT COALESCE(SUM(json_extract(a.value, '$.p')), 0) FROM ledger_entries e, json_each(e.allocations) a WHERE e.party_id = ? AND json_extract(a.value, '$.b') = ? "
            'AND NOT EXISTS (SELECT 1 FROM ledger_entries r WHERE r.reverses = e.id)',
            [dealerId, number]);
        // an earlier edit that lowered the amount owed is also recorded as an allocation: it must not count as money paid
        final corrections = await _db.scalarInt(
            r"SELECT COALESCE(SUM(json_extract(a.value, '$.p')), 0) FROM ledger_entries e, json_each(e.allocations) a WHERE e.party_id = ? AND e.kind = 'adjustment' AND e.note LIKE 'Purchase edited%' "
            r"AND json_extract(a.value, '$.b') = ? AND NOT EXISTS (SELECT 1 FROM ledger_entries r WHERE r.reverses = e.id)",
            [dealerId, number]);
        final paidSince = later - corrections;
        if (newTotal - input.paidPaise - paidSince < 0) {
          throw StateError('The dealer has been paid more than this new total since the purchase was made, so the total cannot be this low.');
        }
        // stock: the difference per product
        final net = <String, int>{};
        for (final o in oldLines) {
          net[o.read<String>('product_id')] = (net[o.read<String>('product_id')] ?? 0) - o.read<int>('qty_milli');
        }
        for (final n in input.lines) {
          net[n.productId] = (net[n.productId] ?? 0) + n.qtyMilli;
        }
        for (final e in net.entries) {
          if (e.value == 0) continue;
          final rate = input.lines.where((l) => l.productId == e.key).map((l) => l.ratePaise).firstOrNull ?? 0;
          if (e.value > 0) await _applyAverage(e.key, e.value, rate); // more came in: the average moves; less (a removal) leaves it as it was
          await _db.exec('INSERT INTO stock_movements(id, product_id, qty_milli, kind, ref_id, unit_cost_paise, note, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)', [newId(), e.key, e.value, 'purchase', purchaseId, rate, 'Purchase edited', cx.nowMs(), cx.nowMs(), cx.deviceId]);
          await _db.exec('INSERT INTO stock_cache(product_id, qty_milli) VALUES (?,?) ON CONFLICT(product_id) DO UPDATE SET qty_milli = qty_milli + excluded.qty_milli', [e.key, e.value]);
        }
        // the buying price follows a rate that changed (or an item that is new here)
        if (input.updateCost) {
          final was = {for (final o in oldLines) o.read<String>('product_id'): o.read<int>('rate_paise')};
          for (final n in input.lines) {
            if (was[n.productId] != n.ratePaise) await _applyCost(n.productId, n.ratePaise);
          }
        }
        await _applyPrices(input.lines);
        // the dealer's account: what is still owed changes by the difference
        final delta = (newTotal - input.paidPaise) - (oldTotal - oldPaid);
        await ledger.changeCredit(_db, PartyKind.dealer, partyId: dealerId, billNo: number, at: cx.now(), delta: delta, newTotal: newTotal, billDate: when);
      }

      // the items: written again (new ids), the purchase says how many there are now
      if (!linesSame) {
        await _db.exec('DELETE FROM purchase_lines WHERE purchase_id = ?', [purchaseId]);
        for (var i = 0; i < input.lines.length; i++) {
          final l = input.lines[i];
          await _db.exec('INSERT INTO purchase_lines(id, purchase_id, line_no, product_id, name, unit, qty_milli, rate_paise, gst_bp, taxable_paise, tax_paise, total_paise) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
              [newId(), purchaseId, i + 1, l.productId, l.name, l.unit, l.qtyMilli, l.ratePaise, l.gstBp, l.taxable, l.tax, l.total]);
        }
      }
      await _db.exec('UPDATE purchases SET invoice_no = ?, total_paise = ?, taxable_paise = ?, tax_paise = ?, paid_paise = ?, update_cost = ?, note = ?, line_count = ?, pay_mode = ? WHERE id = ?',
          [input.invoiceNo.trim(), newTotal, taxable, newTotal - taxable, input.paidPaise, input.updateCost ? 1 : 0, input.note.trim(), input.lines.length, input.payMode, purchaseId]);
      await enqueue(cx, _db, 'purchases', purchaseId);
      await _db.exec('INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)',
          [newId(), 'purchaseEdit', 'purchase', purchaseId, 'total', '$oldTotal', '$newTotal', cx.actor.name, cx.nowMs(), cx.deviceId]);
      return _saved((await _db.row('$_rowSelect WHERE p.id = ?', [purchaseId]))!, replay: false);
    });
  }

  /// A pending purchase arrives: stock and the dealer's account are updated now. Returns false when it was already received.
  Future<bool> markReceived(String purchaseId, {DateTime? at}) {
    return _db.transaction(() async {
      final p = await _db.row('SELECT status FROM purchases WHERE id = ?', [purchaseId]);
      if (p == null) throw StateError('No such purchase.');
      if (p.read<int>('status') == 1) return false;
      await _receive(purchaseId, at ?? cx.now());
      await enqueue(cx, _db, 'purchases', purchaseId);
      await _db.exec(
        'INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)',
        [newId(), 'purchase', 'purchase', purchaseId, 'status', 'pending', 'received', cx.actor.name, cx.nowMs(), cx.deviceId],
      );
      return true;
    });
  }

  SavedPurchase _saved(QueryRow r, {required bool replay}) {
    final row = _row(r);
    return SavedPurchase(id: row.id, number: row.number, totalPaise: row.totalPaise, paidPaise: row.paidPaise, received: row.received, replay: replay);
  }

  /// Newest first. [dealerId] limits it to one dealer.
  Future<List<PurchaseRow>> list({String? dealerId, int limit = 1000}) async {
    final r = await _db.rows('$_rowSelect ${dealerId == null ? '' : 'WHERE p.dealer_id = ?'} ORDER BY p.purchased_at DESC, p.id DESC LIMIT ?', [?dealerId, limit]);
    return [for (final x in r) _row(x)];
  }

  Future<String?> idOfNumber(String number) async => (await _db.row('SELECT id FROM purchases WHERE number = ?', [number]))?.read<String>('id');

  /// One purchase with its items, what the shop marked as the selling price now, the rate paid the time before and a cheaper dealer.
  Future<PurchaseDetail?> detail(String id) async {
    final r = await _db.row('$_rowSelect WHERE p.id = ?', [id]);
    if (r == null) return null;
    final row = _row(r);
    final ls = await _db.rows('SELECT l.*, p.price_paise AS sell FROM purchase_lines l LEFT JOIN products p ON p.id = l.product_id WHERE l.purchase_id = ? ORDER BY l.line_no', [id]);
    final views = <PurchaseLineView>[];
    for (final l in ls) {
      final pid = l.read<String>('product_id');
      final rate = l.read<int>('rate_paise');
      final before = await _db.row(
          'SELECT p.dealer_id, p.dealer_name, l.rate_paise, p.purchased_at FROM purchase_lines l JOIN purchases p ON p.id = l.purchase_id '
          'WHERE l.product_id = ? AND p.id <> ? AND (p.purchased_at < ? OR (p.purchased_at = ? AND p.id < ?)) ORDER BY p.purchased_at DESC, p.id DESC LIMIT 1',
          [pid, id, row.at.millisecondsSinceEpoch, row.at.millisecondsSinceEpoch, id]);
      final cheaper = await _cheaperElsewhere(pid, row.dealerId, rate);
      views.add(PurchaseLineView(
        productId: pid,
        name: l.read<String>('name'),
        unit: l.read<String>('unit'),
        qtyMilli: l.read<int>('qty_milli'),
        ratePaise: rate,
        gstBp: l.read<int>('gst_bp'),
        totalPaise: l.read<int>('total_paise'),
        sellingPaise: l.readNullable<int>('sell') ?? 0,
        lastBefore: before == null ? null : _note(before),
        cheaper: cheaper,
      ));
    }
    return PurchaseDetail(
      row: row,
      lines: views,
      note: r.read<String>('note'),
      receivedAt: r.readNullable<int>('received_at') == null ? null : _at(r.read<int>('received_at')),
      taxPaise: r.read<int>('tax_paise'),
      updateCost: r.read<int>('update_cost') == 1,
      payMode: r.read<int>('pay_mode'),
    );
  }

  static RateNote _note(QueryRow r) => RateNote(dealerId: r.read<String>('dealer_id'), dealerName: r.read<String>('dealer_name'), ratePaise: r.read<int>('rate_paise'), at: _at(r.read<int>('purchased_at')));

  /// The lowest latest-rate among the OTHER dealers when it is below [ratePaise].
  Future<RateNote?> _cheaperElsewhere(String productId, String dealerId, int ratePaise) async {
    final r = await _db.row(
        'SELECT dealer_id, dealer_name, rate_paise, purchased_at FROM ('
        'SELECT p.dealer_id, p.dealer_name, l.rate_paise, p.purchased_at, ROW_NUMBER() OVER (PARTITION BY p.dealer_id ORDER BY p.purchased_at DESC, p.id DESC) AS rn '
        'FROM purchase_lines l JOIN purchases p ON p.id = l.purchase_id WHERE l.product_id = ? AND p.dealer_id <> ?) '
        'WHERE rn = 1 AND rate_paise < ? ORDER BY rate_paise, purchased_at DESC LIMIT 1',
        [productId, dealerId, ratePaise]);
    return r == null ? null : _note(r);
  }

  /// For the purchase form, before saving: the last rate paid for the product (any dealer) and the cheaper dealer than [dealerId] at [ratePaise].
  Future<({RateNote? last, RateNote? cheaper})> rateHints(String productId, {required String dealerId, required int ratePaise}) async {
    final last = await _db.row(
        'SELECT p.dealer_id, p.dealer_name, l.rate_paise, p.purchased_at FROM purchase_lines l JOIN purchases p ON p.id = l.purchase_id WHERE l.product_id = ? ORDER BY p.purchased_at DESC, p.id DESC LIMIT 1',
        [productId]);
    return (last: last == null ? null : _note(last), cheaper: await _cheaperElsewhere(productId, dealerId, ratePaise));
  }

  /// What one dealer has sold the shop (received purchases) and how many are still pending.
  Future<DealerSummary> dealerSummary(String dealerId) async {
    final r = await _db.row(
        'SELECT COUNT(*) AS n, COALESCE(SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END), 0) AS pending, COALESCE(SUM(CASE WHEN status = 1 THEN total_paise ELSE 0 END), 0) AS bought, '
        'COALESCE(SUM(CASE WHEN status = 1 THEN paid_paise ELSE 0 END), 0) AS paid, MAX(purchased_at) AS last FROM purchases WHERE dealer_id = ?',
        [dealerId]);
    final last = r?.readNullable<int>('last');
    return DealerSummary(purchases: r?.read<int>('n') ?? 0, pending: r?.read<int>('pending') ?? 0, boughtPaise: r?.read<int>('bought') ?? 0, paidPaise: r?.read<int>('paid') ?? 0, lastAt: last == null ? null : _at(last));
  }
}
