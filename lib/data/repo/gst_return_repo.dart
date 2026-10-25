/// The figures of a month's GST returns, worked from the bills, credit notes (sales returns) and purchases already saved: GSTR-1 (invoices to registered
/// customers, the rest by rate, credit notes, HSN summary, documents issued) and GSTR-3B (outward supplies, input tax credit, tax to pay). Reads only.
///
/// Rules: cancelled bills are left out; a return is a credit note and is taken off; the tax of one rate on one invoice is split into CGST and SGST ONCE (an odd
/// paisa to SGST), exactly as the printed invoice's GST summary does, or all of it is IGST when the bill was inter-state; input tax credit counts only purchases
/// from dealers that have a GSTIN. Round-off is not part of any taxable value.
library;

import 'package:drift/drift.dart' show QueryRow;
import '../../core/money.dart';
import '../../domain/export/export_table.dart';
import '../../domain/gst_uqc.dart';
import '../context.dart';
import '../db/app_database.dart';

/// The taxable value and the tax of one GST rate.
class RateTotals {
  RateTotals({this.taxable = 0, this.cgst = 0, this.sgst = 0, this.igst = 0});
  int taxable, cgst, sgst, igst;
  int get tax => cgst + sgst + igst;

  void add(int taxableP, int taxP, {required bool inter, int sign = 1}) {
    taxable += sign * taxableP;
    if (inter) {
      igst += sign * taxP;
    } else {
      final c = divRound(taxP, 2);
      cgst += sign * c;
      sgst += sign * (taxP - c);
    }
  }
}

class GstInvoiceRow {
  const GstInvoiceRow({required this.gstin, required this.name, required this.number, required this.date, required this.value, required this.rateBp, required this.taxable, required this.cgst, required this.sgst, required this.igst, this.original = ''});
  final String gstin, name, number, original;
  final DateTime date;
  final int value, rateBp, taxable, cgst, sgst, igst;
}

class HsnRow {
  HsnRow(this.hsn, this.rateBp, this.uqc);
  final String hsn, uqc;
  final int rateBp;
  int qtyMilli = 0, value = 0;
  final totals = RateTotals();
}

class GstMonth {
  GstMonth({required this.label, required this.shopGstin});
  final String label, shopGstin;

  /// Invoices (and credit notes) to registered customers, one row for each rate.
  final b2b = <GstInvoiceRow>[];
  final creditNotes = <GstInvoiceRow>[];

  /// Everything else, by rate: invoices less credit notes.
  final b2c = <int, RateTotals>{};

  /// Outward supplies by rate: all invoices less all credit notes (what GSTR-3B 3.1 adds up).
  final outward = <int, RateTotals>{};
  final hsn = <String, HsnRow>{};

  /// Input tax credit by rate: purchases from dealers with a GSTIN, less what went back. The rest is purchases from dealers with no GSTIN.
  final itc = <int, RateTotals>{};
  final noItc = <int, RateTotals>{};

  String firstInvoice = '', lastInvoice = '';
  int invoices = 0, cancelled = 0, notes = 0;
}

String monthLabel(DateTime m) => '${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][m.month - 1]} ${m.year}';

class GstReturnRepo {
  GstReturnRepo(this.cx);
  final DataContext cx;
  AppDatabase get _db => cx.db;

