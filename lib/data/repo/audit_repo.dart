/// The auditor pack: everything an auditor or accountant asks for to check the sales and file GST for a period (a month or a financial year),
/// as ready tables (one Excel sheet or PDF section each). Reads only; every figure is the one saved on the bill, never worked out again here.
///
///  1. Summary: the period, the shop, counts, totals, and the checks (bill-number gaps, cancelled bills).
///  2. Sales register: EVERY bill, one row each, with customer, GSTIN, taxable value, CGST/SGST/IGST, discount, round-off, total, how it was paid
///     and the status. Cancelled bills are listed (an auditor must see them) and marked, but never counted in the totals.
///  3. Bill items: every item line of every bill (HSN, quantity, rate, discount, GST rate, taxable value, tax, amount).
///  4. GST by rate: sales, credit notes and the net for each rate.
///  5. HSN summary, 6. Credit notes (sales returns), 7. Cancelled bills with reasons, 8. Purchases (input tax credit), 9. Bill number check.
library;

import 'package:drift/drift.dart' show QueryRow;
import '../../domain/export/export_table.dart';
import '../../domain/gst_uqc.dart';
import '../context.dart';
import '../db/app_database.dart';
import 'gst_return_repo.dart' show RateTotals;

DateTime _at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

String _pay(int mode) => switch (mode) { 0 => 'Cash', 1 => 'UPI', 2 => 'Card', 3 => 'Credit', _ => 'Other' };

String _rate(int bp) => bp % 100 == 0 ? '${bp ~/ 100}' : (bp / 100).toStringAsFixed(2);

String _status(int cancelled, int total, int balance) => cancelled == 1 ? 'Cancelled' : (balance == 0 ? 'Paid' : (balance < total ? 'Part paid' : 'On credit'));

class AuditPack {
  const AuditPack({required this.label, required this.tables, required this.headerLines});

  /// "Financial year 2025-26" or "October 2026".
  final String label;
  final List<ExportTable> tables;
  final List<String> headerLines;
}

class AuditRepo {
  AuditRepo(this.cx);
  final DataContext cx;
  AppDatabase get _db => cx.db;

