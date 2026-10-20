/// Filling in many products at once with an Excel sheet: the sheet the program writes (every product with all the details a shop needs), and the reading of
/// the filled sheet into a plan that says, row by row, what would change. Pure Dart; nothing here touches the database.
///
/// Rules (the same on every run):
///  * A product is found by its Code. A row with no Code is matched by Name + Brand; no match means a NEW product.
///  * An empty cell never changes anything (it never blanks a field). A cell with something in it replaces the value.
///  * Stock is the COUNTED quantity: the program adds or takes the difference as a stock change (never edits the figure).
///  * A row with a problem is skipped and listed; the other rows are still done.
library;

import '../export/export_table.dart';
import '../models.dart';

/// The columns, in order, with the name written in the header.
const productSheetHeaders = ['Code', 'Name', 'Category', 'Brand', 'Unit', 'Barcode', 'HSN', 'GST %', 'MRP', 'Selling price', 'Buying price', 'Stock', 'Min stock'];

/// The sheet to download: every product, its details, with the cells the owner still has to fill (MRP, buying price...) left empty.
ExportTable buildProductSheet(List<Product> products) {
  final sorted = [...products]..sort((a, b) {
      final c = a.category.toLowerCase().compareTo(b.category.toLowerCase());
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  Object? money(int paise) => paise > 0 ? Rupees(paise) : null;
  return ExportTable(
    name: 'Products',
    headers: productSheetHeaders,
    rows: [
      for (final p in sorted)
        [
          p.code,
          p.name,
          p.category,
          p.brand,
          p.unit,
          p.barcode,
          p.hsn,
          p.gstBp % 100 == 0 ? p.gstBp ~/ 100 : p.gstBp / 100,
          money(p.mrpPaise),
          Rupees(p.pricePaise),
          money(p.costPaise),
          Qty(p.stockMilli),
          Qty(p.minStockMilli),
        ],
    ],
  );
}

enum SheetRowStatus { update, create, unchanged, error }

class SheetRowPlan {
  SheetRowPlan(this.rowNo);

  /// The row number as the person sees it in Excel (the header is row 1).
  final int rowNo;
  SheetRowStatus status = SheetRowStatus.unchanged;
  String label = '';

  /// What would change, in words ("MRP 0.00 -> 200.00").
  final List<String> changes = [];
  final List<String> problems = [];
  final List<String> warnings = [];

  /// The product as it should be saved (existing one with the new values, or the new product). Null for an error or an unchanged row.
  Product? product;

  /// The counted stock in thousandths when it differs from what the program has; null = leave stock alone.
  int? stockTarget;
  int stockBefore = 0;

  /// True when the product's own details (not only its stock) change.
  bool detailsChanged = false;
}

class ProductSheetPlan {
  ProductSheetPlan(this.rows, {this.fatal = ''});
  final List<SheetRowPlan> rows;

  /// Set when the sheet cannot be used at all (no header, nothing in it).
  final String fatal;

  int count(SheetRowStatus s) => rows.where((r) => r.status == s).length;
  int get updates => count(SheetRowStatus.update);
  int get creates => count(SheetRowStatus.create);
  int get unchanged => count(SheetRowStatus.unchanged);
  int get errors => count(SheetRowStatus.error);
  int get stockChanges => rows.where((r) => r.stockTarget != null && r.status != SheetRowStatus.error).length;
  int get warningRows => rows.where((r) => r.warnings.isNotEmpty && r.status != SheetRowStatus.error).length;
  bool get hasWork => fatal.isEmpty && (updates + creates) > 0;
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

const _aliases = <String, List<String>>{
  'code': ['code', 'productcode', 'itemcode', 'sku'],
  'name': ['name', 'product', 'productname', 'item', 'itemname', 'goods', 'description'],
  'category': ['category', 'group'],
  'brand': ['brand', 'make'],
  'unit': ['unit', 'uom'],
  'barcode': ['barcode', 'ean'],
  'hsn': ['hsn', 'hsncode'],
  'gst': ['gst', 'gstpercent', 'gstrate', 'tax', 'taxpercent'],
  'mrp': ['mrp', 'maxretailprice'],
  'price': ['sellingprice', 'price', 'rate', 'sellprice', 'saleprice', 'sp'],
  'cost': ['buyingprice', 'cost', 'costprice', 'purchaseprice', 'buyprice', 'cp'],
  'stock': ['stock', 'qty', 'quantity', 'openingstock', 'countedstock', 'currentstock', 'stockqty'],
  'min': ['minstock', 'minimumstock', 'reorderlevel', 'minqty'],
};

/// Rupees typed in a cell ("1,050.5", "₹ 200", "Rs. 99") as paise; null when it is not a number.
int? parseMoney(String text) {
  final t = text.replaceAll(RegExp(r'[₹,\s]|rs\.?|inr', caseSensitive: false), '');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || !v.isFinite) return null;
  return (v * 100).round();
}

/// A quantity typed in a cell as thousandths; null when it is not a number.
int? parseQty(String text) {
  final t = text.replaceAll(RegExp(r'[,\s]'), '');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || !v.isFinite) return null;
  return (v * 1000).round();
}

/// A GST rate typed as "18", "18%" or (an Excel percent cell) 0.18, as basis points; null when it is not a number.
int? parseGstBp(String text) {
  final t = text.replaceAll(RegExp(r'[%\s]'), '');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || !v.isFinite) return null;
  return ((v > 0 && v < 1 ? v * 100 : v) * 100).round();
}

