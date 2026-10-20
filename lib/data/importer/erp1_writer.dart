/// Writes a validated [Erp1Plan] into a NEW ERP 2.0 database, in one transaction (all of it or none of it), then rebuilds every summary from
/// the raw rows. Ids come from ERP 1 ids, so running it again changes nothing. Nothing is queued for upload: what goes to the cloud, and
/// when, is the owner's decision at the sync step.
library;

import '../repo/product_codes.dart';
import 'dart:convert';
import '../../import/erp1/plan.dart';
import '../../import/erp1/report.dart';
import '../app_data.dart';
import '../context.dart';
import '../repo/rebuild.dart';
import '../repo/records_repo.dart';

class WriteResult {
  WriteResult({required this.alreadyImported, required this.verified, required this.mismatches});
  final bool alreadyImported;
  final bool verified;
  final List<String> mismatches;
}

const _importKey = 'import.erp1';

Future<WriteResult> writePlan(AppData d, Erp1Plan p, {required int nowMs}) async {
  final db = d.db;
  final marker = await d.settings.get(_importKey);
  if (marker == null) {
    final used = await db.scalarInt('SELECT (SELECT COUNT(*) FROM products) + (SELECT COUNT(*) FROM customers) + (SELECT COUNT(*) FROM bills) + (SELECT COUNT(*) FROM dealers)');
    if (used > 0) throw ImportInputError('The database is not empty. An ERP 1 import goes only into a new, empty database. Nothing was changed.');
  }
  const dev = 'import';
  final now = nowMs;
  await db.transaction(() async {
    for (final c in p.categories.values) {
      await db.exec('INSERT OR IGNORE INTO categories(id, name, created_at, updated_at, device_id) VALUES (?,?,?,?,?)', [c.id, c.name, now, now, dev]);
    }
    for (final x in p.products.values) {
      await db.exec(
        'INSERT OR IGNORE INTO products(id, name, category, unit, price_paise, cost_paise, gst_bp, hsn, barcode, min_stock_milli, active, old_id, created_at, updated_at, deleted_at, device_id, avg_cost_paise, brand) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [x.id, x.name, x.category, x.unit, x.pricePaise, x.costPaise, x.gstBp, x.hsn, x.barcode, x.minStockMilli, x.active ? 1 : 0, x.oldId, x.createdMs > 0 ? x.createdMs : now, now, x.deleted ? now : null, dev, x.avgCostPaise, x.brand],
      );
    }
    for (final c in p.customers.values) {
      await db.exec(
        'INSERT OR IGNORE INTO customers(id, name, phone, city, address, gstin, credit_limit_paise, old_id, created_at, updated_at, deleted_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
        [c.id, c.name, c.phone, c.city, c.address, c.gstin, c.creditLimitPaise, c.oldId, c.createdMs > 0 ? c.createdMs : now, now, c.deleted ? now : null, dev],
      );
    }
    for (final c in p.dealers.values) {
      await db.exec(
        'INSERT OR IGNORE INTO dealers(id, name, phone, city, address, gstin, old_id, created_at, updated_at, deleted_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
        [c.id, c.name, c.phone, c.city, c.address, c.gstin, c.oldId, c.createdMs > 0 ? c.createdMs : now, now, c.deleted ? now : null, dev],
      );
    }
    for (final b in p.bills) {
      final cust = b.customerOldId == null ? null : p.customers[b.customerOldId]!.id;
      await db.exec(
        'INSERT OR IGNORE INTO bills(id, number, series, seq, billed_at, day, customer_id, customer_name, total_paise, received_paise, balance_paise, change_paise, advance_kept_paise, taxable_paise, cgst_paise, sgst_paise, igst_paise, discount_paise, round_off_paise, pay_mode, status, cancelled, item_count, prices_include_gst, idem_key, old_bill_no, note, created_by, created_at, device_id) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,0,0,?,?,?,?,?,?,?,0,?,?,?,?,?,?,?,?,?)',
        [b.id, b.oldNo, 'ERP1', b.seq, b.at.ms, b.at.day, cust, b.customerName, b.total, b.received, b.balance, b.taxable, b.cgst, b.sgst, b.igst, b.discount, b.roundOff, b.payMode, b.cancelled ? 1 : 0, b.lines.length, b.inclusive ? 1 : 0, 'e1-${b.oldNo}', b.oldNo, b.note, 'ERP 1', now, dev],
      );
      for (var i = 0; i < b.lines.length; i++) {
        final l = b.lines[i];
        await db.exec(
          'INSERT OR IGNORE INTO bill_lines(id, bill_id, line_no, product_id, name, unit, qty_milli, rate_paise, cost_paise, discount_bp, gst_bp, gross_paise, discount_paise, taxable_paise, tax_paise, total_paise) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
          ['e1-line-${b.oldNo}-${i + 1}', b.id, i + 1, p.products[l.productOldId]!.id, l.name.isEmpty ? p.products[l.productOldId]!.name : l.name, l.unit, l.qtyMilli, l.ratePaise, l.costPaise, l.discountBp, l.gstBp, l.grossPaise, l.discountPaise, l.taxablePaise, l.taxPaise, l.totalPaise],
        );
      }
      if (b.cancelled) {
        await db.exec('INSERT OR IGNORE INTO bill_cancellations(id, bill_id, bill_no, reason, by_name, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?)', ['e1-cancel-${b.oldNo}', b.id, b.oldNo, b.cancelReason.isEmpty ? 'Cancelled in ERP 1' : b.cancelReason, 'ERP 1', b.at.ms, now, dev]);
      } else if (cust != null && b.balance > 0) {
        await db.exec('INSERT OR IGNORE INTO party_bills(id, party_kind, party_id, bill_no, date, total_paise, paid_paise, cancelled) VALUES (?,?,?,?,?,?,?,0)', ['$cust|${b.oldNo}', 'customer', cust, b.oldNo, b.at.ms, b.total, b.total - b.balance]);
      }
    }
    for (final e in p.estimates) {
      final cust = e.customerOldId == null ? null : p.customers[e.customerOldId]!.id;
      final billId = e.convertedBillOldNo != null && p.bills.any((b) => b.oldNo == e.convertedBillOldNo) ? e.convertedBillOldNo : null;
      await db.exec(
        'INSERT OR IGNORE INTO estimations(id, number, at, customer_id, customer_name, total_paise, line_count, converted_bill_id, created_at, updated_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
        [e.id, e.number, e.at.ms, cust, e.customerName, e.totalPaise, e.lines.length, billId, now, now, dev],
      );
      for (var i = 0; i < e.lines.length; i++) {
        final l = e.lines[i];
        await db.exec(
          'INSERT OR IGNORE INTO estimation_lines(id, estimation_id, line_no, product_id, name, unit, qty_milli, rate_paise, discount_bp) VALUES (?,?,?,?,?,?,?,?,?)',
          ['e1-eline-${e.oldId}-${i + 1}', e.id, i + 1, p.products[l.productOldId]!.id, l.name, l.unit, l.qtyMilli, l.ratePaise, l.discountBp],
        );
      }
    }
    for (final e in p.entries) {
      await db.exec(
        'INSERT OR IGNORE INTO ledger_entries(id, party_kind, party_id, kind, amount_paise, at, bill_no, note, by_name, mode, allocations, running_paise, ref_id, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,0,?,?,?)',
        [e.id, e.partyKind, e.partyId, e.kind, e.amountPaise, e.atMs, e.billNo, e.note, 'ERP 1', e.mode, '[]', e.refId, now, dev],
      );
    }
    for (final x in p.payments) {
      await db.exec(
        'INSERT OR IGNORE INTO payments(id, party_kind, party_id, amount_paise, advance_paise, mode, at, note, receipt_no, allocations, by_name, created_at, device_id) VALUES (?,?,?,?,0,?,?,?,?,?,?,?,?)',
        [x.id, x.partyKind, x.partyId, x.amountPaise, x.mode, x.atMs, x.note, x.receiptNo, '[]', 'ERP 1', now, dev],
      );
    }
    for (final m in p.moves) {
      await db.exec('INSERT OR IGNORE INTO stock_movements(id, product_id, qty_milli, kind, ref_id, unit_cost_paise, at, note, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)', [m.id, m.productId, m.qtyMilli, m.kind, m.refId, m.unitCostPaise, m.atMs, m.note, now, dev]);
    }
    for (final r in p.records) {
      await db.exec('INSERT OR IGNORE INTO records(id, kind, data, at, created_at, updated_at, device_id) VALUES (?,?,?,?,?,?,?)', [r.id, r.kind, RecordsRepo.encode(r.fields), r.atMs, now, now, dev]);
    }
    for (final c in p.corrections) {
      await db.exec('INSERT OR IGNORE INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)', ['e1-corr-${c.billOldNo}', c.auditText, 'bill', 'e1-bill-${c.billOldNo}', 'balance_paise', '${c.amountPaise}', '0', 'Import from ERP 1', now, dev]);
    }
    await db.exec("INSERT INTO counters(name, value) VALUES ('inv.ERP1', ?) ON CONFLICT(name) DO UPDATE SET value = MAX(value, excluded.value)", [p.bills.length]);
    await _profile(d, p, now);
    await backfillProductCodes(db); // every imported product gets its program code (by category)
    await rebuildSummaries(db);
    await d.settings.put(_importKey, jsonEncode({'at': now, 'backup': p.backupStamp ?? '', 'bills': p.bills.length, 'products': p.products.length}));
  });
  final bad = await verifyAgainstPlan(d, p);
  return WriteResult(alreadyImported: marker != null, verified: bad.isEmpty, mismatches: bad);
}