  /// All the tables for [from] (inclusive) to [to] (exclusive), described as [label].
  Future<AuditPack> pack(DateTime from, DateTime to, {required String label, required String shopName, required String shopGstin}) async {
    final f = from.millisecondsSinceEpoch, t = to.millisecondsSinceEpoch;

    // ---- 2. sales register
    final bills = await _db.rows(
        'SELECT b.id, b.number, b.series, b.seq, b.billed_at, b.customer_name, COALESCE(c.gstin, \'\') AS gstin, b.item_count, b.taxable_paise, b.cgst_paise, b.sgst_paise, b.igst_paise, '
        'b.discount_paise + b.extra_discount_paise AS disc, b.round_off_paise, b.total_paise, b.received_paise, b.balance_paise, b.pay_mode, b.cancelled, COALESCE(b.old_bill_no, \'\') AS old_no '
        'FROM bills b LEFT JOIN customers c ON c.id = b.customer_id WHERE b.billed_at >= ? AND b.billed_at < ? ORDER BY b.billed_at, b.id',
        [f, t]);
    var nBills = 0, nCancelled = 0, taxable = 0, cgst = 0, sgst = 0, igst = 0, disc = 0, round = 0, total = 0, received = 0, balance = 0, items = 0;
    for (final b in bills) {
      if (b.read<int>('cancelled') == 1) {
        nCancelled++;
        continue;
      }
      nBills++;
      taxable += b.read<int>('taxable_paise');
      cgst += b.read<int>('cgst_paise');
      sgst += b.read<int>('sgst_paise');
      igst += b.read<int>('igst_paise');
      disc += b.read<int>('disc');
      round += b.read<int>('round_off_paise');
      total += b.read<int>('total_paise');
      received += b.read<int>('received_paise');
      balance += b.read<int>('balance_paise');
      items += b.read<int>('item_count');
    }
    final register = ExportTable(
      name: 'Sales register',
      note: 'Every bill of the period, one row each. Cancelled bills are listed and marked but are NOT counted in the totals.',
      summary: [('Bills', '$nBills'), if (nCancelled > 0) ('Cancelled (not counted)', '$nCancelled'), ('Taxable value', Rupees(taxable).text), ('Total', Rupees(total).text)],
      headers: const ['Bill no', 'Date', 'Customer', 'Customer GSTIN', 'Items', 'Taxable value', 'CGST', 'SGST', 'IGST', 'Discount', 'Round off', 'Bill total', 'Received', 'Balance', 'Paid by', 'Status', 'Old bill no'],
      totalsRow: [null, null, null, null, items, Rupees(taxable), Rupees(cgst), Rupees(sgst), Rupees(igst), Rupees(disc), Rupees(round), Rupees(total), Rupees(received), Rupees(balance), null, null, null],
      rows: [
        for (final b in bills)
          [
            b.read<String>('number'),
            _at(b.read<int>('billed_at')),
            b.read<String>('customer_name').isEmpty ? 'Walk-in customer' : b.read<String>('customer_name'),
            b.read<String>('gstin').trim().toUpperCase(),
            b.read<int>('item_count'),
            Rupees(b.read<int>('taxable_paise')),
            Rupees(b.read<int>('cgst_paise')),
            Rupees(b.read<int>('sgst_paise')),
            Rupees(b.read<int>('igst_paise')),
            Rupees(b.read<int>('disc')),
            Rupees(b.read<int>('round_off_paise')),
            Rupees(b.read<int>('total_paise')),
            Rupees(b.read<int>('received_paise')),
            Rupees(b.read<int>('balance_paise')),
            _pay(b.read<int>('pay_mode')),
            _status(b.read<int>('cancelled'), b.read<int>('total_paise'), b.read<int>('balance_paise')),
            b.read<String>('old_no'),
          ],
      ],
    );

    // ---- 3. bill items
    final lines = await _db.rows(
        'SELECT b.number, b.billed_at, b.customer_name, b.cancelled, l.line_no, l.name, COALESCE(p.hsn, \'\') AS hsn, l.unit, l.qty_milli, l.rate_paise, l.discount_bp, l.discount_paise, l.gst_bp, l.taxable_paise, l.tax_paise, l.total_paise '
        'FROM bill_lines l JOIN bills b ON b.id = l.bill_id LEFT JOIN products p ON p.id = l.product_id WHERE b.billed_at >= ? AND b.billed_at < ? ORDER BY b.billed_at, b.id, l.line_no',
        [f, t]);
    final itemsTable = ExportTable(
      name: 'Bill items',
      note: 'Every item line of every bill. Lines of cancelled bills are marked and not counted.',
      headers: const ['Bill no', 'Date', 'Customer', 'Item', 'HSN', 'Unit', 'Quantity', 'Rate (before GST)', 'Discount %', 'Discount', 'GST %', 'Taxable value', 'GST', 'Amount', 'Status'],
      rows: [
        for (final l in lines)
          [
            l.read<String>('number'),
            _at(l.read<int>('billed_at')),
            l.read<String>('customer_name'),
            l.read<String>('name'),
            l.read<String>('hsn').trim(),
            gstUqc(l.read<String>('unit')),
            Qty(l.read<int>('qty_milli')),
            Rupees(l.read<int>('rate_paise')),
            _rate(l.read<int>('discount_bp')),
            Rupees(l.read<int>('discount_paise')),
            _rate(l.read<int>('gst_bp')),
            Rupees(l.read<int>('taxable_paise')),
            Rupees(l.read<int>('tax_paise')),
            Rupees(l.read<int>('total_paise')),
            l.read<int>('cancelled') == 1 ? 'Cancelled' : '',
          ],
      ],
    );

    // ---- 4. GST by rate (bill by bill, so the CGST/SGST split is the printed invoice's own), sales less credit notes
    final byRateBills = await _db.rows(
        'SELECT b.igst_paise > 0 AS inter, l.gst_bp AS rate, SUM(l.taxable_paise) AS taxable, SUM(l.tax_paise) AS tax FROM bill_lines l JOIN bills b ON b.id = l.bill_id '
        'WHERE b.cancelled = 0 AND b.billed_at >= ? AND b.billed_at < ? GROUP BY b.id, l.gst_bp',
        [f, t]);
    final sales = <int, RateTotals>{}, returns = <int, RateTotals>{};
    for (final r in byRateBills) {
      sales.putIfAbsent(r.read<int>('rate'), RateTotals.new).add(r.read<int>('taxable'), r.read<int>('tax'), inter: r.read<int>('inter') > 0);
    }
    final byRateReturns = await _db.rows(
        'SELECT b.igst_paise > 0 AS inter, l.gst_bp AS rate, SUM(r.taxable_paise) AS taxable, SUM(r.tax_paise) AS tax FROM sales_return_lines r JOIN sales_returns s ON s.id = r.return_id '
        'JOIN bill_lines l ON l.id = r.bill_line_id JOIN bills b ON b.id = s.bill_id WHERE s.returned_at >= ? AND s.returned_at < ? GROUP BY s.id, l.gst_bp',
        [f, t]);
    for (final r in byRateReturns) {
      returns.putIfAbsent(r.read<int>('rate'), RateTotals.new).add(r.read<int>('taxable'), r.read<int>('tax'), inter: r.read<int>('inter') > 0);
    }
    final rates = {...sales.keys, ...returns.keys}.toList()..sort();
    RateTotals z(Map<int, RateTotals> m, int k) => m[k] ?? RateTotals();
    int sum(int Function(RateTotals) pick, Map<int, RateTotals> m) => m.values.fold<int>(0, (a, x) => a + pick(x));
    final netT = sum((x) => x.taxable, sales) - sum((x) => x.taxable, returns);
    final netC = sum((x) => x.cgst, sales) - sum((x) => x.cgst, returns);
    final netS = sum((x) => x.sgst, sales) - sum((x) => x.sgst, returns);
    final netI = sum((x) => x.igst, sales) - sum((x) => x.igst, returns);
    final rateTable = ExportTable(
      name: 'GST by rate',
      note: 'Sales (cancelled bills left out), credit notes and the net, for each GST rate.',
      headers: const ['GST rate %', 'Sales taxable', 'Sales CGST', 'Sales SGST', 'Sales IGST', 'Credit notes taxable', 'Credit notes tax', 'Net taxable', 'Net CGST', 'Net SGST', 'Net IGST'],
      totalsRow: [null, Rupees(sum((x) => x.taxable, sales)), Rupees(sum((x) => x.cgst, sales)), Rupees(sum((x) => x.sgst, sales)), Rupees(sum((x) => x.igst, sales)), Rupees(sum((x) => x.taxable, returns)), Rupees(sum((x) => x.tax, returns)), Rupees(netT), Rupees(netC), Rupees(netS), Rupees(netI)],
      rows: [
        for (final k in rates)
          [
            _rate(k),
            Rupees(z(sales, k).taxable),
            Rupees(z(sales, k).cgst),
            Rupees(z(sales, k).sgst),
            Rupees(z(sales, k).igst),
            Rupees(z(returns, k).taxable),
            Rupees(z(returns, k).tax),
            Rupees(z(sales, k).taxable - z(returns, k).taxable),
            Rupees(z(sales, k).cgst - z(returns, k).cgst),
            Rupees(z(sales, k).sgst - z(returns, k).sgst),
            Rupees(z(sales, k).igst - z(returns, k).igst),
          ],
      ],
    );

    // ---- 5. HSN summary
    final hsn = <String, (String, int, String, int, int, int, int)>{}; // key -> (hsn, rate, uqc, qty, value, taxable, tax)
    void addHsn(List<QueryRow> rows, int sign) {
      for (final r in rows) {
        final code = r.read<String>('hsn').trim().isEmpty ? '(not set)' : r.read<String>('hsn').trim();
        final rate = r.read<int>('rate');
        final uqc = gstUqc(r.read<String>('unit'));
        final k = '$code|$rate|$uqc';
        final o = hsn[k] ?? (code, rate, uqc, 0, 0, 0, 0);
        hsn[k] = (code, rate, uqc, o.$4 + sign * r.read<int>('qty'), o.$5 + sign * r.read<int>('value'), o.$6 + sign * r.read<int>('taxable'), o.$7 + sign * r.read<int>('tax'));
      }
    }

    addHsn(
        await _db.rows(
            'SELECT COALESCE(p.hsn, \'\') AS hsn, l.gst_bp AS rate, l.unit AS unit, SUM(l.qty_milli) AS qty, SUM(l.total_paise) AS value, SUM(l.taxable_paise) AS taxable, SUM(l.tax_paise) AS tax '
            'FROM bill_lines l JOIN bills b ON b.id = l.bill_id LEFT JOIN products p ON p.id = l.product_id WHERE b.cancelled = 0 AND b.billed_at >= ? AND b.billed_at < ? GROUP BY 1, 2, 3',
            [f, t]),
        1);
    addHsn(
        await _db.rows(
            'SELECT COALESCE(p.hsn, \'\') AS hsn, l.gst_bp AS rate, l.unit AS unit, SUM(r.qty_milli) AS qty, SUM(r.amount_paise) AS value, SUM(r.taxable_paise) AS taxable, SUM(r.tax_paise) AS tax '
            'FROM sales_return_lines r JOIN sales_returns s ON s.id = r.return_id JOIN bill_lines l ON l.id = r.bill_line_id LEFT JOIN products p ON p.id = r.product_id '
            'WHERE s.returned_at >= ? AND s.returned_at < ? GROUP BY 1, 2, 3',
            [f, t]),
        -1);
    final hsnRows = hsn.values.where((x) => x.$4 != 0 || x.$5 != 0).toList()..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    final hsnTable = ExportTable(
      name: 'HSN summary',
      note: 'What was sold less what came back, for each HSN code, GST rate and unit. "(not set)" means the product has no HSN code yet.',
      headers: const ['HSN', 'Unit', 'Quantity', 'Total value', 'GST rate %', 'Taxable value', 'GST'],
      totalsRow: [null, null, null, Rupees(hsnRows.fold<int>(0, (a, x) => a + x.$5)), null, Rupees(hsnRows.fold<int>(0, (a, x) => a + x.$6)), Rupees(hsnRows.fold<int>(0, (a, x) => a + x.$7))],
      rows: [for (final x in hsnRows) [x.$1, x.$3, Qty(x.$4), Rupees(x.$5), _rate(x.$2), Rupees(x.$6), Rupees(x.$7)]],
    );

    // ---- 6. credit notes
    final notes = await _db.rows(
        'SELECT s.number, s.returned_at, s.bill_no, s.customer_name, COALESCE(c.gstin, \'\') AS gstin, s.taxable_paise, s.cgst_paise, s.sgst_paise, s.igst_paise, s.round_off_paise, s.total_paise, s.reason '
        'FROM sales_returns s LEFT JOIN customers c ON c.id = s.customer_id WHERE s.returned_at >= ? AND s.returned_at < ? ORDER BY s.returned_at, s.id',
        [f, t]);
    final noteTable = ExportTable(
      name: 'Credit notes',
      note: 'Goods customers gave back (sales returns). Each is a credit note against the bill shown.',
      headers: const ['Credit note no', 'Date', 'Against bill', 'Customer', 'Customer GSTIN', 'Taxable value', 'CGST', 'SGST', 'IGST', 'Round off', 'Note total', 'Reason'],
      totalsRow: [null, null, null, null, null, Rupees(notes.fold<int>(0, (a, x) => a + x.read<int>('taxable_paise'))), Rupees(notes.fold<int>(0, (a, x) => a + x.read<int>('cgst_paise'))), Rupees(notes.fold<int>(0, (a, x) => a + x.read<int>('sgst_paise'))), Rupees(notes.fold<int>(0, (a, x) => a + x.read<int>('igst_paise'))), Rupees(notes.fold<int>(0, (a, x) => a + x.read<int>('round_off_paise'))), Rupees(notes.fold<int>(0, (a, x) => a + x.read<int>('total_paise'))), null],
      rows: [
        for (final n in notes)
          [n.read<String>('number'), _at(n.read<int>('returned_at')), n.read<String>('bill_no'), n.read<String>('customer_name'), n.read<String>('gstin').trim().toUpperCase(), Rupees(n.read<int>('taxable_paise')), Rupees(n.read<int>('cgst_paise')), Rupees(n.read<int>('sgst_paise')), Rupees(n.read<int>('igst_paise')), Rupees(n.read<int>('round_off_paise')), Rupees(n.read<int>('total_paise')), n.read<String>('reason')],
      ],
    );

    // ---- 7. cancelled bills
    final cancelled = await _db.rows(
        'SELECT b.number, b.billed_at, b.customer_name, b.total_paise, COALESCE(x.reason, \'\') AS reason, COALESCE(x.by_name, \'\') AS by_name, x.at AS cancelled_at '
        'FROM bills b LEFT JOIN bill_cancellations x ON x.bill_id = b.id WHERE b.cancelled = 1 AND b.billed_at >= ? AND b.billed_at < ? ORDER BY b.billed_at, b.id',
        [f, t]);
    final cancelTable = ExportTable(
      name: 'Cancelled bills',
      note: 'Bills cancelled after saving, with who cancelled them and why. Their amounts are in no total of this pack.',
      headers: const ['Bill no', 'Bill date', 'Customer', 'Bill total', 'Cancelled on', 'Cancelled by', 'Reason'],
      totalsRow: [null, null, null, Rupees(cancelled.fold<int>(0, (a, x) => a + x.read<int>('total_paise'))), null, null, null],
      rows: [for (final c in cancelled) [c.read<String>('number'), _at(c.read<int>('billed_at')), c.read<String>('customer_name'), Rupees(c.read<int>('total_paise')), c.readNullable<int>('cancelled_at') == null ? '' : _at(c.read<int>('cancelled_at')), c.read<String>('by_name'), c.read<String>('reason')]],
    );

    // ---- 8. purchases (input tax credit)
    final purch = await _db.rows(
        'SELECT p.number, p.invoice_no, p.purchased_at, p.dealer_name, COALESCE(d.gstin, \'\') AS gstin, p.taxable_paise, p.tax_paise, p.total_paise, p.paid_paise, p.status '
        'FROM purchases p LEFT JOIN dealers d ON d.id = p.dealer_id WHERE p.purchased_at >= ? AND p.purchased_at < ? ORDER BY p.purchased_at, p.id',
        [f, t]);
    final got = purch.where((p) => p.read<int>('status') == 1).toList();
    final purchTable = ExportTable(
      name: 'Purchases',
      note: 'Purchases from dealers. Input tax credit counts only RECEIVED purchases from dealers who gave a GSTIN. Pending ones are listed and not counted.',
      headers: const ['Our no', 'Dealer invoice no', 'Date', 'Dealer', 'Dealer GSTIN', 'Taxable value', 'GST', 'Total', 'Paid', 'Status'],
      totalsRow: [null, null, null, null, null, Rupees(got.fold<int>(0, (a, x) => a + x.read<int>('taxable_paise'))), Rupees(got.fold<int>(0, (a, x) => a + x.read<int>('tax_paise'))), Rupees(got.fold<int>(0, (a, x) => a + x.read<int>('total_paise'))), Rupees(got.fold<int>(0, (a, x) => a + x.read<int>('paid_paise'))), null],
      rows: [for (final p in purch) [p.read<String>('number'), p.read<String>('invoice_no'), _at(p.read<int>('purchased_at')), p.read<String>('dealer_name'), p.read<String>('gstin').trim().toUpperCase(), Rupees(p.read<int>('taxable_paise')), Rupees(p.read<int>('tax_paise')), Rupees(p.read<int>('total_paise')), Rupees(p.read<int>('paid_paise')), p.read<int>('status') == 1 ? 'Received' : 'Pending']],
    );

    // ---- 9. bill number check: the numbers of each series should follow each other with nothing missing
    final bySeries = <String, List<(int, String)>>{};
    for (final b in bills) {
      bySeries.putIfAbsent(b.read<String>('series'), () => []).add((b.read<int>('seq'), b.read<String>('number')));
    }
    final gapRows = <List<Object?>>[];
    var gaps = 0;
    for (final e in bySeries.entries) {
      final seqs = e.value.map((x) => x.$1).toList()..sort();
      final have = seqs.toSet();
      final missing = <int>[];
      for (var s = seqs.first; s <= seqs.last && missing.length < 500; s++) {
        if (!have.contains(s)) missing.add(s);
      }
      gaps += missing.length;
      final byNo = {for (final x in e.value) x.$1: x.$2};
      gapRows.add([e.key.isEmpty ? '(no series)' : e.key, byNo[seqs.first], byNo[seqs.last], seqs.length, missing.length, missing.isEmpty ? 'none' : missing.take(60).join(', ') + (missing.length > 60 ? ' ...' : '')]);
    }
    final checkTable = ExportTable(
      name: 'Bill number check',
      note: 'The bill numbers of each series should follow each other. "Missing numbers" are numbers between the first and last bill of the period that are not in this shop data (an auditor will ask about them; a cancelled bill is still listed, so it is never a gap).',
      headers: const ['Series', 'First bill', 'Last bill', 'Bills listed', 'Missing numbers (count)', 'Missing numbers'],
      rows: gapRows,
    );

    final summary = ExportTable(
      name: 'Summary',
      note: 'Period: $label. Figures are the ones saved on the bills; cancelled bills are not counted.',
      summary: [('Bills', '$nBills'), ('Total sales', Rupees(total).text)],
      headers: const ['What', 'Value'],
      rows: [
        ['Shop', shopName],
        ['Shop GSTIN', shopGstin.isEmpty ? '(not set)' : shopGstin],
        ['Period', label],
        ['Bills (not cancelled)', nBills],
        ['Cancelled bills (listed, not counted)', nCancelled],
        ['Credit notes (sales returns)', notes.length],
        ['Taxable value of sales', Rupees(taxable)],
        ['CGST', Rupees(cgst)],
        ['SGST', Rupees(sgst)],
        ['IGST', Rupees(igst)],
        ['Discount given', Rupees(disc)],
        ['Round off', Rupees(round)],
        ['Total of bills', Rupees(total)],
        ['Received', Rupees(received)],
        ['Still to receive (on credit)', Rupees(balance)],
        ['Net taxable value after credit notes', Rupees(netT)],
        ['Net GST after credit notes', Rupees(netC + netS + netI)],
        ['Purchases received (taxable value)', Rupees(got.fold<int>(0, (a, x) => a + x.read<int>('taxable_paise')))],
        ['GST paid on purchases received (input tax credit, before the GSTIN check)', Rupees(got.fold<int>(0, (a, x) => a + x.read<int>('tax_paise')))],
        ['Missing bill numbers', gaps],
        ['HSN not set on', '${hsnRows.where((x) => x.$1 == '(not set)').length} HSN/rate row(s)'],
      ],
    );

    return AuditPack(
      label: label,
      headerLines: ['Period: $label'],
      tables: [summary, register, itemsTable, rateTable, hsnTable, noteTable, cancelTable, purchTable, checkTable],
    );
  }
}