  Future<GstMonth> month(DateTime m, {required String shopGstin}) async {
    final from = DateTime(m.year, m.month, 1).millisecondsSinceEpoch;
    final to = DateTime(m.year, m.month + 1, 1).millisecondsSinceEpoch;
    final shopState = gstinState(shopGstin);
    final out = GstMonth(label: monthLabel(m), shopGstin: shopGstin);
    RateTotals at(Map<int, RateTotals> map, int rate) => map.putIfAbsent(rate, RateTotals.new);

    // ---- invoices: one row per invoice and rate
    final inv = await _db.rows(
        'SELECT b.id, b.number, b.billed_at, b.total_paise, b.igst_paise AS inter, COALESCE(c.gstin, \'\') AS gstin, COALESCE(c.name, b.customer_name) AS cname, l.gst_bp AS rate, '
        'SUM(l.taxable_paise) AS taxable, SUM(l.tax_paise) AS tax FROM bill_lines l JOIN bills b ON b.id = l.bill_id LEFT JOIN customers c ON c.id = b.customer_id '
        'WHERE b.cancelled = 0 AND b.billed_at >= ? AND b.billed_at < ? GROUP BY b.id, l.gst_bp ORDER BY b.billed_at, b.id, l.gst_bp',
        [from, to]);
    for (final r in inv) {
      final inter = r.read<int>('inter') > 0;
      final rate = r.read<int>('rate'), taxable = r.read<int>('taxable'), tax = r.read<int>('tax');
      final t = RateTotals()..add(taxable, tax, inter: inter);
      final gstin = r.read<String>('gstin').trim().toUpperCase();
      if (looksLikeGstin(gstin)) {
        out.b2b.add(GstInvoiceRow(gstin: gstin, name: r.read<String>('cname'), number: r.read<String>('number'), date: DateTime.fromMillisecondsSinceEpoch(r.read<int>('billed_at')), value: r.read<int>('total_paise'), rateBp: rate, taxable: t.taxable, cgst: t.cgst, sgst: t.sgst, igst: t.igst));
      } else {
        at(out.b2c, rate).add(taxable, tax, inter: inter);
      }
      at(out.outward, rate).add(taxable, tax, inter: inter);
    }

    // ---- credit notes: one row per note and rate
    final cn = await _db.rows(
        'SELECT s.id, s.number, s.returned_at, s.total_paise, b.number AS bill_no, b.igst_paise AS inter, COALESCE(c.gstin, \'\') AS gstin, COALESCE(c.name, b.customer_name) AS cname, l.gst_bp AS rate, '
        'SUM(r.taxable_paise) AS taxable, SUM(r.tax_paise) AS tax FROM sales_return_lines r JOIN sales_returns s ON s.id = r.return_id JOIN bill_lines l ON l.id = r.bill_line_id '
        'JOIN bills b ON b.id = s.bill_id LEFT JOIN customers c ON c.id = b.customer_id WHERE s.returned_at >= ? AND s.returned_at < ? GROUP BY s.id, l.gst_bp ORDER BY s.returned_at, s.id, l.gst_bp',
        [from, to]);
    final noteIds = <String>{};
    for (final r in cn) {
      noteIds.add(r.read<String>('id'));
      final inter = r.read<int>('inter') > 0;
      final rate = r.read<int>('rate'), taxable = r.read<int>('taxable'), tax = r.read<int>('tax');
      final t = RateTotals()..add(taxable, tax, inter: inter);
      final gstin = r.read<String>('gstin').trim().toUpperCase();
      if (looksLikeGstin(gstin)) {
        out.creditNotes.add(GstInvoiceRow(gstin: gstin, name: r.read<String>('cname'), number: r.read<String>('number'), date: DateTime.fromMillisecondsSinceEpoch(r.read<int>('returned_at')), value: r.read<int>('total_paise'), rateBp: rate, taxable: t.taxable, cgst: t.cgst, sgst: t.sgst, igst: t.igst, original: r.read<String>('bill_no')));
      } else {
        at(out.b2c, rate).add(taxable, tax, inter: inter, sign: -1);
      }
      at(out.outward, rate).add(taxable, tax, inter: inter, sign: -1);
    }
    out.notes = noteIds.length;

    // ---- HSN summary: what was sold less what came back
    Future<void> hsn(String sql, int sign) async {
      final rows = await _db.rows(sql, [from, to]);
      for (final r in rows) {
        final code = r.read<String>('hsn').trim().isEmpty ? '(not set)' : r.read<String>('hsn').trim();
        final rate = r.read<int>('rate');
        final uqc = gstUqc(r.read<String>('unit'));
        final row = out.hsn.putIfAbsent('$code|$rate|$uqc', () => HsnRow(code, rate, uqc));
        row.qtyMilli += sign * r.read<int>('qty');
        row.value += sign * r.read<int>('value');
        row.totals.add(r.read<int>('taxable'), r.read<int>('tax'), inter: r.read<int>('inter') > 0, sign: sign);
      }
    }

    await hsn(
        'SELECT COALESCE(p.hsn, \'\') AS hsn, l.gst_bp AS rate, l.unit AS unit, b.igst_paise > 0 AS inter, SUM(l.qty_milli) AS qty, SUM(l.total_paise) AS value, SUM(l.taxable_paise) AS taxable, SUM(l.tax_paise) AS tax '
        'FROM bill_lines l JOIN bills b ON b.id = l.bill_id LEFT JOIN products p ON p.id = l.product_id WHERE b.cancelled = 0 AND b.billed_at >= ? AND b.billed_at < ? GROUP BY 1, 2, 3, 4',
        1);
    await hsn(
        'SELECT COALESCE(p.hsn, \'\') AS hsn, l.gst_bp AS rate, l.unit AS unit, b.igst_paise > 0 AS inter, SUM(r.qty_milli) AS qty, SUM(r.amount_paise) AS value, SUM(r.taxable_paise) AS taxable, SUM(r.tax_paise) AS tax '
        'FROM sales_return_lines r JOIN sales_returns s ON s.id = r.return_id JOIN bill_lines l ON l.id = r.bill_line_id JOIN bills b ON b.id = s.bill_id LEFT JOIN products p ON p.id = r.product_id '
        'WHERE s.returned_at >= ? AND s.returned_at < ? GROUP BY 1, 2, 3, 4',
        -1);

    // ---- documents issued
    final docs = await _db.rows('SELECT number, cancelled FROM bills WHERE billed_at >= ? AND billed_at < ? ORDER BY billed_at, id', [from, to]);
    out.invoices = docs.length;
    out.cancelled = docs.where((d) => d.read<int>('cancelled') == 1).length;
    if (docs.isNotEmpty) {
      out.firstInvoice = docs.first.read<String>('number');
      out.lastInvoice = docs.last.read<String>('number');
    }

    // ---- input tax credit: purchases received this month from dealers with a GSTIN, less purchase returns
    final pur = await _db.rows(
        'SELECT COALESCE(d.gstin, \'\') AS gstin, l.gst_bp AS rate, SUM(l.taxable_paise) AS taxable, SUM(l.tax_paise) AS tax FROM purchase_lines l JOIN purchases p ON p.id = l.purchase_id '
        'LEFT JOIN dealers d ON d.id = p.dealer_id WHERE p.status = 1 AND p.purchased_at >= ? AND p.purchased_at < ? GROUP BY p.id, l.gst_bp',
        [from, to]);
    final back = await _db.rows(
        'SELECT COALESCE(d.gstin, \'\') AS gstin, l.gst_bp AS rate, SUM(r.taxable_paise) AS taxable, SUM(r.tax_paise) AS tax FROM purchase_return_lines r JOIN purchase_returns s ON s.id = r.return_id '
        'JOIN purchase_lines l ON l.id = r.purchase_line_id LEFT JOIN dealers d ON d.id = s.dealer_id WHERE s.returned_at >= ? AND s.returned_at < ? GROUP BY s.id, l.gst_bp',
        [from, to]);
    void credit(List<QueryRow> rows, int sign) {
      for (final r in rows) {
        final gstin = r.read<String>('gstin').trim().toUpperCase();
        final ok = looksLikeGstin(gstin);
        final inter = ok && shopState.isNotEmpty && gstinState(gstin) != shopState;
        at(ok ? out.itc : out.noItc, r.read<int>('rate')).add(r.read<int>('taxable'), r.read<int>('tax'), inter: inter, sign: sign);
      }
    }

    credit(pur, 1);
    credit(back, -1);
    return out;
  }
}

