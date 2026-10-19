import 'package:drift/drift.dart';
import '../../domain/models.dart';
import '../context.dart';
import '../db/app_database.dart';
import '../ids.dart';
import 'product_codes.dart';

/// Products, categories, customers and dealers. Editable records: every change bumps `version` and `hlc`, and the same transaction
/// writes the upload queue row. Price, cost and credit-limit changes also write an audit row (the rules ask for it when it syncs).
class CatalogRepo {
  CatalogRepo(this.cx);
  final DataContext cx;
  AppDatabase get _db => cx.db;

  // ---------------------------------------------------------------- products

  static Product _product(QueryRow r) => Product(
        id: r.read<String>('id'),
        name: r.read<String>('name'),
        category: r.read<String>('category'),
        unit: r.read<String>('unit'),
        pricePaise: r.read<int>('price_paise'),
        costPaise: r.read<int>('cost_paise'),
        stockMilli: r.read<int>('stock'),
        gstBp: r.read<int>('gst_bp'),
        barcode: r.read<String>('barcode'),
        hsn: r.read<String>('hsn'),
        minStockMilli: r.read<int>('min_stock_milli'),
        code: r.read<String>('code'),
        brand: r.read<String>('brand'),
        mrpPaise: r.read<int>('mrp_paise'),
      );

  static const _productSelect = 'SELECT p.*, COALESCE(s.qty_milli, 0) AS stock FROM products p LEFT JOIN stock_cache s ON s.product_id = p.id';

  /// Newest first (a new product is at the top of the list).
  Future<List<Product>> products({int? limit, int offset = 0}) async {
    final r = await _db.rows('$_productSelect WHERE p.deleted_at IS NULL ORDER BY p.created_at DESC, p.rowid DESC ${limit == null ? '' : 'LIMIT $limit OFFSET $offset'}');
    return [for (final x in r) _product(x)];
  }

  Future<Product?> product(String id) async {
    final r = await _db.row('$_productSelect WHERE p.id = ?', [id]);
    return r == null ? null : _product(r);
  }

  /// A scanned barcode: one product or none. (The `barcode <> ''` part is what lets SQLite use the barcode index.)
  Future<Product?> productByBarcode(String code) async {
    final c = code.trim();
    if (c.isEmpty) return null;
    final r = await _db.row("$_productSelect WHERE p.barcode = ? AND p.barcode <> '' AND p.deleted_at IS NULL", [c]);
    return r == null ? null : _product(r);
  }

  Future<int> productCount() => _db.scalarInt('SELECT COUNT(*) FROM products WHERE deleted_at IS NULL');

  /// Search as you type: every word is a prefix ("hav swi" finds HAVELLS ... SWITCH), or a barcode. Uses the FTS5 index.
  Future<List<Product>> searchProducts(String text, {int limit = 60}) async {
    final q = ftsQuery(text);
    if (q == null) return products(limit: limit);
    final r = await _db.rows('$_productSelect JOIN product_fts f ON f.rowid = p.rowid WHERE product_fts MATCH ? AND p.deleted_at IS NULL ORDER BY rank LIMIT ?', [q, limit]);
    return [for (final x in r) _product(x)];
  }

