/// The reconciliation report: what the importer read, what it will write, what it would reject or repair, and the totals the owner can
/// check against ERP 1's own screens. Plain text so it can be shown, saved or read out.
library;

import 'plan.dart';

/// Totals of a plan, in paise and milli-units. The same figures are read back from the new database after a write and must match.
class Recon {
  Recon(Erp1Plan p) {
    for (final b in p.bills) {
      if (b.cancelled) {
        cancelledBills++;
        cancelledPaise += b.total;
        continue;
      }
      bills++;
      salesPaise += b.total;
      creditOnBillsPaise += b.balance;
      final m = b.at.month;
      salesByMonth[m] = (salesByMonth[m] ?? 0) + b.total;
    }
    for (final pay in p.payments) {
      final m = DateTime.fromMillisecondsSinceEpoch(pay.atMs, isUtc: true).add(const Duration(hours: 5, minutes: 30));
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      if (pay.partyKind == 'customer') {
        customerPaymentsPaise += pay.amountPaise;
        paymentsByMonth[key] = (paymentsByMonth[key] ?? 0) + pay.amountPaise;
      } else {
        dealerPaymentsPaise += pay.amountPaise;
      }
    }
    for (final c in p.customers.values) {
      if (c.deleted) continue;
      if (c.outstandingPaise > 0) {
        customersOwing++;
        customerOwedPaise += c.outstandingPaise;
      } else if (c.outstandingPaise < 0) {
        customersInAdvance++;
        customerAdvancePaise += -c.outstandingPaise;
      }
    }
    for (final d in p.dealers.values) {
      if (d.deleted) continue;
      if (d.outstandingPaise > 0) {
        dealersOwed++;
        dealerOwedPaise += d.outstandingPaise;
      }
    }
    for (final pr in p.products.values) {
      if (pr.placeholder) continue;
      stockMilli += pr.stockMilli;
      if (pr.stockMilli < 0) negativeProducts++;
      if (pr.deleted) {
        deletedProducts++;
        continue;
      }
      final stock = pr.stockMilli;
      int v(int rate) => (stock * rate / 1000).round();
      final bucket = !pr.active ? inactive : (pr.costPaise == 0 && pr.avgCostPaise == 0 ? unpriced : active);
      bucket.add(pr, stock, v(pr.pricePaise), v(pr.costPaise), v(pr.avgCostPaise));
    }
  }

  int bills = 0, cancelledBills = 0, salesPaise = 0, cancelledPaise = 0, creditOnBillsPaise = 0;
  int customerPaymentsPaise = 0, dealerPaymentsPaise = 0;
  int customersOwing = 0, customerOwedPaise = 0, customersInAdvance = 0, customerAdvancePaise = 0, dealersOwed = 0, dealerOwedPaise = 0;
  int stockMilli = 0, negativeProducts = 0, deletedProducts = 0;
  final salesByMonth = <String, int>{};
  final paymentsByMonth = <String, int>{};
  final active = ValueBucket(), unpriced = ValueBucket(), inactive = ValueBucket();

  /// The three candidate rules for "what is my stock worth", for ACTIVE products that have a buying price, with the other groups beside them.
  ValueBucket get all => ValueBucket()
    ..merge(active)
    ..merge(unpriced)
    ..merge(inactive);
}

class ValueBucket {
  int products = 0, qtyMilli = 0, atSelling = 0, atBuying = 0, atAverage = 0, negativeProducts = 0, negativeAtSelling = 0, negativeAtBuying = 0, negativeAtAverage = 0;
  PProduct? example;
  void add(PProduct p, int stock, int selling, int buying, int average) {
    products++;
    qtyMilli += stock;
    atSelling += selling;
    atBuying += buying;
    atAverage += average;
    if (stock < 0) {
      negativeProducts++;
      negativeAtSelling += selling;
      negativeAtBuying += buying;
      negativeAtAverage += average;
    }
    if (example == null && stock > 0 && p.pricePaise > 0 && p.costPaise > 0 && p.avgCostPaise > 0 && p.costPaise != p.pricePaise) example = p;
  }

  void merge(ValueBucket o) {
    products += o.products;
    qtyMilli += o.qtyMilli;
    atSelling += o.atSelling;
    atBuying += o.atBuying;
    atAverage += o.atAverage;
    negativeProducts += o.negativeProducts;
    negativeAtSelling += o.negativeAtSelling;
    negativeAtBuying += o.negativeAtBuying;
    negativeAtAverage += o.negativeAtAverage;
    example ??= o.example;
  }
}

