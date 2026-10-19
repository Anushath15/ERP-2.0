/// Builds the six tables of the Export page from the shop database. Reads only (nothing is changed), straight from SQL, so it
/// does not depend on what the screens happen to have loaded.
library;

import '../app_data.dart';
import '../context.dart';
import '../../domain/export/export_table.dart';

enum ExportKind { sales, products, customers, dues, expenses, gst }

/// Most rows one export reads (a shop with more than this many bills exports by year with the date filter in a later release).
const maxExportRows = 500000;

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
      return ExportTable(
        name: 'Sales',
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
      return ExportTable(
        name: 'GST register',
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
          'SELECT p.mrp_paise, p.code, p.brand, p.name, p.category, p.unit, p.hsn, p.gst_bp, p.price_paise, p.cost_paise, COALESCE(s.qty_milli, 0) AS qty, p.min_stock_milli, p.barcode, p.active '
          'FROM products p LEFT JOIN stock_cache s ON s.product_id = p.id WHERE p.deleted_at IS NULL ORDER BY p.name COLLATE NOCASE LIMIT ?',
          [maxExportRows]);
      return ExportTable(
        name: 'Products',
        headers: ['Code', 'Name', 'Brand', 'Category', 'Unit', 'HSN', 'GST %', 'MRP', 'Selling price', 'Buying price', 'Stock', 'Low stock at', 'Barcode', 'Active'],
        rows: [
          for (final x in r)
            [
              x.read<String>('code'),
              x.read<String>('name'),
              x.read<String>('brand'),
              x.read<String>('category'),
              x.read<String>('unit'),
              x.read<String>('hsn'),
              x.read<int>('gst_bp') / 100,
              Rupees(x.read<int>('mrp_paise')),
              Rupees(x.read<int>('price_paise')),
              Rupees(x.read<int>('cost_paise')),
              Qty(x.read<int>('qty')),
              Qty(x.read<int>('min_stock_milli')),
              x.read<String>('barcode'),
              x.read<int>('active') == 1 ? 'Yes' : 'No',
            ],
        ],
      );
    case ExportKind.customers:
      final r = await db.rows(
          'SELECT c.name, c.phone, c.city, c.address, c.gstin, c.credit_limit_paise, COALESCE(b.balance_paise, 0) AS owed '
          "FROM customers c LEFT JOIN party_balance b ON b.party_id = c.id AND b.party_kind = 'customer' WHERE c.deleted_at IS NULL ORDER BY c.name COLLATE NOCASE LIMIT ?",
          [maxExportRows]);
      return ExportTable(
        name: 'Customers',
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
      return ExportTable(
        name: 'Money to collect',
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
      return ExportTable(
        name: 'Expenses',
        headers: ['Date', 'Category', 'Note', 'Amount'],
        rows: [
          for (final r in list.reversed) [date(r.f['date']), r.s('category'), r.s('note'), Rupees(r.i('amount'))],
        ],
      );
  }
}

/// The file name for an export: `Sales 2026-10-17.xlsx`.
String exportFileName(ExportTable t, String ext, DateTime now) =>
    '${t.name} ${DataContext.dayOf(now)}.$ext';