  /// Turns what a person typed into a safe FTS5 query: each word in quotes with a trailing `*`. Null when nothing searchable was typed.
  static String? ftsQuery(String text) {
    final words = text.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return null;
    return words.map((w) => '"${w.replaceAll('"', '')}"*').join(' ');
  }

  /// Adds a product, or saves changes to an existing one. A changed "stock now" becomes a stock movement (stock is always the sum of movements).
  Future<void> saveProduct(Product p, {required bool create}) {
    return _db.transaction(() async {
      final now = cx.nowMs();
      if (create) {
        final code = p.code.isNotEmpty ? p.code : await nextProductCode(_db, p.category);
        await _db.exec(
          'INSERT INTO products(id, name, category, unit, price_paise, cost_paise, gst_bp, hsn, barcode, min_stock_milli, code, brand, mrp_paise, active, created_at, updated_at, device_id, version, hlc) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,1,?,?,?,1,?)',
          [p.id, p.name, p.category, p.unit, p.pricePaise, p.costPaise, p.gstBp, p.hsn, p.barcode, p.minStockMilli, code, p.brand, p.mrpPaise, now, now, cx.deviceId, cx.hlc.next()],
        );
        await _db.exec('INSERT INTO stock_cache(product_id, qty_milli) VALUES (?, 0) ON CONFLICT(product_id) DO NOTHING', [p.id]);
        if (p.stockMilli != 0) await _move(p.id, p.stockMilli, 'opening', 'Opening stock', now);
      } else {
        final old = await _db.row('$_productSelect WHERE p.id = ?', [p.id]);
        if (old == null) throw StateError('No such product.');
        final before = _product(old);
        await _db.exec(
          'UPDATE products SET name = ?, category = ?, unit = ?, price_paise = ?, cost_paise = ?, gst_bp = ?, barcode = ?, hsn = ?, min_stock_milli = ?, brand = ?, mrp_paise = ?, updated_at = ?, version = version + 1, hlc = ?, device_id = ? WHERE id = ?',
          [p.name, p.category, p.unit, p.pricePaise, p.costPaise, p.gstBp, p.barcode, p.hsn, p.minStockMilli, p.brand, p.mrpPaise, now, cx.hlc.next(), cx.deviceId, p.id],
        );
        if (before.pricePaise != p.pricePaise) await _audit('price', 'product', p.id, 'price', '${before.pricePaise}', '${p.pricePaise}');
        if (before.costPaise != p.costPaise) await _audit('cost', 'product', p.id, 'cost', '${before.costPaise}', '${p.costPaise}');
        final diff = p.stockMilli - before.stockMilli;
        if (diff != 0) await _move(p.id, diff, 'adjustment', 'Edited on the product page', now);
      }
      await enqueue(cx, _db, 'products', p.id);
    });
  }

  Future<void> _move(String productId, int qty, String kind, String note, int at) async {
    await _db.exec('INSERT INTO stock_movements(id, product_id, qty_milli, kind, note, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?)', [newId(), productId, qty, kind, note, at, cx.nowMs(), cx.deviceId]);
    await _db.exec('INSERT INTO stock_cache(product_id, qty_milli) VALUES (?,?) ON CONFLICT(product_id) DO UPDATE SET qty_milli = qty_milli + excluded.qty_milli', [productId, qty]);
  }

  Future<void> _audit(String what, String entity, String entityId, String field, String? oldV, String? newV) async {
    final id = newId();
    await _db.exec('INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)', [id, what, entity, entityId, field, oldV, newV, cx.actor.name, cx.nowMs(), cx.deviceId]);
    await enqueue(cx, _db, 'audit', id);
  }

  // ---------------------------------------------------------------- categories

  Future<List<String>> categoryNames() async => [for (final r in await _db.rows('SELECT name FROM categories WHERE deleted_at IS NULL ORDER BY name COLLATE NOCASE')) r.read<String>('name')];

  Future<void> addCategory(String name) {
    return _db.transaction(() async {
      final id = newId();
      final now = cx.nowMs();
      await _db.exec('INSERT INTO categories(id, name, created_at, updated_at, device_id, hlc) VALUES (?,?,?,?,?,?)', [id, name.trim(), now, now, cx.deviceId, cx.hlc.next()]);
      await enqueue(cx, _db, 'categories', id);
    });
  }

  /// Changes a brand's spelling on every product that carries it (capital letters do not matter when finding them). Returns the ids of
  /// the products changed, so the screens can read them again.
  Future<List<String>> renameBrand(String from, String to) {
    return _db.transaction(() async {
      final ids = [for (final r in await _db.rows('SELECT id FROM products WHERE brand = ? COLLATE NOCASE AND deleted_at IS NULL', [from.trim()])) r.read<String>('id')];
      for (final id in ids) {
        await _db.exec('UPDATE products SET brand = ?, updated_at = ?, version = version + 1, hlc = ?, device_id = ? WHERE id = ?', [to.trim(), cx.nowMs(), cx.hlc.next(), cx.deviceId, id]);
        await enqueue(cx, _db, 'products', id);
      }
      return ids;
    });
  }

  /// Changes a unit's spelling on every product that carries it. Returns the ids of the products changed.
  Future<List<String>> renameUnit(String from, String to) {
    return _db.transaction(() async {
      final ids = [for (final r in await _db.rows('SELECT id FROM products WHERE unit = ? COLLATE NOCASE AND deleted_at IS NULL', [from.trim()])) r.read<String>('id')];
      for (final id in ids) {
        await _db.exec('UPDATE products SET unit = ?, updated_at = ?, version = version + 1, hlc = ?, device_id = ? WHERE id = ?', [to.trim(), cx.nowMs(), cx.hlc.next(), cx.deviceId, id]);
        await enqueue(cx, _db, 'products', id);
      }
      return ids;
    });
  }

  // ---------------------------------------------------------------- customers

  static Customer _customer(QueryRow r) => Customer(
        id: r.read<String>('id'),
        name: r.read<String>('name'),
        phone: r.read<String>('phone'),
        city: r.read<String>('city'),
        address: r.read<String>('address'),
        gstin: r.read<String>('gstin'),
        balancePaise: r.read<int>('balance'),
        creditLimitPaise: r.read<int>('credit_limit_paise'),
      );

  static const _customerSelect = 'SELECT c.*, COALESCE(b.balance_paise, 0) AS balance FROM customers c LEFT JOIN party_balance b ON b.party_id = c.id';

  Future<List<Customer>> customers({int? limit, int offset = 0}) async {
    final r = await _db.rows('$_customerSelect WHERE c.deleted_at IS NULL ORDER BY c.created_at DESC, c.rowid DESC ${limit == null ? '' : 'LIMIT $limit OFFSET $offset'}');
    return [for (final x in r) _customer(x)];
  }

  Future<Customer?> customer(String id) async {
    final r = await _db.row('$_customerSelect WHERE c.id = ?', [id]);
    return r == null ? null : _customer(r);
  }

  Future<List<Customer>> searchCustomers(String text, {int limit = 60}) async {
    final q = text.trim();
    if (q.isEmpty) return customers(limit: limit);
    final like = '%${_like(q)}%';
    final r = await _db.rows("$_customerSelect WHERE c.deleted_at IS NULL AND (c.name LIKE ? ESCAPE '\\' OR c.phone LIKE ? ESCAPE '\\' OR c.city LIKE ? ESCAPE '\\') ORDER BY c.name COLLATE NOCASE LIMIT ?", [like, like, like, limit]);
    return [for (final x in r) _customer(x)];
  }

  static String _like(String s) => s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  Future<void> saveCustomer(Customer c, {required bool create}) {
    return _db.transaction(() async {
      final now = cx.nowMs();
      if (create) {
        await _db.exec(
          'INSERT INTO customers(id, name, phone, city, address, gstin, credit_limit_paise, created_at, updated_at, device_id, version, hlc) VALUES (?,?,?,?,?,?,?,?,?,?,1,?)',
          [c.id, c.name, c.phone, c.city, c.address, c.gstin, c.creditLimitPaise, now, now, cx.deviceId, cx.hlc.next()],
        );
      } else {
        final old = await _db.row('SELECT credit_limit_paise FROM customers WHERE id = ?', [c.id]);
        if (old == null) throw StateError('No such customer.');
        await _db.exec('UPDATE customers SET name = ?, phone = ?, city = ?, address = ?, gstin = ?, credit_limit_paise = ?, updated_at = ?, version = version + 1, hlc = ?, device_id = ? WHERE id = ?', [c.name, c.phone, c.city, c.address, c.gstin, c.creditLimitPaise, now, cx.hlc.next(), cx.deviceId, c.id]);
        final was = old.read<int>('credit_limit_paise');
        if (was != c.creditLimitPaise) await _audit('creditLimit', 'customer', c.id, 'creditLimit', '$was', '${c.creditLimitPaise}');
      }
      await enqueue(cx, _db, 'customers', c.id);
    });
  }

  Future<int> customerCount() => _db.scalarInt('SELECT COUNT(*) FROM customers WHERE deleted_at IS NULL');

  // ---------------------------------------------------------------- dealers (a record with name, phone, city and the balance we owe)

  Future<List<Rec>> dealers() async {
    final r = await _db.rows('SELECT d.*, COALESCE(b.balance_paise, 0) AS balance FROM dealers d LEFT JOIN party_balance b ON b.party_id = d.id WHERE d.deleted_at IS NULL ORDER BY d.created_at DESC, d.rowid DESC');
    return [for (final x in r) Rec(x.read<String>('id'), {'name': x.read<String>('name'), 'phone': x.read<String>('phone'), 'city': x.read<String>('city'), 'balance': x.read<int>('balance')})];
  }

  Future<void> saveDealer(Rec d, {required bool create}) {
    return _db.transaction(() async {
      final now = cx.nowMs();
      if (create) {
        await _db.exec('INSERT INTO dealers(id, name, phone, city, created_at, updated_at, device_id, version, hlc) VALUES (?,?,?,?,?,?,?,1,?)', [d.id, d.s('name'), d.s('phone'), d.s('city'), now, now, cx.deviceId, cx.hlc.next()]);
      } else {
        await _db.exec('UPDATE dealers SET name = ?, phone = ?, city = ?, updated_at = ?, version = version + 1, hlc = ?, device_id = ? WHERE id = ?', [d.s('name'), d.s('phone'), d.s('city'), now, cx.hlc.next(), cx.deviceId, d.id]);
      }
      await enqueue(cx, _db, 'dealers', d.id);
    });
  }
}