String _rs(int paise) => '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
String _q(int milli) {
  final frac = (milli.abs() % 1000).toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '');
  return '${milli ~/ 1000}${frac.isEmpty ? '' : '.$frac'}';
}

/// Reads the filled sheet. [rows] are the cells as text (header row first), [existing] the products now in the program, [newId] makes ids for new products.
ProductSheetPlan planProductSheet(List<List<String>> rows, List<Product> existing, {required String Function() newId}) {
  // the header: the first row that names a Code or a Name column
  var headerAt = -1;
  var cols = <String, int>{};
  for (var r = 0; r < rows.length && r < 20 && headerAt < 0; r++) {
    final m = <String, int>{};
    for (var c = 0; c < rows[r].length; c++) {
      final n = _norm(rows[r][c]);
      if (n.isEmpty) continue;
      for (final e in _aliases.entries) {
        if (e.value.contains(n) && !m.containsKey(e.key)) m[e.key] = c;
      }
    }
    if (m.containsKey('code') || m.containsKey('name')) {
      headerAt = r;
      cols = m;
    }
  }
  if (headerAt < 0) return ProductSheetPlan(const [], fatal: 'The sheet needs a header row with at least a Code or a Name column.');
  if (cols.length < 2) return ProductSheetPlan(const [], fatal: 'The sheet has only one known column. Use the sheet downloaded from the program.');

  String cell(List<String> row, String key) {
    final i = cols[key];
    return i == null || i >= row.length ? '' : row[i].trim();
  }

  final byCode = {for (final p in existing) if (p.code.isNotEmpty) p.code.toLowerCase(): p};
  final byNameBrand = <String, List<Product>>{};
  for (final p in existing) {
    byNameBrand.putIfAbsent('${p.name.trim().toLowerCase()}|${p.brand.trim().toLowerCase()}', () => []).add(p);
  }
  final seenCodes = <String>{}, seenNew = <String>{}, seenIds = <String>{};

  final plans = <SheetRowPlan>[];
  for (var r = headerAt + 1; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => c.trim().isEmpty)) continue;
    final plan = SheetRowPlan(r + 1);
    plans.add(plan);
    final code = cell(row, 'code');
    final name = cell(row, 'name');
    plan.label = name.isNotEmpty ? name : code;

    // which product is this row about
    Product? found;
    if (code.isNotEmpty) {
      found = byCode[code.toLowerCase()];
      if (found == null) {
        plan.problems.add('Code "$code" is not in your products. Leave the Code empty to add it as a new product.');
      } else if (!seenCodes.add(code.toLowerCase())) {
        plan.problems.add('Code "$code" is on an earlier row too.');
      }
    } else if (name.isNotEmpty) {
      final list = byNameBrand['${name.toLowerCase()}|${cell(row, 'brand').toLowerCase()}'] ?? const [];
      if (list.length > 1) {
        plan.problems.add('"$name" matches ${list.length} products. Use the Code to say which one.');
      } else if (list.length == 1) {
        found = list.first;
        if (!seenCodes.add(found.code.toLowerCase().isEmpty ? found.id : found.code.toLowerCase())) plan.problems.add('This product is on an earlier row too.');
      }
    } else {
      plan.problems.add('The row has no Code and no Name.');
    }
    if (found != null && !seenIds.add(found.id) && plan.problems.isEmpty) plan.problems.add('This product is on an earlier row too.');

    // the values typed on the row (null = the cell is empty: leave it)
    int? price, mrp, cost, stock, minStock, gst;
    String? bad(String key, String what, int? Function(String) parse, void Function(int) set, {bool negativeOk = false}) {
      final t = cell(row, key);
      if (t.isEmpty) return null;
      final v = parse(t);
      if (v == null) return '$what "$t" is not a number.';
      if (v < 0 && !negativeOk) return '$what cannot be below zero.';
      set(v);
      return null;
    }

    for (final problem in [
      bad('price', 'Selling price', parseMoney, (v) => price = v),
      bad('mrp', 'MRP', parseMoney, (v) => mrp = v),
      bad('cost', 'Buying price', parseMoney, (v) => cost = v),
      bad('stock', 'Stock', parseQty, (v) => stock = v),
      bad('min', 'Min stock', parseQty, (v) => minStock = v),
      bad('gst', 'GST %', parseGstBp, (v) => gst = v),
    ]) {
      if (problem != null) plan.problems.add(problem);
    }
    if (gst != null && gst! > 10000) plan.problems.add('GST % cannot be above 100.');
    if (gst != null && gst! > 4000 && gst! <= 10000) plan.warnings.add('GST ${_rs(gst!)} % looks high.');
    if (plan.problems.isNotEmpty) {
      plan.status = SheetRowStatus.error;
      continue;
    }

    final brand = cell(row, 'brand'), category = cell(row, 'category'), unit = cell(row, 'unit'), barcode = cell(row, 'barcode'), hsn = cell(row, 'hsn');

    if (found == null) {
      // a new product
      if (name.isEmpty) {
        plan.problems.add('A new product needs a Name.');
      } else if (price == null) {
        plan.problems.add('A new product needs a Selling price.');
      } else if (!seenNew.add('${name.toLowerCase()}|${brand.toLowerCase()}')) {
        plan.problems.add('"$name" is on an earlier row too.');
      }
      if (plan.problems.isNotEmpty) {
        plan.status = SheetRowStatus.error;
        continue;
      }
      final p = Product(
        id: newId(),
        name: name,
        category: category,
        unit: unit.isEmpty ? 'pcs' : unit,
        pricePaise: price!,
        costPaise: cost ?? 0,
        stockMilli: stock ?? 0,
        gstBp: gst ?? 1800,
        barcode: barcode,
        hsn: hsn.isEmpty ? '8302' : hsn,
        minStockMilli: minStock ?? 0,
        brand: brand,
        mrpPaise: mrp ?? 0,
      );
      plan.status = SheetRowStatus.create;
      plan.product = p;
      plan.detailsChanged = true;
      if (stock != null && stock != 0) {
        plan.stockTarget = stock;
        plan.changes.add('opening stock ${_q(stock!)}');
      }
      plan.changes.insert(0, 'new product, selling price ${_rs(price!)}');
      _priceWarnings(plan, p.pricePaise, p.costPaise, p.mrpPaise);
      continue;
    }

    // an existing product: only what is typed and different
    var p = found;
    void change(String what, String from, String to) => plan.changes.add('$what $from -> $to');
    if (name.isNotEmpty && name != p.name) {
      change('name', p.name, name);
      p = p.copyWith(name: name);
    }
    if (category.isNotEmpty && category != p.category) {
      change('category', p.category.isEmpty ? '-' : p.category, category);
      p = p.copyWith(category: category);
    }
    if (brand.isNotEmpty && brand != p.brand) {
      change('brand', p.brand.isEmpty ? '-' : p.brand, brand);
      p = p.copyWith(brand: brand);
    }
    if (unit.isNotEmpty && unit != p.unit) {
      change('unit', p.unit, unit);
      p = p.copyWith(unit: unit);
    }
    if (barcode.isNotEmpty && barcode != p.barcode) {
      change('barcode', p.barcode.isEmpty ? '-' : p.barcode, barcode);
      p = p.copyWith(barcode: barcode);
    }
    if (hsn.isNotEmpty && hsn != p.hsn) {
      change('HSN', p.hsn, hsn);
      p = p.copyWith(hsn: hsn);
    }
    if (gst != null && gst != p.gstBp) {
      change('GST %', _rs(p.gstBp), _rs(gst!));
      p = p.copyWith(gstBp: gst);
    }
    if (mrp != null && mrp != p.mrpPaise) {
      change('MRP', _rs(p.mrpPaise), _rs(mrp!));
      p = p.copyWith(mrpPaise: mrp);
    }
    if (price != null && price != p.pricePaise) {
      change('selling price', _rs(p.pricePaise), _rs(price!));
      p = p.copyWith(pricePaise: price);
    }
    if (cost != null && cost != p.costPaise) {
      change('buying price', _rs(p.costPaise), _rs(cost!));
      p = p.copyWith(costPaise: cost);
    }
    if (minStock != null && minStock != p.minStockMilli) {
      change('min stock', _q(p.minStockMilli), _q(minStock!));
      p = p.copyWith(minStockMilli: minStock);
    }
    plan.detailsChanged = plan.changes.isNotEmpty;
    if (stock != null && stock != p.stockMilli) {
      plan.stockTarget = stock;
      plan.stockBefore = p.stockMilli;
      change('stock', _q(p.stockMilli), _q(stock!));
    }
    plan.product = p;
    plan.status = plan.changes.isEmpty ? SheetRowStatus.unchanged : SheetRowStatus.update;
    if (plan.status == SheetRowStatus.unchanged) plan.product = null;
    if (plan.status != SheetRowStatus.unchanged) _priceWarnings(plan, p.pricePaise, p.costPaise, p.mrpPaise);
  }
  return ProductSheetPlan(plans);
}

void _priceWarnings(SheetRowPlan plan, int price, int cost, int mrp) {
  if (cost > 0 && price > 0 && price < cost) plan.warnings.add('Selling price ${_rs(price)} is below the buying price ${_rs(cost)} (a loss on every sale).');
  if (mrp > 0 && price > mrp) plan.warnings.add('Selling price ${_rs(price)} is above the MRP ${_rs(mrp)}.');
}