// ---------------------------------------------------------------- the tables

String _rate(int bp) => bp % 100 == 0 ? '${bp ~/ 100}' : (bp / 100).toStringAsFixed(2);

List<int> _sortedRates(Iterable<int> r) => (r.toList()..sort());

/// GSTR-1 as the tables an accountant keys into the portal: B2B invoices, everything else by rate (B2C), credit notes, HSN summary, documents issued.
List<ExportTable> gstr1Tables(GstMonth m) {
  final b2bTaxable = m.b2b.fold<int>(0, (s, r) => s + r.taxable);
  final b2cRates = _sortedRates(m.b2c.keys);
  return [
    ExportTable(
      name: 'GSTR-1 B2B invoices',
      note: 'Invoices to customers who gave a GSTIN, one row for each GST rate. Place of supply: ${m.shopGstin.length >= 2 ? m.shopGstin.substring(0, 2) : '-'} (own state) unless IGST is shown.',
      summary: [('Invoices (rows)', '${m.b2b.length}'), ('Taxable value', _money(b2bTaxable)), ('Tax', _money(m.b2b.fold<int>(0, (s, r) => s + r.cgst + r.sgst + r.igst)))],
      headers: const ['GSTIN of customer', 'Customer', 'Invoice no', 'Date', 'Invoice value', 'Rate %', 'Taxable value', 'CGST', 'SGST', 'IGST'],
      totalsRow: [null, null, null, null, null, null, Rupees(b2bTaxable), Rupees(m.b2b.fold<int>(0, (s, r) => s + r.cgst)), Rupees(m.b2b.fold<int>(0, (s, r) => s + r.sgst)), Rupees(m.b2b.fold<int>(0, (s, r) => s + r.igst))],
      rows: [for (final r in m.b2b) [r.gstin, r.name, r.number, r.date, Rupees(r.value), _rate(r.rateBp), Rupees(r.taxable), Rupees(r.cgst), Rupees(r.sgst), Rupees(r.igst)]],
    ),
    ExportTable(
      name: 'GSTR-1 B2C by rate',
      note: 'All other sales (no customer GSTIN), by GST rate, after taking off credit notes.',
      summary: [('Taxable value', _money(m.b2c.values.fold<int>(0, (s, r) => s + r.taxable))), ('Tax', _money(m.b2c.values.fold<int>(0, (s, r) => s + r.tax)))],
      headers: const ['Rate %', 'Taxable value', 'CGST', 'SGST', 'IGST'],
      totalsRow: [null, Rupees(m.b2c.values.fold<int>(0, (s, r) => s + r.taxable)), Rupees(m.b2c.values.fold<int>(0, (s, r) => s + r.cgst)), Rupees(m.b2c.values.fold<int>(0, (s, r) => s + r.sgst)), Rupees(m.b2c.values.fold<int>(0, (s, r) => s + r.igst))],
      rows: [for (final k in b2cRates) [_rate(k), Rupees(m.b2c[k]!.taxable), Rupees(m.b2c[k]!.cgst), Rupees(m.b2c[k]!.sgst), Rupees(m.b2c[k]!.igst)]],
    ),
    ExportTable(
      name: 'GSTR-1 Credit notes',
      note: 'Sales returns to customers who gave a GSTIN (the others are already taken off the B2C table).',
      headers: const ['GSTIN of customer', 'Customer', 'Credit note no', 'Date', 'Against invoice', 'Note value', 'Rate %', 'Taxable value', 'CGST', 'SGST', 'IGST'],
      rows: [for (final r in m.creditNotes) [r.gstin, r.name, r.number, r.date, r.original, Rupees(r.value), _rate(r.rateBp), Rupees(r.taxable), Rupees(r.cgst), Rupees(r.sgst), Rupees(r.igst)]],
    ),
    hsnTable(m),
    ExportTable(
      name: 'GSTR-1 Documents issued',
      headers: const ['Document', 'From', 'To', 'Total issued', 'Cancelled', 'Net issued'],
      rows: [
        ['Invoices', m.firstInvoice, m.lastInvoice, m.invoices, m.cancelled, m.invoices - m.cancelled],
        ['Credit notes', '', '', m.notes, 0, m.notes],
      ],
    ),
  ];
}

