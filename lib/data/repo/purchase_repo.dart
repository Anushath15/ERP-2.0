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
import '../ids.dart';
import 'ledger_repo.dart';

class PurchaseLineInput {
  const PurchaseLineInput({required this.productId, required this.name, required this.unit, required this.qtyMilli, required this.ratePaise, required this.gstBp});
  final String productId, name, unit;
  final int qtyMilli, ratePaise, gstBp;

  int get taxable => lineAmount(ratePaise, qtyMilli);
  int get tax => divRound(taxable * gstBp, 10000);
  int get total => taxable + tax;
}

class SavePurchaseInput {
  const SavePurchaseInput({required this.idemKey, required this.dealerId, required this.at, required this.lines, this.invoiceNo = '', this.paidPaise = 0, this.received = true, this.updateCost = true, this.note = ''});
  final String idemKey, dealerId, invoiceNo, note;
  final DateTime at;
  final List<PurchaseLineInput> lines;

  /// Money paid to the dealer now (0 up to the total); the rest goes on the dealer's account when the purchase is received.
  final int paidPaise;
  final bool received;

  /// Make these rates the products' buying price when the stock comes in.
  final bool updateCost;

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
  const PurchaseDetail({required this.row, required this.lines, required this.note, required this.receivedAt, required this.taxPaise});
  final PurchaseRow row;
  final List<PurchaseLineView> lines;
  final String note;
  final DateTime? receivedAt;
  final int taxPaise;
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
      final number = 'PUR-${(await nextCounter(_db, 'rec.purchases')).toString().padLeft(5, '0')}';
      final id = newId();
      final at = input.at.millisecondsSinceEpoch;
      final taxable = input.lines.fold<int>(0, (s, l) => s + l.taxable);
      await _db.exec(
        'INSERT INTO purchases(id, number, dealer_id, dealer_name, invoice_no, purchased_at, day, total_paise, taxable_paise, tax_paise, paid_paise, status, update_cost, note, idem_key, by_name, created_at, device_id) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,0,?,?,?,?,?,?)',
        [id, number, input.dealerId, dealer.read<String>('name'), input.invoiceNo.trim(), at, DataContext.dayOf(input.at), total, taxable, total - taxable, input.paidPaise, input.updateCost ? 1 : 0, input.note.trim(), input.idemKey, cx.actor.name, cx.nowMs(), cx.deviceId],
      );
      for (var i = 0; i < input.lines.length; i++) {
        final l = input.lines[i];
        await _db.exec(
          'INSERT INTO purchase_lines(id, purchase_id, line_no, product_id, name, unit, qty_milli, rate_paise, gst_bp, taxable_paise, tax_paise, total_paise) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
          [newId(), id, i + 1, l.productId, l.name, l.unit, l.qtyMilli, l.ratePaise, l.gstBp, l.taxable, l.tax, l.total],
        );
      }
      if (input.received) await _receive(id, input.at);
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
      await _db.exec('INSERT INTO stock_movements(id, product_id, qty_milli, kind, ref_id, unit_cost_paise, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?)', [newId(), pid, qty, 'purchase', id, l.read<int>('rate_paise'), ms, cx.nowMs(), cx.deviceId]);
      await _db.exec('INSERT INTO stock_cache(product_id, qty_milli) VALUES (?,?) ON CONFLICT(product_id) DO UPDATE SET qty_milli = qty_milli + excluded.qty_milli', [pid, qty]);
      if (p.read<int>('update_cost') == 1) {
        final before = await _db.scalarInt('SELECT cost_paise FROM products WHERE id = ?', [pid]);
        final rate = l.read<int>('rate_paise');
        if (before != rate) {
          await _db.exec('UPDATE products SET cost_paise = ?, updated_at = ?, version = version + 1, hlc = ?, device_id = ? WHERE id = ?', [rate, cx.nowMs(), cx.hlc.next(), cx.deviceId, pid]);
          await _db.exec('INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)', [newId(), 'cost', 'product', pid, 'cost', '$before', '$rate', cx.actor.name, cx.nowMs(), cx.deviceId]);
          await enqueue(cx, _db, 'products', pid);
        }
      }
    }
    await ledger.addBillCredit(_db, PartyKind.dealer, partyId: p.read<String>('dealer_id'), billNo: p.read<String>('number'), at: when, total: p.read<int>('total_paise'), received: p.read<int>('paid_paise'));
    await _db.exec('UPDATE purchases SET status = 1, received_at = ? WHERE id = ?', [ms, id]);
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
    final r = await _db.rows('$_rowSelect ${dealerId == null ? '' : 'WHERE p.dealer_id = ?'} ORDER BY p.purchased_at DESC, p.id DESC LIMIT ?', [if (dealerId != null) dealerId, limit]);
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
