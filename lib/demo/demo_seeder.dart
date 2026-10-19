/// Fills a database with the made-up sample shop (the same data the prototype showed), through the real tables, so Demo mode and
/// the tests exercise the real code. Deterministic. Never used for the real shop's database.
library;

import '../data/repo/product_codes.dart';
import 'dart:convert';
import 'dart:math';
import '../data/app_data.dart';
import '../data/context.dart';
import '../domain/bill_math.dart';
import '../domain/credit/account.dart';
import '../domain/credit/ledger.dart';
import '../domain/models.dart';
import '../fake/shop_profile.dart';
import 'seed.dart';
import 'seed_credit.dart';

/// Deterministic fake lines for a sample document (a sample bill has no lines of its own).
List<CartLine> demoLines(String key, int count, List<Product> products) {
  var h = key.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7FFFFFFF);
  int next(int n) {
    h = (h * 1103515245 + 12345) & 0x7FFFFFFF;
    return (h >> 8) % n;
  }

  return [for (var i = 0; i < count; i++) CartLine(product: products[next(products.length)], qtyMilli: 1000 * (1 + next(5)))];
}

class DemoCounts {
  const DemoCounts({this.products = 757, this.customers = 5000, this.bills = 4000, this.estimates = 300});
  final int products, customers, bills, estimates;
}