String _money(int paise) => formatPaise(paise, symbol: true);

/// The HSN-wise summary of outward supplies (sales less returns), one row for each HSN code, rate and unit.
ExportTable hsnTable(GstMonth m) {
  final rows = m.hsn.values.where((r) => r.qtyMilli != 0 || r.value != 0).toList()..sort((a, b) => a.hsn != b.hsn ? a.hsn.compareTo(b.hsn) : a.rateBp.compareTo(b.rateBp));
  int sum(int Function(HsnRow) f) => rows.fold<int>(0, (s, r) => s + f(r));
  return ExportTable(
    name: 'HSN summary',
    note: 'Sales less returns, by HSN code, rate and unit. Products with no HSN code show as (not set): fill it in on the Products page.',
    summary: [('HSN rows', '${rows.length}'), ('Total value', _money(sum((r) => r.value))), ('Taxable value', _money(sum((r) => r.totals.taxable))), ('Total tax', _money(sum((r) => r.totals.tax)))],
    headers: const ['HSN', 'Unit (UQC)', 'Quantity', 'Total value', 'Rate %', 'Taxable value', 'IGST', 'CGST', 'SGST'],
    totalsRow: [null, null, null, Rupees(sum((r) => r.value)), null, Rupees(sum((r) => r.totals.taxable)), Rupees(sum((r) => r.totals.igst)), Rupees(sum((r) => r.totals.cgst)), Rupees(sum((r) => r.totals.sgst))],
    rows: [for (final r in rows) [r.hsn, r.uqc, Qty(r.qtyMilli), Rupees(r.value), _rate(r.rateBp), Rupees(r.totals.taxable), Rupees(r.totals.igst), Rupees(r.totals.cgst), Rupees(r.totals.sgst)]],
  );
}