String rupees(int paise) {
  final neg = paise < 0;
  final a = paise.abs();
  var whole = (a ~/ 100).toString();
  // Indian grouping: last three digits, then groups of two
  if (whole.length > 3) {
    final tail = whole.substring(whole.length - 3);
    var head = whole.substring(0, whole.length - 3);
    final parts = <String>[];
    while (head.length > 2) {
      parts.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) parts.insert(0, head);
    whole = '${parts.join(',')},$tail';
  }
  return '${neg ? '-' : ''}₹$whole.${(a % 100).toString().padLeft(2, '0')}';
}

String qty(int milli) {
  final neg = milli < 0;
  final a = milli.abs();
  final frac = (a % 1000).toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '');
  return '${neg ? '-' : ''}${a ~/ 1000}${frac.isEmpty ? '' : '.$frac'}';
}

String buildReport(Erp1Plan p, {String? fileName, bool dryRun = true, String? valuationRule}) {
  final r = Recon(p);
  final o = StringBuffer();
  void h(String t) => o.writeln('\n== $t');
  o.writeln(dryRun ? 'ERP 1 IMPORT: DRY RUN (nothing was written)' : 'ERP 1 IMPORT: WRITTEN TO A NEW DATABASE');
  if (fileName != null) o.writeln('Backup file: $fileName');
  o.writeln('Backup format: ${p.backupFormat ?? 'not stated'}; taken: ${p.backupStamp ?? 'not stated'}');

  h('1. Counts (read in the file / will be written)');
  const keyOf = {
    'products': 'erp_products', 'customers': 'erp_customers', 'dealers': 'erp_dealers', 'bills': 'erp_sales_invoices', 'estimates': 'erp_estimations',
    'customer payments': 'erp_credit_payments', 'dealer payments': 'erp_dealer_payments', 'purchases': 'erp_purchases', 'sales returns': 'erp_sales_returns',
    'purchase returns': 'erp_purchase_returns', 'stock adjustments': 'erp_stock_adjustments', 'expenses': 'erp_expenses', 'deliveries': 'erp_deliveries',
    'warranties': 'erp_warranties', 'projects': 'erp_house_projects', 'staff': 'erp_staff', 'notifications': 'erp_notifications', 'categories': 'erp_categories',
  };
  for (final e in keyOf.entries) {
    final read = p.read[e.value] ?? 0;
    final wrote = e.key == 'categories' ? p.categories.length : (p.imported[e.key] ?? 0);
    final rej = p.issues.count(IssueKind.rejected, e.key);
    final skip = p.issues.count(IssueKind.skipped, e.key);
    o.writeln('  ${e.key.padRight(20)} read ${read.toString().padLeft(8)}   written ${wrote.toString().padLeft(8)}   rejected ${rej.toString().padLeft(6)}   skipped (deleted) $skip');
  }
  final placeholders = p.products.values.where((x) => x.placeholder).length;
  if (placeholders > 0) o.writeln('  placeholder products made for bill lines with an unknown product: $placeholders');

  h('2. Sales and payments');
  o.writeln('  Bills counted (not cancelled): ${r.bills}, total ${rupees(r.salesPaise)}; money still owed on them: ${rupees(r.creditOnBillsPaise)}');
  o.writeln('  Cancelled bills: ${r.cancelledBills}, total ${rupees(r.cancelledPaise)} (kept, marked cancelled, not counted in sales)');
  o.writeln('  Customer payments: ${rupees(r.customerPaymentsPaise)}; dealer payments: ${rupees(r.dealerPaymentsPaise)}');
  o.writeln('  Month by month (sales / payments received):');
  final months = {...r.salesByMonth.keys, ...r.paymentsByMonth.keys}.toList()..sort();
  for (final m in months) {
    o.writeln('    $m   ${rupees(r.salesByMonth[m] ?? 0).padLeft(16)}   ${rupees(r.paymentsByMonth[m] ?? 0).padLeft(16)}');
  }

  h('3. Customer and dealer balances (these must match ERP 1\'s own screens)');
  o.writeln('  Customers who owe: ${r.customersOwing}, total ${rupees(r.customerOwedPaise)}');
  o.writeln('  Customers with money in advance: ${r.customersInAdvance}, total ${rupees(r.customerAdvancePaise)}');
  o.writeln('  Dealers we owe: ${r.dealersOwed}, total ${rupees(r.dealerOwedPaise)}');
  final big = p.openingCustomer.entries.where((e) => e.value.abs() >= 100000).toList()..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
  o.writeln('  Customers whose balance is NOT explained by their bills and payments in the file: ${p.openingCustomer.length} (carried in as an "opening balance" entry; largest ${big.take(5).map((e) => '${p.customers[e.key]!.name} ${rupees(e.value)}').join('; ')})');
  o.writeln('  Dealers likewise: ${p.openingDealer.length}');

  h('4. Stock');
  o.writeln('  Products with stock figures: ${p.products.values.where((x) => !x.placeholder).length}; total quantity ${qty(r.stockMilli)}; negative stock: ${r.negativeProducts} product(s) (kept as they are)');
  o.writeln('  Products whose opening stock had to be made up to match ERP 1\'s figure: ${p.openingStock.length}');
  _valuation(o, r, valuationRule);

  h('5. Every record the importer would reject or repair');
  final order = [IssueKind.rejected, IssueKind.repaired, IssueKind.skipped, IssueKind.note];
  final label = {IssueKind.rejected: 'REJECTED (not imported)', IssueKind.repaired: 'REPAIRED (imported, value changed)', IssueKind.skipped: 'SKIPPED', IssueKind.note: 'NOTE (imported as is)'};
  for (final k in order) {
    final bs = p.issues.buckets.values.where((b) => b.kind == k).toList()..sort((a, b) => b.count.compareTo(a.count));
    o.writeln('  ${label[k]}: ${bs.fold(0, (a, b) => a + b.count)}');
    for (final b in bs.take(60)) {
      o.writeln('    ${b.count.toString().padLeft(7)} x ${b.entity}: ${b.reason}   e.g. ${b.examples.take(4).join(', ')}');
    }
    if (bs.length > 60) o.writeln('    … and ${bs.length - 60} more kinds');
  }

  h('6. Lists in the file with no home in ERP 2.0 yet (kept out, listed here)');
  if (p.unmappedKeys.isEmpty) o.writeln('  none');
  for (final e in p.unmappedKeys.entries) {
    o.writeln('  ${e.key}: ${e.value} record(s)');
  }
  o.writeln('  Not imported by design: sign-in accounts, passwords, this computer\'s printer and appearance settings, the old invoice counters.');

  h('7. Old bill numbers');
  final first = p.bills.isEmpty ? null : p.bills.first, last = p.bills.isEmpty ? null : p.bills.last;
  o.writeln('  Every ERP 1 bill keeps its number as "Old bill no." (searchable). First: ${first?.oldNo ?? '-'} (${first?.at.day ?? '-'}), last: ${last?.oldNo ?? '-'} (${last?.at.day ?? '-'}).');
  return o.toString();
}