/// Puts the sample shop in [d]. [now] is the sample "today" (bills and balances are dated relative to it).
Future<void> seedDemo(AppData d, DateTime now, {DemoCounts counts = const DemoCounts()}) async {
  final db = d.db;
  final cx = d.cx;
  final t = cx.nowMs();
  final products = seedProducts(count: counts.products);
  final customers = seedCustomers(count: counts.customers);
  final dealers = seedDealers();
  final byNameAll = {for (final p in products.reversed) p.name: p.id};
  final adjusted = seedAdjustments(now, products);
  final adjSum = <String, int>{};
  for (final r in adjusted) {
    final pid = byNameAll[r.s('product')];
    if (pid != null) adjSum[pid] = (adjSum[pid] ?? 0) + r.i('qty');
  }

  await db.transaction(() async {
    await d.settings.put('shop.profile', ShopProfile.sample.toJsonText());

    // categories
    await db.batch((b) {
      for (final c in categories) {
        b.customStatement('INSERT INTO categories(id, name, created_at, updated_at, device_id) VALUES (?,?,?,?,?)', ['cat-${c.toLowerCase()}', c, t, t, cx.deviceId]);
      }
    });

    // products (the first in the list is the newest: created_at counts down) and customers, dealers
    await db.batch((b) {
      for (var i = 0; i < products.length; i++) {
        final p = products[i];
        b.customStatement(
          'INSERT INTO products(id, name, category, unit, price_paise, cost_paise, gst_bp, hsn, barcode, min_stock_milli, created_at, updated_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
          [p.id, p.name, p.category, p.unit, p.pricePaise, p.costPaise, p.gstBp, p.hsn, p.barcode, p.minStockMilli, t - i, t - i, cx.deviceId],
        );
      }
      for (var i = 0; i < customers.length; i++) {
        final c = customers[i];
        b.customStatement('INSERT INTO customers(id, name, phone, city, address, credit_limit_paise, created_at, updated_at, device_id) VALUES (?,?,?,?,?,?,?,?,?)', [c.id, c.name, c.phone, c.city, c.address, c.creditLimitPaise, t - i, t - i, cx.deviceId]);
      }
      for (var i = 0; i < dealers.length; i++) {
        final r = dealers[i];
        b.customStatement('INSERT INTO dealers(id, name, phone, city, created_at, updated_at, device_id) VALUES (?,?,?,?,?,?,?)', [r.id, r.s('name'), r.s('phone'), r.s('city'), t - i, t - i, cx.deviceId]);
      }
    });

    // sample bills, with lines and sale movements; the opening stock is what makes the stock end where the sample says
    final book = BillBook(now, count: counts.bills, customers: customers);
    final sold = <String, int>{};
    final billRows = <List<Object?>>[];
    final cancelRows = <List<Object?>>[];
    final lineRows = <List<Object?>>[];
    final moveRows = <List<Object?>>[];
    final monthRows = <String, List<int>>{}; // 'product|month' -> qty, amount
    final dayRows = <String, List<int>>{}; // day -> bills, sales, taxable, cost, tax, cash, upi, card, credit
    for (var i = 0; i < counts.bills; i++) {
      final s = book.at(i);
      final lines = demoLines(s.number, s.items, products);
      final calc = calcBillIn([for (final l in lines) CalcLineIn(rate: l.rate, qtyMilli: l.qtyMilli, gstBp: l.product.gstBp)]);
      final total = s.totalPaise;
      final cancelled = s.status == DocStatus.cancelled;
      final balance = cancelled ? 0 : total - s.paidPaise;
      final id = 'demo-${s.number}';
      final seq = int.parse(s.number.substring(2));
      final modeIx = s.mode == PayMode.credit ? 0 : s.mode.index;
      final at = s.date.millisecondsSinceEpoch;
      billRows.add([id, s.number, 'A', seq, at, DataContext.dayOf(s.date), null, s.customer == 'Walk-in customer' ? '' : s.customer, total, cancelled ? total : s.paidPaise, balance, 0, 0, calc.taxable, calc.cgst, calc.sgst, calc.igst, calc.discount, calc.roundOff, modeIx, lines.length, 1, id, cancelled ? 1 : 0, 'Priya', t, cx.deviceId]);
      if (cancelled) cancelRows.add(['$id-x', id, s.number, 'Sample: wrong item billed', 'Owner', at, t, cx.deviceId]);
      for (var k = 0; k < lines.length; k++) {
        final l = lines[k];
        final c = calc.lines[k];
        lineRows.add(['$id-$k', id, k + 1, l.product.id, l.product.name, l.product.unit, l.qtyMilli, l.rate, l.product.costPaise, 0, l.product.gstBp, c.gross, 0, c.taxable, c.tax, c.total]);
        moveRows.add(['$id-m$k', l.product.id, -l.qtyMilli, 'sale', id, at, t, cx.deviceId]);
        sold[l.product.id] = (sold[l.product.id] ?? 0) + l.qtyMilli;
        if (cancelled) {
          moveRows.add(['$id-c$k', l.product.id, l.qtyMilli, 'cancel', id, at, t, cx.deviceId]);
          sold[l.product.id] = sold[l.product.id]! - l.qtyMilli;
        } else {
          final key = '${l.product.id}|${DataContext.monthOf(s.date)}';
          final m = monthRows.putIfAbsent(key, () => [0, 0]);
          m[0] += l.qtyMilli;
          m[1] += c.total;
        }
      }
      final day = dayRows.putIfAbsent(DataContext.dayOf(s.date), () => List.filled(11, 0));
      if (cancelled) {
        day[9] += 1;
        day[10] += total;
      } else {
        final settled = total - balance;
        day[0] += 1;
        day[1] += total;
        day[2] += calc.taxable;
        day[3] += lines.fold<int>(0, (a, l) => a + (l.product.costPaise * l.qtyMilli / 1000).round());
        day[4] += calc.tax;
        day[5] += modeIx == 0 ? settled : 0;
        day[6] += modeIx == 1 ? settled : 0;
        day[7] += modeIx >= 2 ? settled : 0;
        day[8] += balance;
      }
    }
    await db.batch((b) {
      for (final p in products) {
        final qty = p.stockMilli + (sold[p.id] ?? 0) - (adjSum[p.id] ?? 0);
        b.customStatement('INSERT INTO stock_cache(product_id, qty_milli) VALUES (?,?)', [p.id, p.stockMilli]);
        if (qty != 0) b.customStatement("INSERT INTO stock_movements(id, product_id, qty_milli, kind, note, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?)", ['open-${p.id}', p.id, qty, 'opening', 'Opening stock', now.subtract(const Duration(days: 4000)).millisecondsSinceEpoch, t, cx.deviceId]);
      }
      for (final r in billRows) {
        b.customStatement(
          'INSERT INTO bills(id, number, series, seq, billed_at, day, customer_id, customer_name, total_paise, received_paise, balance_paise, change_paise, advance_kept_paise, taxable_paise, cgst_paise, sgst_paise, igst_paise, discount_paise, round_off_paise, pay_mode, item_count, prices_include_gst, idem_key, cancelled, created_by, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
          r,
        );
      }
      for (final r in cancelRows) {
        b.customStatement('INSERT INTO bill_cancellations(id, bill_id, bill_no, reason, by_name, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?)', r);
      }
      for (final r in lineRows) {
        b.customStatement('INSERT INTO bill_lines(id, bill_id, line_no, product_id, name, unit, qty_milli, rate_paise, cost_paise, discount_bp, gst_bp, gross_paise, discount_paise, taxable_paise, tax_paise, total_paise) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)', r);
      }
      for (final r in moveRows) {
        b.customStatement('INSERT INTO stock_movements(id, product_id, qty_milli, kind, ref_id, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?)', r);
      }
      monthRows.forEach((k, v) {
        final parts = k.split('|');
        b.customStatement('INSERT INTO product_month(product_id, month, qty_milli, amount_paise) VALUES (?,?,?,?)', [parts[0], parts[1], v[0], v[1]]);
      });
      dayRows.forEach((k, v) {
        b.customStatement('INSERT INTO day_totals(day, bills, sales_paise, taxable_paise, cost_paise, tax_paise, cash_paise, upi_paise, card_paise, credit_paise, cancelled_bills, cancelled_paise) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', [k, ...v]);
      });
    });
    await db.exec("INSERT INTO counters(name, value) VALUES ('inv.A', ?)", [counts.bills > 0 ? max(20000, counts.bills) : 20000]);
    await db.exec("INSERT INTO counters(name, value) VALUES ('rcp.customer', 39), ('rcp.dealer', 39), ('est', ?), ('rec.purchases', 240), ('rec.salesReturns', 60), ('rec.purchaseReturns', 30)", [counts.estimates]);

    // credit: customers and dealers with balances (through the ledger, so balances, running figures and dues are all consistent)
    Future<void> account(PartyKind kind, String partyId, CreditAccount a) async {
      for (final e in a.ledger) {
        // the sample generator numbers its entries from 1 for each call: make the ids unique across customers and dealers
        final u = LedgerEntry(id: '${kind.name}-${e.id}', customerId: e.customerId, kind: e.kind, amountPaise: e.amountPaise, at: e.at, billNo: e.billNo, note: e.note, by: e.by, mode: e.mode, reverses: e.reverses, allocations: e.allocations);
        await d.ledger.addEntry(db, kind, u);
      }
      for (final x in a.bills) {
        await d.ledger.putDue(db, kind, partyId, x);
      }
    }

    final credit = seedCredit(customers, now);
    for (final e in credit.entries) {
      await account(PartyKind.customer, e.key, e.value);
    }
    final dealerCredit = seedCredit([for (final r in dealers) Customer(id: r.id, name: r.s('name'), phone: r.s('phone'), city: r.s('city'), balancePaise: r.i('balance'))], now, billPrefix: 'PUR-0', billBase: 15000, seed: 2031);
    for (final e in dealerCredit.entries) {
      await account(PartyKind.dealer, e.key, e.value);
    }

    // reminders
    final log = seedReminders(credit, now);
    await db.batch((b) {
      for (final r in log.records) {
        b.customStatement('INSERT INTO reminders(id, customer_id, at, amount_due_paise, message, by_name, created_at, device_id) VALUES (?,?,?,?,?,?,?,?)', [r.id, r.customerId, r.at.millisecondsSinceEpoch, r.amountDuePaise, r.message, r.by, t, cx.deviceId]);
      }
    });

    // estimates with their lines
    final est = seedEstimations(now, customers, count: counts.estimates);
    final estCount = est.length;
    await db.batch((b) {
      for (var i = 0; i < estCount; i++) {
        final e = est[i];
        final id = 'demo-${e.number}';
        b.customStatement(
          'INSERT INTO estimations(id, number, at, edited_on, customer_name, total_paise, line_count, converted_bill_id, created_at, updated_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
          [id, e.number, e.date.millisecondsSinceEpoch, e.editedOn?.millisecondsSinceEpoch, e.customer, e.totalPaise, e.lines, e.convertedTo, t, t, cx.deviceId],
        );
        final lines = demoLines(e.number, e.lines.clamp(1, 12), products);
        for (var k = 0; k < lines.length; k++) {
          final l = lines[k];
          b.customStatement('INSERT INTO estimation_lines(id, estimation_id, line_no, product_id, name, unit, qty_milli, rate_paise, discount_bp) VALUES (?,?,?,?,?,?,?,?,?)', ['$id-$k', id, k + 1, l.product.id, l.product.name, l.product.unit, l.qtyMilli, l.rate, 0]);
        }
      }
    });

    // small records
    Future<void> recs(String kind, List<Rec> list) async {
      await db.batch((b) {
        for (var i = 0; i < list.length; i++) {
          final r = list[i];
          final at = r.f['date'] is DateTime ? (r.f['date'] as DateTime).millisecondsSinceEpoch : (r.f['time'] is DateTime ? (r.f['time'] as DateTime).millisecondsSinceEpoch : t - i);
          b.customStatement('INSERT INTO records(id, kind, data, at, created_at, updated_at, device_id) VALUES (?,?,?,?,?,?,?)', [r.id, kind, _enc(r.f), at, t, t, cx.deviceId]);
        }
      });
    }

    await recs('purchases', seedPurchases(now, dealers));
    await recs('purchaseReturns', seedPurchaseReturns(now, dealers));
    await recs('salesReturns', seedSalesReturns(now, customers));
    await recs('delivery', seedDelivery(now, customers));
    await recs('expenses', seedExpenses(now));
    await recs('warranty', seedWarranty(now, customers, products));
    await recs('staff', seedStaff());
    await recs('notifications', seedNotifications(now));

    // stock changes by hand
    final byName = {for (final p in products.reversed) p.name: p.id};
    await db.batch((b) {
      for (final r in adjusted) {
        final pid = byName[r.s('product')];
        if (pid == null) continue;
        b.customStatement("INSERT INTO stock_movements(id, product_id, qty_milli, kind, note, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?)", ['demo-${r.id}', pid, r.i('qty'), 'adjustment', r.s('reason'), (r.f['date'] as DateTime).millisecondsSinceEpoch, t, cx.deviceId]);
      }
    });
    await backfillProductCodes(db); // the sample products have their codes too
  });
}

String _enc(Map<String, Object> f) => jsonEncode({for (final e in f.entries) e.key: e.value is DateTime ? {'_d': (e.value as DateTime).millisecondsSinceEpoch} : e.value});