Future<void> _profile(AppData d, Erp1Plan p, int now) async {
  if (p.settings.isEmpty) return;
  Map<String, Object?> cur = {};
  final raw = await d.settings.get('shop.profile');
  if (raw != null) {
    try {
      final j = jsonDecode(raw);
      if (j is Map<String, dynamic>) cur = j;
    } catch (_) {}
  }
  for (final k in const ['name', 'ownerName', 'address', 'phone', 'gstin', 'billFooter']) {
    final v = p.settings[k];
    if (v != null && '${cur[k] ?? ''}'.isEmpty) cur[k] = v;
  }
  await d.settings.put('shop.profile', jsonEncode(cur));
}

/// Reads the totals back from the database and compares them with the plan. Empty list = every figure agrees.
Future<List<String>> verifyAgainstPlan(AppData d, Erp1Plan p) async {
  final db = d.db;
  final r = Recon(p);
  final bad = <String>[];
  Future<void> eq(String what, int got, int want) async {
    if (got != want) bad.add('$what: database has $got, the backup says $want');
  }

  await eq('bills (not cancelled)', await db.scalarInt("SELECT COUNT(*) FROM bills WHERE cancelled = 0 AND series = 'ERP1'"), r.bills);
  await eq('bills cancelled', await db.scalarInt("SELECT COUNT(*) FROM bills WHERE cancelled = 1 AND series = 'ERP1'"), r.cancelledBills);
  await eq('sales total (paise)', await db.scalarInt("SELECT COALESCE(SUM(total_paise),0) FROM bills WHERE cancelled = 0 AND series = 'ERP1'"), r.salesPaise);
  await eq('day totals sales (paise)', await db.scalarInt('SELECT COALESCE(SUM(sales_paise),0) FROM day_totals'), r.salesPaise);
  await eq('customer payments (paise)', await db.scalarInt("SELECT COALESCE(SUM(amount_paise),0) FROM payments WHERE party_kind = 'customer'"), r.customerPaymentsPaise);
  await eq('products', await db.scalarInt("SELECT COUNT(*) FROM products WHERE old_id IS NOT NULL"), p.products.length);
  await eq('customers', await db.scalarInt('SELECT COUNT(*) FROM customers'), p.customers.length);
  await eq('dealers', await db.scalarInt('SELECT COUNT(*) FROM dealers'), p.dealers.length);
  var wantCust = 0, wantDeal = 0;
  for (final c in p.customers.values) {
    wantCust += c.outstandingPaise;
  }
  for (final c in p.dealers.values) {
    wantDeal += c.outstandingPaise;
  }
  await eq('customer balances (paise)', await db.scalarInt("SELECT COALESCE(SUM(balance_paise),0) FROM party_balance WHERE party_kind = 'customer'"), wantCust);
  await eq('dealer balances (paise)', await db.scalarInt("SELECT COALESCE(SUM(balance_paise),0) FROM party_balance WHERE party_kind = 'dealer'"), wantDeal);
  var wantStock = 0;
  for (final x in p.products.values) {
    wantStock += x.stockMilli;
  }
  await eq('stock quantity (milli)', await db.scalarInt('SELECT COALESCE(SUM(qty_milli),0) FROM stock_cache'), wantStock);
  return bad;
}

/// What a shop database holds, read from it (live rows only): used to show the owner what the new file contains.
Future<Map<String, int>> shopCounts(AppData d) async => {
      'products': await d.db.scalarInt('SELECT COUNT(*) FROM products WHERE deleted_at IS NULL'),
      'customers': await d.db.scalarInt('SELECT COUNT(*) FROM customers WHERE deleted_at IS NULL'),
      'dealers': await d.db.scalarInt('SELECT COUNT(*) FROM dealers WHERE deleted_at IS NULL'),
      'bills': await d.db.scalarInt('SELECT COUNT(*) FROM bills'),
      'estimates': await d.db.scalarInt('SELECT COUNT(*) FROM estimations'),
    };