void _valuation(StringBuffer o, Recon r, String? chosen) {
  o.writeln('\n  STOCK VALUE: a decision is needed (no rule has been applied).');
  void row(String name, ValueBucket b) {
    o.writeln('    ${name.padRight(46)} ${b.products.toString().padLeft(6)} products   at selling price ${rupees(b.atSelling).padLeft(16)}   at buying price ${rupees(b.atBuying).padLeft(16)}   at average cost ${rupees(b.atAverage).padLeft(16)}');
  }

  row('Active products with a buying price', r.active);
  row('Active products with NO buying price (cost 0)', r.unpriced);
  row('Inactive products', r.inactive);
  row('Everything above', r.all);
  if (r.all.negativeProducts > 0) {
    o.writeln('    ${r.all.negativeProducts} product(s) have NEGATIVE stock; they are included in the totals above as ${rupees(r.all.negativeAtSelling)} (selling), ${rupees(r.all.negativeAtBuying)} (buying), ${rupees(r.all.negativeAtAverage)} (average). Counting them as zero instead would give ${rupees(r.all.atSelling - r.all.negativeAtSelling)} / ${rupees(r.all.atBuying - r.all.negativeAtBuying)} / ${rupees(r.all.atAverage - r.all.negativeAtAverage)}.');
  }
  final ex = r.all.example;
  if (ex != null) {
    final q = ex.stockMilli;
    o.writeln('    Example from your own list: "${ex.name}", ${qty(q)} in stock, sells at ${rupees(ex.pricePaise)}, bought at ${rupees(ex.costPaise)}, average cost ${rupees(ex.avgCostPaise)}.');
    o.writeln('      Selling price rule says ${rupees((q * ex.pricePaise / 1000).round())}; buying price rule says ${rupees((q * ex.costPaise / 1000).round())}; average cost rule says ${rupees((q * ex.avgCostPaise / 1000).round())}.');
  }
  o.writeln('    The setting "valuation.rule" is ${chosen ?? 'NOT SET'}; the Reports page will show all three until it is set.');
}