/// GSTR-3B: outward supplies (3.1), input tax credit (4) and the tax to pay (6.1), from the same figures as GSTR-1.
ExportTable gstr3bTable(GstMonth m) {
  RateTotals sumOf(Iterable<RateTotals> x) {
    final t = RateTotals();
    for (final r in x) {
      t.taxable += r.taxable;
      t.cgst += r.cgst;
      t.sgst += r.sgst;
      t.igst += r.igst;
    }
    return t;
  }

  final taxed = sumOf([for (final e in m.outward.entries) if (e.key > 0) e.value]);
  final nil = sumOf([for (final e in m.outward.entries) if (e.key == 0) e.value]);
  final itc = sumOf(m.itc.values);
  final noItc = sumOf(m.noItc.values);
  // what is to pay: the output tax less the credit, head by head (IGST credit may also pay CGST and SGST, as the law allows: shown as the net)
  int pay(int out, int credit) => out - credit > 0 ? out - credit : 0;
  int carry(int out, int credit) => credit - out > 0 ? credit - out : 0;
  final payIgst = pay(taxed.igst, itc.igst), payCgst = pay(taxed.cgst, itc.cgst), paySgst = pay(taxed.sgst, itc.sgst);
  final carryIgst = carry(taxed.igst, itc.igst), carryCgst = carry(taxed.cgst, itc.cgst), carrySgst = carry(taxed.sgst, itc.sgst);
  List<Object?> row(String table, String what, RateTotals t) => [table, what, Rupees(t.taxable), Rupees(t.igst), Rupees(t.cgst), Rupees(t.sgst)];
  return ExportTable(
    name: 'GSTR-3B summary',
    note: 'Input tax credit counts only purchases from dealers that have a GSTIN (add it on the dealer\'s page). IGST credit set-off against CGST/SGST is left to your accountant.',
    summary: [('Output tax', _money(taxed.tax)), ('Input tax credit', _money(itc.tax)), ('Tax to pay', _money(payIgst + payCgst + paySgst)), if (carryIgst + carryCgst + carrySgst > 0) ('Credit to carry forward', _money(carryIgst + carryCgst + carrySgst))],
    headers: const ['Table', 'Description', 'Taxable value', 'IGST', 'CGST', 'SGST/UTGST'],
    rows: [
      row('3.1(a)', 'Outward taxable supplies (other than zero rated, nil rated and exempted)', taxed),
      row('3.1(c)', 'Other outward supplies (nil rated, exempted)', nil),
      row('4(A)(5)', 'All other ITC (net of purchase returns)', itc),
      ['4(D)', 'Not eligible: purchases from dealers with no GSTIN (tax paid, not claimable)', Rupees(noItc.taxable), Rupees(noItc.igst), Rupees(noItc.cgst), Rupees(noItc.sgst)],
      ['6.1', 'Tax payable (output tax less credit)', null, Rupees(payIgst), Rupees(payCgst), Rupees(paySgst)],
      if (carryIgst + carryCgst + carrySgst > 0) ['6.1', 'Credit left over, carried forward', null, Rupees(carryIgst), Rupees(carryCgst), Rupees(carrySgst)],
    ],
  );
}
