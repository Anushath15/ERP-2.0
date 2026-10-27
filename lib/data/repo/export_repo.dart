/// Builds the six tables of the Export page from the shop database. Reads only (nothing is changed), straight from SQL, so it
/// does not depend on what the screens happen to have loaded.
library;

import '../app_data.dart';
import '../context.dart';
import '../../core/money.dart';
import '../../domain/export/export_table.dart';
import '../../domain/stock_value.dart';

enum ExportKind { sales, products, customers, dues, expenses, gst, topCustomers, overdue }

/// Most rows one export reads (a shop with more than this many bills exports by year with the date filter in a later release).
const maxExportRows = 500000;

/// Money for a figure box: ₹ 12,34,567.89.
String rupees(int paise) => formatPaise(paise, symbol: true);

DateTime _at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

String _pay(int mode) => switch (mode) {
      0 => 'Cash',
      1 => 'UPI',
      2 => 'Card',
      _ => 'Other',
    };

String _status(int cancelled, int total, int balance) => cancelled == 1 ? 'Cancelled' : (balance == 0 ? 'Paid' : (balance < total ? 'Part paid' : 'On credit'));

Future<ExportTable> buildExport(AppData d, ExportKind kind) async {
  final db = d.db;
  switch (kind) {
    case ExportKind.sales:
      final r = await db.rows(
          'SELECT number, billed_at, customer_name, item_count, total_paise, received_paise, balance_paise, pay_mode, cancelled, old_bill_no '
          'FROM bills ORDER BY billed_at, id LIMIT ?',
          [maxExportRows]);
      // cancelled bills are listed but never counted in the figures
      var cTotal = 0, cReceived = 0, cBalance = 0, cItems = 0, cBills = 0, cancelled = 0;
      for (final x in r) {
        if (x.read<int>('cancelled') == 1) {
          cancelled++;
          continue;
        }
        cBills++;
        cTotal += x.read<int>('total_paise');
        cReceived += x.read<int>('received_paise');
        cBalance += x.read<int>('balance_paise');
        cItems += x.read<int>('item_count');
      }
      return ExportTable(
        name: 'Sales',
        summary: [('Bills', '$cBills'), ('Total sales', rupees(cTotal)), ('Received', rupees(cReceived)), ('On credit (balance)', rupees(cBalance)), if (cancelled > 0) ('Cancelled bills (not counted)', '$cancelled')],
        totalsRow: [null, null, null, cItems, Rupees(cTotal), Rupees(cReceived), Rupees(cBalance), null, null, null],
        headers: ['Bill no', 'Date', 'Customer', 'Items', 'Total', 'Received', 'Balance', 'Paid by', 'Status', 'Old bill no'],
        rows: [
          for (final x in r)
            [
              x.read<String>('number'),
              _at(x.read<int>('billed_at')),
              x.read<String>('customer_name'),
              x.read<int>('item_count'),
              Rupees(x.read<int>('total_paise')),
              Rupees(x.read<int>('received_paise')),
              Rupees(x.read<int>('balance_paise')),
              _pay(x.read<int>('pay_mode')),
              _status(x.read<int>('cancelled'), x.read<int>('total_paise'), x.read<int>('balance_paise')),
              x.read<String?>('old_bill_no') ?? '',
            ],
        ],
      );
    case ExportKind.gst:
      final r = await db.rows(
          'SELECT number, billed_at, customer_name, taxable_paise, cgst_paise, sgst_paise, igst_paise, discount_paise, round_off_paise, total_paise '
          'FROM bills WHERE cancelled = 0 ORDER BY billed_at, id LIMIT ?',
          [maxExportRows]);
      var gTaxable = 0, gCgst = 0, gSgst = 0, gIgst = 0, gDisc = 0, gRound = 0, gTotal = 0;
      for (final x in r) {
        gTaxable += x.read<int>('taxable_paise');
        gCgst += x.read<int>('cgst_paise');
        gSgst += x.read<int>('sgst_paise');
        gIgst += x.read<int>('igst_paise');
        gDisc += x.read<int>('discount_paise');
        gRound += x.read<int>('round_off_paise');
        gTotal += x.read<int>('total_paise');
      }
      return ExportTable(
        name: 'GST register',
        note: 'Cancelled bills are not included.',
        summary: [('Bills', '${r.length}'), ('Taxable value', rupees(gTaxable)), ('Total GST', rupees(gCgst + gSgst + gIgst)), ('Invoice total', rupees(gTotal))],
        totalsRow: [null, null, null, Rupees(gTaxable), Rupees(gCgst), Rupees(gSgst), Rupees(gIgst), Rupees(gDisc), Rupees(gRound), Rupees(gTotal)],
        headers: ['Bill no', 'Date', 'Customer', 'Taxable value', 'CGST', 'SGST', 'IGST', 'Discount', 'Round off', 'Total'],
        rows: [
          for (final x in r)
            [
              x.read<String>('number'),
              _at(x.read<int>('billed_at')),
              x.read<String>('customer_name'),
              Rupees(x.read<int>('taxable_paise')),
              Rupees(x.read<int>('cgst_paise')),
              Rupees(x.read<int>('sgst_paise')),
              Rupees(x.read<int>('igst_paise')),
              Rupees(x.read<int>('discount_paise')),
              Rupees(x.read<int>('round_off_paise')),
              Rupees(x.read<int>('total_paise')),
            ],
        ],
      );
    case ExportKind.products:
      final r = await db.rows(
          'SELECT p.id, p.mrp_paise, p.code, p.brand, p.name, p.category, p.unit, p.hsn, p.gst_bp, p.price_paise, p.cost_paise, COALESCE(s.qty_milli, 0) AS qty, p.min_stock_milli, p.barcode, p.active '
          'FROM products p LEFT JOIN stock_cache s ON s.product_id = p.id WHERE p.deleted_at IS NULL ORDER BY p.name COLLATE NOCASE LIMIT ?',
          [maxExportRows]);
      // the value of the stock comes from the ONE stock-value calculation (the Inventory page uses it too): the rule the shop chose, else the average cost
      final valuation = await d.reports.stockValuation();
      final rule = valuation.shown;
      final byId = {for (final l in await d.reports.stockLines()) l.id: l};
      var worthSum = 0, inStock = 0, outOfStock = 0;
      final worth = <int>[];
      final ids = [for (final x in r) x.read<String>('id')];
      for (var i = 0; i < r.length; i++) {
        final l = byId[ids[i]];
        final q = r[i].read<int>('qty');
        final unit = l?.unitValue(rule) ?? (l == null ? null : (l.avgPaise > 0 ? l.avgPaise : l.buyPaise));
        final w = (q > 0 && unit != null && unit > 0) ? (unit * q + 500) ~/ 1000 : 0;
        worth.add(w);
        worthSum += w;
        if (q > 0) {
          inStock++;
        } else {
          outOfStock++;
        }
      }
      final ruleText = switch (rule) { ValuationRule.average => 'average cost', ValuationRule.buying => 'buying price', ValuationRule.selling => 'selling price' };
      return ExportTable(
        name: 'Products',
        note: 'Stock worth = stock x $ruleText (the rule chosen in Inventory). Products with no buying price are not valued.',
        summary: [
          ('Total products', '${r.length}'),
          ('In stock', '$inStock'),
          ('Out of stock', '$outOfStock'),
          ('Total stock worth', rupees(worthSum)),
          ('Worth at buying price', rupees(valuation.total(ValuationRule.buying))),
          ('Worth at selling price', rupees(valuation.total(ValuationRule.selling))),
          if (valuation.unpricedProducts > 0) ('Stock with no buying price', '${valuation.unpricedProducts}'),
        ],
        totalsRow: [null, '${r.length} products', null, null, null, null, null, null, null, null, null, null, null, null, Rupees(worthSum)],
        headers: ['Code', 'Name', 'Brand', 'Category', 'Unit', 'HSN', 'GST %', 'MRP', 'Selling price', 'Buying price', 'Stock', 'Low stock at', 'Barcode', 'Active', 'Stock worth'],
        rows: [
          for (var i = 0; i < r.length; i++)
            [
              r[i].read<String>('code'),
              r[i].read<String>('name'),
              r[i].read<String>('brand'),
              r[i].read<String>('category'),
              r[i].read<String>('unit'),
              r[i].read<String>('hsn'),
              r[i].read<int>('gst_bp') / 100,
              Rupees(r[i].read<int>('mrp_paise')),
              Rupees(r[i].read<int>('price_paise')),
              Rupees(r[i].read<int>('cost_paise')),
              Qty(r[i].read<int>('qty')),
              Qty(r[i].read<int>('min_stock_milli')),
              r[i].read<String>('barcode'),
              r[i].read<int>('active') == 1 ? 'Yes' : 'No',
              Rupees(worth[i]),
            ],
        ],
      );
    case ExportKind.customers:
      final r = await db.rows(
          'SELECT c.name, c.phone, c.city, c.address, c.gstin, c.credit_limit_paise, COALESCE(b.balance_paise, 0) AS owed '
          "FROM customers c LEFT JOIN party_balance b ON b.party_id = c.id AND b.party_kind = 'customer' WHERE c.deleted_at IS NULL ORDER BY c.name COLLATE NOCASE LIMIT ?",
          [maxExportRows]);
      var owedAll = 0, creditAll = 0, owing = 0;
      for (final x in r) {
        owedAll += x.read<int>('owed');
        creditAll += x.read<int>('credit_limit_paise');
        if (x.read<int>('owed') > 0) owing++;
      }
      return ExportTable(
        name: 'Customers',
        summary: [('Customers', '${r.length}'), ('Customers who owe us', '$owing'), ('Total owed to us', rupees(owedAll))],
        totalsRow: [null, null, null, null, null, Rupees(creditAll), Rupees(owedAll)],
        headers: ['Name', 'Phone', 'City', 'Address', 'GSTIN', 'Credit limit', 'Owes us'],
        rows: [
          for (final x in r)
            [
              x.read<String>('name'),
              x.read<String>('phone'),
              x.read<String>('city'),
              x.read<String>('address'),
              x.read<String>('gstin'),
              Rupees(x.read<int>('credit_limit_paise')),
              Rupees(x.read<int>('owed')),
            ],
        ],
      );
    case ExportKind.dues:
      final r = await db.rows(
          'SELECT c.name, c.phone, c.city, b.balance_paise AS owed, b.last_bill_at, b.last_payment_at '
          "FROM party_balance b JOIN customers c ON c.id = b.party_id WHERE b.party_kind = 'customer' AND b.balance_paise > 0 AND c.deleted_at IS NULL "
          'ORDER BY b.balance_paise DESC LIMIT ?',
          [maxExportRows]);
      var duesAll = 0;
      for (final x in r) {
        duesAll += x.read<int>('owed');
      }
      return ExportTable(
        name: 'Credit and Dues',
        summary: [('Customers who owe us', '${r.length}'), ('Total to collect', rupees(duesAll))],
        totalsRow: [null, null, null, Rupees(duesAll), null, null],
        headers: ['Customer', 'Phone', 'City', 'Owes us', 'Last bill', 'Last payment'],
        rows: [
          for (final x in r)
            [
              x.read<String>('name'),
              x.read<String>('phone'),
              x.read<String>('city'),
              Rupees(x.read<int>('owed')),
              x.read<int?>('last_bill_at') == null ? '' : _at(x.read<int>('last_bill_at')),
              x.read<int?>('last_payment_at') == null ? '' : _at(x.read<int>('last_payment_at')),
            ],
        ],
      );
    case ExportKind.expenses:
      final list = await d.records.list('expenses', limit: maxExportRows);
      Object? date(Object? v) => v is DateTime ? v : (v ?? '');
      final spent = list.fold<int>(0, (s, e) => s + e.i('amount'));
      return ExportTable(
        name: 'Expenses',
        summary: [('Entries', '${list.length}'), ('Total spent', rupees(spent))],
        totalsRow: [null, null, null, Rupees(spent)],
        headers: ['Date', 'Category', 'Note', 'Amount'],
        rows: [
          for (final r in list.reversed) [date(r.f['date']), r.s('category'), r.s('note'), Rupees(r.i('amount'))],
        ],
      );
    case ExportKind.topCustomers:
      final now = d.cx.now();
      final from = DateTime(now.year - 1, now.month, now.day + 1);
      final top = await d.reports.topCustomers(from, now, limit: 100);
      final delay = await d.reports.paymentDelay();
      final all = top.fold<int>(0, (s, x) => s + x.salesPaise);
      return ExportTable(
        name: 'Top customers',
        note: 'The last 12 months: bills (not cancelled) less returns. Walk-in sales without a customer are not counted.',
        summary: [
          ('Customers', '${top.length}'),
          ('Their purchases', rupees(all)),
          if (delay.averageDays != null) ('Average days to pay a credit bill', delay.averageDays!.toStringAsFixed(1)),
          if (delay.bills > 0) ('Longest wait', '${delay.longestDays} days'),
        ],
        totalsRow: [null, null, top.fold<int>(0, (s, x) => s + x.bills), Rupees(all), null],
        headers: const ['Customer', 'Phone', 'Bills', 'Bought', 'Share %'],
        rows: [for (final x in top) [x.name, x.phone, x.bills, Rupees(x.salesPaise), all == 0 ? 0 : (x.salesPaise * 1000 ~/ all) / 10]],
      );
    case ExportKind.overdue:
      final list = await d.reports.overdueBills(d.cx.now());
      final due = list.fold<int>(0, (s, x) => s + x.duePaise);
      return ExportTable(
        name: 'Overdue bills',
        note: 'Credit bills not paid in full more than 30 days after the bill, oldest first.',
        summary: [('Overdue bills', '${list.length}'), ('Customers', '${list.map((x) => x.customerId).toSet().length}'), ('Amount overdue', rupees(due))],
        totalsRow: [null, null, null, null, null, Rupees(due)],
        headers: const ['Customer', 'Phone', 'Bill no', 'Bill date', 'Days', 'Still due'],
        rows: [for (final x in list) [x.customerName, x.phone, x.billNo, x.billDate, x.daysOld, Rupees(x.duePaise)]],
      );
  }
}

/// The file name for an export: `Sales 2026-10-17.xlsx`.
String exportFileName(ExportTable t, String ext, DateTime now) =>
    '${t.name} ${DataContext.dayOf(now)}.$ext';
