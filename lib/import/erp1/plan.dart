/// Reads an ERP 1 backup (a COPY) and turns it into a validated plan: every record converted to ERP 2.0 units, every problem logged with its
/// reason. Nothing here touches a database, so a dry run is simply "build the plan and print the report".
library;

import 'dart:convert';
import 'checksum.dart';
import 'convert.dart';

/// The file is not an ERP 1 backup, or is too damaged to read at all. The message is plain English for the owner.
class ImportInputError implements Exception {
  ImportInputError(this.message);
  final String message;
  @override
  String toString() => message;
}

enum IssueKind { rejected, repaired, skipped, note }

class IssueBucket {
  IssueBucket(this.entity, this.kind, this.reason);
  final String entity, reason;
  final IssueKind kind;
  int count = 0;
  final examples = <String>[];
}

/// Counts every problem by (entity, kind, reason) and keeps a few example ids, so a hostile file with a million bad rows costs no memory.
class IssueLog {
  final buckets = <String, IssueBucket>{};
  static const maxExamples = 8;

  void add(String entity, String id, IssueKind kind, String reason) {
    final b = buckets.putIfAbsent('$entity|${kind.name}|$reason', () => IssueBucket(entity, kind, reason));
    b.count++;
    if (b.examples.length < maxExamples) b.examples.add(id);
  }

  void fold(String entity, String id, Findings f) {
    final r = f.rejected;
    if (r != null) add(entity, id, IssueKind.rejected, r);
    for (final s in f.repaired) {
      add(entity, id, IssueKind.repaired, s);
    }
    for (final s in f.notes) {
      add(entity, id, IssueKind.note, s);
    }
  }

  int count(IssueKind k, [String? entity]) => buckets.values.where((b) => b.kind == k && (entity == null || b.entity == entity)).fold(0, (a, b) => a + b.count);
}

// ------------------------------------------------------------------ planned rows (ERP 2.0 units)

class PProduct {
  PProduct(this.oldId, this.name);
  final String oldId;
  String name, category = '', unit = 'pcs', hsn = '', barcode = '';
  int pricePaise = 0, costPaise = 0, avgCostPaise = 0, gstBp = 1800, minStockMilli = 0, stockMilli = 0, createdMs = 0;
  bool active = true, deleted = false, placeholder = false;
  String get id => 'e1-prod-$oldId';
}

class PParty {
  PParty(this.oldId, this.name);
  final String oldId;
  String name, phone = '', city = '', address = '', gstin = '';
  int creditLimitPaise = 0, outstandingPaise = 0, createdMs = 0;
  bool deleted = false;
  String kind = 'customer';
  String get id => kind == 'customer' ? 'e1-cust-$oldId' : 'e1-deal-$oldId';
}

class PLine {
  PLine({required this.productOldId, required this.name, required this.unit, required this.qtyMilli, required this.ratePaise, required this.costPaise, required this.discountBp, required this.gstBp, required this.grossPaise, required this.discountPaise, required this.taxablePaise, required this.taxPaise, required this.totalPaise});
  final String productOldId, name, unit;
  final int qtyMilli, ratePaise, costPaise, discountBp, gstBp, grossPaise, discountPaise, taxablePaise, taxPaise, totalPaise;
}

class PBill {
  PBill(this.oldNo, this.at);
  final String oldNo;
  final Moment at;
  String? customerOldId;
  String customerName = '', cancelReason = '', note = '';
  int total = 0, received = 0, balance = 0, taxable = 0, cgst = 0, sgst = 0, igst = 0, discount = 0, roundOff = 0, payMode = 0, seq = 0;
  bool cancelled = false, inclusive = true;
  final lines = <PLine>[];
  String get id => 'e1-bill-$oldNo';
}

class PEntry {
  PEntry(this.id, this.partyKind, this.partyId, this.kind, this.amountPaise, this.atMs, {this.billNo, this.note = '', this.mode, this.refId});
  final String id, partyKind, partyId, kind;
  final int amountPaise, atMs;
  final String? billNo, mode, refId;
  final String note;
}

class PPayment {
  PPayment(this.id, this.partyKind, this.partyId, this.amountPaise, this.mode, this.atMs, this.receiptNo, this.note);
  final String id, partyKind, partyId, mode, receiptNo, note;
  final int amountPaise, atMs;
}

class PMove {
  PMove(this.id, this.productId, this.qtyMilli, this.kind, this.refId, this.atMs, this.unitCostPaise, [this.note = '']);
  final String id, productId, kind, note;
  final String? refId;
  final int qtyMilli, atMs, unitCostPaise;
}

class PEstimate {
  PEstimate(this.oldId, this.number, this.at);
  final String oldId, number;
  final Moment at;
  String? customerOldId, convertedBillOldNo;
  String customerName = '';
  int totalPaise = 0;
  final lines = <PLine>[];
  String get id => 'e1-est-$oldId';
}

class PRecord {
  PRecord(this.id, this.kind, this.atMs, this.fields);
  final String id, kind;
  final int atMs;
  final Map<String, Object> fields; // ERP 2.0 record fields; a DateTime is stored with the usual marker
}

class PCategory {
  PCategory(this.name);
  final String name;
  String get id => 'e1-cat-${name.toLowerCase().hashCode.toRadixString(16)}';
}

/// A correction the OWNER named. Nothing else is ever corrected silently.
class ImportCorrection {
  const ImportCorrection({required this.billOldNo, required this.clearPaise, required this.reason});
  final String billOldNo, reason;
  final int clearPaise;
}

/// The corrections the owner has confirmed (15 Oct 2026: ram's part-paid bill was settled; ERP 1 shows the customer owing nothing).
const ownerConfirmedCorrections = [
  ImportCorrection(billOldNo: 'INV-2627-000001', clearPaise: 6000, reason: 'owner confirmed on 2026-10-15 that the 60.00 unpaid on this bill was cleared'),
];

class AppliedCorrection {
  AppliedCorrection(this.billOldNo, this.amountPaise, this.reason);
  final String billOldNo, reason;
  final int amountPaise;
  String get auditText => 'Corrected during import: bill $billOldNo, ${amountPaise ~/ 100}.${(amountPaise % 100).toString().padLeft(2, '0')} marked paid ($reason)';
}

/// A difference the importer did NOT change: ERP 1's balance for a customer is lower than the bills still showing unpaid add up to.
class NeedsDecision {
  NeedsDecision(this.customer, this.bills, this.differencePaise);
  final String customer;
  final List<String> bills; // "INV-... unpaid 60.00"
  final int differencePaise;
}

/// The whole validated import.
class Erp1Plan {
  final issues = IssueLog();
  final read = <String, int>{}; // records found per ERP 1 key
  final imported = <String, int>{}; // records that will be written per entity
  final unmappedKeys = <String, int>{}; // keys found in the file that this version has no home for
  final products = <String, PProduct>{};
  final customers = <String, PParty>{};
  final dealers = <String, PParty>{};
  final bills = <PBill>[];
  final estimates = <PEstimate>[];
  final entries = <PEntry>[];
  final payments = <PPayment>[];
  final moves = <PMove>[];
  final records = <PRecord>[];
  final categories = <String, PCategory>{};
  final settings = <String, String>{};
  final corrections = <AppliedCorrection>[];
  final decisions = <NeedsDecision>[];
  List<ImportCorrection> allowedCorrections = ownerConfirmedCorrections;
  final openingCustomer = <String, int>{}; // the residual opening entries (to list large ones)
  final openingDealer = <String, int>{};
  final openingStock = <String, int>{};
  String? backupStamp, backupFormat;
  ChecksumResult checksum = ChecksumResult.notPresent;
  int? declaredKeys, declaredRecords;
  int actualKeys = 0, actualRecords = 0;
  int backupMs = 0;

  static const knownKeys = {
    'erp_products', 'erp_categories', 'erp_customers', 'erp_dealers', 'erp_sales_invoices', 'erp_estimations', 'erp_purchases', 'erp_purchase_returns', 'erp_sales_returns',
    'erp_stock_adjustments', 'erp_credit_payments', 'erp_dealer_payments', 'erp_expenses', 'erp_deliveries', 'erp_warranties', 'erp_house_projects', 'erp_staff',
    'erp_notifications', 'erp_settings', 'erp_system_state', 'erp_product_price_history', 'erp_expense_categories', 'erp_daily_closings', 'erp_opening_cash', 'erp_users', 'erp_drafts', 'erp_projects',
  };

  /// Reads the backup text. Throws [ImportInputError] for something that is not a backup at all; anything wrong inside a record is logged, not thrown.
  static Erp1Plan parse(String text, {List<ImportCorrection> corrections = ownerConfirmedCorrections}) {
    Object? root;
    try {
      root = jsonDecode(text);
    } catch (_) {
      throw ImportInputError('This file is not a readable ERP 1 backup (it is not valid JSON). Nothing was changed.');
    }
    if (root is! Map<String, dynamic>) throw ImportInputError('This file is not an ERP 1 backup (it is not a set of saved records). Nothing was changed.');
    final data = root['data'];
    if (data is! Map<String, dynamic>) throw ImportInputError('This file is not an ERP 1 backup (it has no "data" section). Nothing was changed.');
    final p = Erp1Plan()..allowedCorrections = corrections;
    final meta0 = root['_metadata'];
    final fmt = meta0 is Map ? '${meta0['format'] ?? ''}' : '';
    if (!fmt.startsWith('senthil_erp') && !data.keys.any((k) => knownKeys.contains(k))) {
      throw ImportInputError('This file is not an ERP 1 backup: none of the lists ERP 1 saves (products, customers, bills ...) are in it. Nothing was changed.');
    }
    final meta = root['_metadata'];
    if (meta is Map<String, dynamic>) {
      p.backupFormat = text_(meta['format']);
      p.backupStamp = text_(meta['timestamp']);
      p.backupMs = moment(meta['timestamp'])?.ms ?? 0;
      p.declaredKeys = meta['keyCount'] is int ? meta['keyCount'] as int : null;
      p.declaredRecords = meta['recordCount'] is int ? meta['recordCount'] as int : null;
    }
    p.checksum = verifyChecksum(data, meta);
    p.actualKeys = data.length;
    for (final v in data.values) {
      p.actualRecords += v is List ? v.length : 1;
    }
    try {
      _Builder(p, data).run();
    } on ImportInputError {
      rethrow;
    } catch (e) {
      throw ImportInputError('The backup could not be read to the end ($e). Nothing was changed.');
    }
    return p;
  }

  static String text_(Object? v) => v is String ? v : '';
}

// ------------------------------------------------------------------ the builder

int _divRound(int a, int b) => b == 0 ? 0 : ((a * 2 + (a >= 0 ? b : -b)) ~/ (2 * b));

class _Builder {
  _Builder(this.p, this.data);
  final Erp1Plan p;
  final Map<String, dynamic> data;
  IssueLog get log => p.issues;

  List<Map<String, dynamic>> list(String key, {String? entity}) {
    final v = data[key];
    if (v == null) return const [];
    if (v is Map<String, dynamic> && v.containsKey('__rawText')) {
      log.add(entity ?? key, key, IssueKind.rejected, 'the whole list was not readable text (saved as raw text)');
      return const [];
    }
    if (v is! List) {
      log.add(entity ?? key, key, IssueKind.rejected, 'the list is not a list');
      return const [];
    }
    p.read[key] = v.length;
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < v.length; i++) {
      final r = v[i];
      if (r is Map<String, dynamic>) {
        out.add(r);
      } else {
        log.add(entity ?? key, '#$i', IssueKind.rejected, 'the record is not an object');
      }
    }
    return out;
  }

  void bump(String entity) => p.imported[entity] = (p.imported[entity] ?? 0) + 1;

  void run() {
    for (final k in data.keys) {
      if (!Erp1Plan.knownKeys.contains(k)) {
        final n = data[k] is List ? (data[k] as List).length : 1;
        p.unmappedKeys[k] = n;
      }
    }
    _settings();
    _categories();
    _products();
    _parties();
    _bills();
    _estimates();
    _creditPayments();
    _purchases();
    _dealerPayments();
    _adjustments();
    _otherRecords();
    _closeLedgers();
    _closeStock();
    _countSkippedKeys();
  }

  // ---------------------------------------------------------------- settings
  void _settings() {
    final s = data['erp_settings'];
    if (s is! Map<String, dynamic>) return;
    p.read['erp_settings'] = 1;
    for (final e in const {'shopName': 'name', 'ownerName': 'ownerName', 'address': 'address', 'phone': 'phone', 'gstin': 'gstin', 'invoicePrefix': 'oldInvoicePrefix', 'footerMessage': 'billFooter'}.entries) {
      final v = text(s[e.key], max: 300);
      if (v.isNotEmpty) p.settings[e.value] = v;
    }
    bump('settings');
  }

  // ---------------------------------------------------------------- categories, products
  void _categories() {
    for (final r in list('erp_categories', entity: 'categories')) {
      final f = Findings();
      final n = text(r['name'], max: 80, f: f, what: 'category name');
      if (n.isEmpty) {
        log.add('categories', text(r['id']), IssueKind.rejected, 'no name');
        continue;
      }
      p.categories.putIfAbsent(n.toLowerCase(), () => PCategory(n));
      log.fold('categories', text(r['id']), f);
    }
  }

  void _products() {
    final barcodes = <String>{};
    for (final r in list('erp_products', entity: 'products')) {
      final id = text(r['id'], max: 80);
      final f = Findings();
      if (id.isEmpty) {
        log.add('products', '?', IssueKind.rejected, 'no id');
        continue;
      }
      if (p.products.containsKey(id)) {
        log.add('products', id, IssueKind.rejected, 'the same id appears twice (the first one is kept)');
        continue;
      }
      final name = text(r['name'], max: 200, f: f, what: 'name');
      if (name.isEmpty) {
        log.add('products', id, IssueKind.rejected, 'no name');
        continue;
      }
      final pr = PProduct(id, name);
      pr.category = text(r['category'], max: 80, f: f, what: 'category');
      final unit = text(r['unit'], max: 20);
      pr.unit = unit.isEmpty ? 'pcs' : unit;
      pr.pricePaise = paise(r['price'] ?? r['sellingPrice'], f, 'selling price', missing: 0) ?? 0;
      pr.costPaise = paise(r['buyingPrice'] ?? r['costPrice'], f, 'buying price', missing: 0) ?? 0;
      pr.avgCostPaise = paise(r['avgCost'], f, 'average cost', missing: 0) ?? 0;
      pr.gstBp = percentBp(r['taxRate'] ?? r['gst'] ?? r['gstRate'], f, missing: 1800);
      pr.hsn = text(r['hsn'] ?? r['hsnCode'], max: 20, f: f, what: 'HSN');
      var bc = text(r['barcode'] ?? r['sku'], max: 64, f: f, what: 'barcode');
      if (bc.isNotEmpty && !barcodes.add(bc)) {
        f.repair('the barcode was already used by another product (blanked)');
        bc = '';
      }
      pr.barcode = bc;
      pr.minStockMilli = milli(r['minStock'] ?? r['reorderLevel'], f, 'minimum stock', missing: 0) ?? 0;
      final st = milli(r['stock'] ?? r['quantity'], f, 'stock', negativeOk: true, missing: 0) ?? 0;
      if (st < 0) f.note('stock was negative in ERP 1 (kept as it is)');
      pr.stockMilli = st;
      pr.deleted = truthy(r['isDeleted']);
      pr.active = r.containsKey('status') ? truthy(r['status'], otherwise: true) : truthy(r['isActive'], otherwise: true);
      pr.createdMs = moment(r['createdAt'])?.ms ?? 0;
      if (f.rejected != null) {
        log.fold('products', id, f);
        continue;
      }
      if (pr.category.isNotEmpty) p.categories.putIfAbsent(pr.category.toLowerCase(), () => PCategory(pr.category));
      p.products[id] = pr;
      bump('products');
      log.fold('products', id, f);
    }
  }

  // ---------------------------------------------------------------- customers, dealers
  void _parties() {
    for (final kind in const ['customer', 'dealer']) {
      final key = kind == 'customer' ? 'erp_customers' : 'erp_dealers';
      final entity = kind == 'customer' ? 'customers' : 'dealers';
      final target = kind == 'customer' ? p.customers : p.dealers;
      for (final r in list(key, entity: entity)) {
        final id = text(r['id'], max: 80);
        final f = Findings();
        if (id.isEmpty) {
          log.add(entity, '?', IssueKind.rejected, 'no id');
          continue;
        }
        if (target.containsKey(id)) {
          log.add(entity, id, IssueKind.rejected, 'the same id appears twice (the first one is kept)');
          continue;
        }
        final name = text(kind == 'dealer' ? (r['companyName'] ?? r['name']) : r['name'], max: 200, f: f, what: 'name');
        if (name.isEmpty) {
          log.add(entity, id, IssueKind.rejected, 'no name');
          continue;
        }
        final c = PParty(id, name)..kind = kind;
        c.phone = text(r['phone'], max: 30, f: f, what: 'phone');
        c.city = text(r['area'] ?? r['city'], max: 100, f: f, what: 'area');
        c.address = text(r['address'], max: 300, f: f, what: 'address');
        c.gstin = text(r['gst'] ?? r['gstin'], max: 20, f: f, what: 'GSTIN');
        c.creditLimitPaise = paise(r['creditLimit'], f, 'credit limit', missing: 0) ?? 0;
        c.outstandingPaise = paise(r['outstanding'], f, 'outstanding', negativeOk: true, missing: 0) ?? 0;
        c.deleted = truthy(r['isDeleted']);
        c.createdMs = moment(r['createdAt'])?.ms ?? 0;
        if (kind == 'customer') {
          for (final k in const ['whatsapp', 'type', 'creditDays', 'notes', 'pin']) {
            if (text(r[k]).isNotEmpty) f.note('$k has no place in ERP 2.0 yet (listed only)');
          }
        }
        if (f.rejected != null) {
          log.fold(entity, id, f);
          continue;
        }
        target[id] = c;
        bump(entity);
        log.fold(entity, id, f);
      }
    }
  }

  // ---------------------------------------------------------------- sales invoices
  PProduct _placeholder(String oldId, String name) {
    final existing = p.products[oldId];
    if (existing != null) return existing;
    final pr = PProduct(oldId.isEmpty ? 'unknown' : oldId, name.isEmpty ? 'Unknown item (ERP 1 id $oldId)' : name)..placeholder = true;
    pr.active = false;
    p.products[pr.oldId] = pr;
    log.add('products', pr.oldId, IssueKind.note, 'a bill line named a product that is not in the product list (a placeholder was created)');
    return pr;
  }

  PLine? _line(Map<String, dynamic> it, Findings f, {required bool inclusiveDefault}) {
    final qty = milli(it['qty'] ?? it['quantity'], f, 'quantity', missing: 0) ?? 0;
    if (qty <= 0) {
      f.repair('a line without a quantity above zero was skipped');
      return null;
    }
    final rate = paise(it['price'] ?? it['rate'], f, 'rate', missing: 0) ?? 0;
    final gst = percentBp(it['taxRate'] ?? it['gst'], f);
    final inclusive = (text(it['pricingMode']).toLowerCase() == 'exclusive') ? false : inclusiveDefault;
    final gross = _divRound(rate * qty, 1000);
    final dPct = asNum(it['discountPercent']);
    final dBp = dPct == null || dPct < 0 || dPct > 100 ? 0 : (dPct * 100).round();
    final dAmt = paise(it['discountAmount'], f, 'discount', missing: null);
    final disc = dAmt != null && dAmt > 0 ? dAmt : _divRound(gross * dBp, 10000);
    final net = gross - disc;
    final given = paise(it['total'], f, 'line total', missing: null);
    int taxable, tax, total;
    if (inclusive) {
      total = given ?? net;
      taxable = _divRound(total * 10000, 10000 + gst);
      tax = total - taxable;
    } else if (given == null || (given - net).abs() <= 1) {
      taxable = net;
      tax = _divRound(net * gst, 10000);
      total = taxable + tax;
    } else {
      total = given;
      taxable = _divRound(total * 10000, 10000 + gst);
      tax = total - taxable;
    }
    final pid = text(it['productId'], max: 80);
    return PLine(
      productOldId: pid,
      name: text(it['name'] ?? it['productName'], max: 200, f: f, what: 'line name'),
      unit: () {
        final u = text(it['unit'], max: 20);
        return u.isEmpty ? 'pcs' : u;
      }(),
      qtyMilli: qty,
      ratePaise: rate,
      costPaise: paise(it['costPrice'], f, 'cost', missing: 0) ?? 0,
      discountBp: dBp,
      gstBp: gst,
      grossPaise: gross,
      discountPaise: disc,
      taxablePaise: taxable,
      taxPaise: tax,
      totalPaise: total,
    );
  }

  void _bills() {
    final seen = <String>{};
    final all = <PBill>[];
    for (final r in list('erp_sales_invoices', entity: 'bills')) {
      final oldNo = text(r['invoiceNumber'] ?? r['id'], max: 60);
      final f = Findings();
      if (oldNo.isEmpty) {
        log.add('bills', '?', IssueKind.rejected, 'no bill number');
        continue;
      }
      if (truthy(r['isDeleted'])) {
        log.add('bills', oldNo, IssueKind.skipped, 'deleted in ERP 1 (not imported)');
        continue;
      }
      if (!seen.add(oldNo)) {
        log.add('bills', oldNo, IssueKind.rejected, 'the same bill number appears twice (the first one is kept)');
        continue;
      }
      final at = moment(r['date'] ?? r['createdAt']);
      if (at == null) {
        log.add('bills', oldNo, IssueKind.rejected, 'the date is missing or not a real date');
        continue;
      }
      final b = PBill(oldNo, at);
      final statusText = text(r['status']).toLowerCase();
      final payStatus = text(r['paymentStatus']).toLowerCase();
      b.cancelled = statusText == 'cancelled' || payStatus == 'cancelled' || truthy(r['isCancelled']);
      b.cancelReason = text(r['cancelReason'], max: 200);
      b.customerName = text(r['customerName'], max: 200, f: f, what: 'customer name');
      final cid = text(r['customerId'], max: 80);
      if (cid.isNotEmpty) {
        if (p.customers.containsKey(cid)) {
          b.customerOldId = cid;
        } else {
          f.note('the customer is not in the customer list (the bill keeps the name only)');
        }
      }
      final items = r['items'];
      if (items is List) {
        for (final it in items) {
          if (it is! Map<String, dynamic>) {
            f.repair('a line that is not an object was skipped');
            continue;
          }
          final lf = Findings();
          final line = _line(it, lf, inclusiveDefault: text(r['pricingMode']).toLowerCase() != 'exclusive');
          f.repaired.addAll(lf.repaired.where((x) => !f.repaired.contains(x)));
          if (lf.rejected != null) {
            f.repair('a line was skipped: ${lf.rejected}');
            continue;
          }
          if (line == null) continue;
          b.lines.add(line);
        }
      } else if (items != null) {
        f.repair('the items were not a list (no lines imported)');
      }
      if (b.lines.isEmpty) f.note('the bill has no lines (kept with its totals)');
      final lineSum = b.lines.fold(0, (a, l) => a + l.totalPaise);
      final lineTax = b.lines.fold(0, (a, l) => a + l.taxPaise);
      final lineTaxable = b.lines.fold(0, (a, l) => a + l.taxablePaise);
      b.total = paise(r['totalAmount'] ?? r['total'] ?? r['grandTotal'], f, 'total', negativeOk: true, missing: null) ?? lineSum;
      if (r['totalAmount'] == null && r['total'] == null && r['grandTotal'] == null) f.repair('the bill total was missing (taken from the lines)');
      if (b.total < 0) {
        f.rejected = 'negative bill total';
      }
      b.taxable = paise(r['taxableAmount'], f, 'taxable amount', missing: null) ?? lineTaxable;
      b.cgst = paise(r['cgstTotal'], f, 'CGST', missing: null) ?? lineTax ~/ 2;
      b.sgst = paise(r['sgstTotal'], f, 'SGST', missing: null) ?? (lineTax - lineTax ~/ 2);
      b.igst = paise(r['igstTotal'], f, 'IGST', missing: 0) ?? 0;
      b.discount = paise(r['discount'], f, 'discount', missing: 0) ?? 0;
      b.roundOff = paise(r['roundOff'], f, 'round-off', negativeOk: true, missing: 0) ?? 0;
      final mode = text(r['paymentMode']).toLowerCase();
      b.payMode = switch (mode) {
        'cash' || '' => 0,
        'upi' || 'gpay' || 'phonepe' || 'paytm' => 1,
        'card' || 'debit card' || 'credit card' => 2,
        'credit' => 3,
        _ => 0,
      };
      if (mode.isNotEmpty && !const {'cash', 'upi', 'gpay', 'phonepe', 'paytm', 'card', 'debit card', 'credit card', 'credit'}.contains(mode)) {
        f.repair('unknown payment mode "$mode" (read as cash)');
      }
      final paid = paise(r['amountPaid'], f, 'amount paid', missing: null);
      var received = paid ?? (payStatus.contains('pending') || statusText.contains('pending') ? 0 : b.total);
      if (received > b.total) {
        f.repair('amount paid was more than the total (reduced to the total)');
        received = b.total;
      }
      b.received = received;
      b.balance = b.cancelled ? 0 : b.total - received;
      if ((lineSum - (b.total - b.roundOff)).abs() > 100 && b.lines.isNotEmpty) f.note('the lines add up to a different amount than the bill total (the bill total is kept)');
      if (b.balance > 0 && b.customerOldId == null) f.note('money is owed on this bill but no known customer is attached');
      if (f.rejected != null) {
        log.fold('bills', oldNo, f);
        continue;
      }
      for (final l in b.lines) {
        if (!p.products.containsKey(l.productOldId)) _placeholder(l.productOldId, l.name);
      }
      all.add(b);
      log.fold('bills', oldNo, f);
    }
    all.sort((a, b) {
      final c = a.at.ms.compareTo(b.at.ms);
      return c != 0 ? c : a.oldNo.compareTo(b.oldNo);
    });
    for (var i = 0; i < all.length; i++) {
      final b = all[i]..seq = i + 1;
      p.bills.add(b);
      bump('bills');
      if (!b.cancelled) {
        for (var n = 0; n < b.lines.length; n++) {
          final l = b.lines[n];
          p.moves.add(PMove('e1-mov-sale-${b.oldNo}-$n', p.products[l.productOldId]!.id, -l.qtyMilli, 'sale', b.id, b.at.ms, l.costPaise));
        }
        final cid = b.customerOldId;
        if (cid != null && b.balance > 0) {
          p.entries.add(PEntry('e1-led-bill-${b.oldNo}', 'customer', p.customers[cid]!.id, 'billCredit', b.balance, b.at.ms, billNo: b.oldNo, note: 'From ERP 1'));
        }
      }
    }
  }

  // ---------------------------------------------------------------- estimates
  void _estimates() {
    for (final r in list('erp_estimations', entity: 'estimates')) {
      final id = text(r['id'], max: 80);
      if (id.isEmpty) {
        log.add('estimates', '?', IssueKind.rejected, 'no id');
        continue;
      }
      if (truthy(r['isDeleted'])) {
        log.add('estimates', id, IssueKind.skipped, 'deleted in ERP 1 (not imported)');
        continue;
      }
      final f = Findings();
      final at = moment(r['date'] ?? r['createdAt']);
      if (at == null) {
        log.add('estimates', id, IssueKind.rejected, 'the date is missing or not a real date');
        continue;
      }
      if (!estSeen.add(id)) {
        log.add('estimates', id, IssueKind.rejected, 'the same id appears twice (the first one is kept)');
        continue;
      }
      var number = text(r['estimateNumber'] ?? r['number'] ?? id, max: 40);
      if (!estNumbers.add(number)) {
        number = '$number-$id';
        estNumbers.add(number);
        f.repair('the estimate number was used twice (the id was added to it)');
      }
      final e = PEstimate(id, number, at);
      e.customerName = text(r['customerName'], max: 200, f: f, what: 'customer name');
      final cid = text(r['customerId'], max: 80);
      if (p.customers.containsKey(cid)) e.customerOldId = cid;
      final items = r['items'];
      if (items is List) {
        for (final it in items) {
          if (it is! Map<String, dynamic>) continue;
          final lf = Findings();
          final l = _line(it, lf, inclusiveDefault: true);
          if (l != null && lf.rejected == null) {
            e.lines.add(l);
            if (!p.products.containsKey(l.productOldId)) _placeholder(l.productOldId, l.name);
          }
        }
      }
      e.totalPaise = paise(r['totalAmount'] ?? r['total'], f, 'total', missing: null) ?? e.lines.fold<int>(0, (a, l) => a + l.totalPaise);
      final conv = text(r['convertedInvoiceId'] ?? r['invoiceId']);
      if (conv.isNotEmpty) e.convertedBillOldNo = conv;
      if (text(r['status']).toLowerCase() == 'converted' && conv.isEmpty) f.note('the estimate was converted but the bill is not named');
      p.estimates.add(e);
      bump('estimates');
      log.fold('estimates', id, f);
    }
  }

  // ---------------------------------------------------------------- payments
  final paySeen = <String>{};
  final estSeen = <String>{};
  final estNumbers = <String>{};

  void _creditPayments() {
    var i = 0;
    for (final r in list('erp_credit_payments', entity: 'customer payments')) {
      i++;
      final id = text(r['id'], max: 80).isEmpty ? 'idx$i' : text(r['id'], max: 80);
      final f = Findings();
      if (truthy(r['isDeleted'])) {
        log.add('customer payments', id, IssueKind.skipped, 'deleted in ERP 1 (not imported)');
        continue;
      }
      final cid = text(r['customerId'], max: 80);
      final c = p.customers[cid];
      if (c == null) {
        log.add('customer payments', id, IssueKind.rejected, 'the customer is not in the customer list');
        continue;
      }
      final amt = paise(r['amount'], f, 'amount', missing: 0) ?? 0;
      if (amt <= 0) {
        log.add('customer payments', id, IssueKind.rejected, 'the amount is not above zero');
        continue;
      }
      final at = moment(r['date'] ?? r['createdAt']);
      if (at == null) {
        log.add('customer payments', id, IssueKind.rejected, 'the date is missing or not a real date');
        continue;
      }
      if (f.rejected != null) {
        log.fold('customer payments', id, f);
        continue;
      }
      if (!paySeen.add('c$id')) {
        log.add('customer payments', id, IssueKind.rejected, 'the same id appears twice (the first one is kept)');
        continue;
      }
      final mode = text(r['method'] ?? r['paymentMode'], max: 20).toLowerCase();
      final eid = 'e1-pay-$id';
      p.payments.add(PPayment(eid, 'customer', c.id, amt, mode.isEmpty ? 'cash' : mode, at.ms, id, text(r['note'] ?? r['notes'], max: 200)));
      p.entries.add(PEntry('e1-led-$id', 'customer', c.id, 'payment', -amt, at.ms, note: 'From ERP 1', mode: mode.isEmpty ? 'cash' : mode, refId: eid));
      bump('customer payments');
      log.fold('customer payments', id, f);
    }
  }

  void _dealerPayments() {
    var i = 0;
    for (final r in list('erp_dealer_payments', entity: 'dealer payments')) {
      i++;
      final id = text(r['id'], max: 80).isEmpty ? 'idx$i' : text(r['id'], max: 80);
      final f = Findings();
      if (truthy(r['isDeleted'])) {
        log.add('dealer payments', id, IssueKind.skipped, 'deleted in ERP 1 (not imported)');
        continue;
      }
      final d = p.dealers[text(r['dealerId'], max: 80)];
      if (d == null) {
        log.add('dealer payments', id, IssueKind.rejected, 'the dealer is not in the dealer list');
        continue;
      }
      final amt = paise(r['amount'], f, 'amount', missing: 0) ?? 0;
      final at = moment(r['date'] ?? r['createdAt']);
      if (amt <= 0 || at == null) {
        log.add('dealer payments', id, IssueKind.rejected, amt <= 0 ? 'the amount is not above zero' : 'the date is missing or not a real date');
        continue;
      }
      if (!paySeen.add('d$id')) {
        log.add('dealer payments', id, IssueKind.rejected, 'the same id appears twice (the first one is kept)');
        continue;
      }
      final mode = text(r['method'], max: 20).toLowerCase();
      p.payments.add(PPayment('e1-dpay-$id', 'dealer', d.id, amt, mode.isEmpty ? 'cash' : mode, at.ms, 'D-$id', text(r['note'], max: 200)));
      p.entries.add(PEntry('e1-led-d$id', 'dealer', d.id, 'payment', -amt, at.ms, note: 'From ERP 1', mode: mode.isEmpty ? 'cash' : mode, refId: 'e1-dpay-$id'));
      bump('dealer payments');
      log.fold('dealer payments', id, f);
    }
  }

  // ---------------------------------------------------------------- purchases
  void _purchases() {
    final seen = <String>{};
    for (final r in list('erp_purchases', entity: 'purchases')) {
      final id = text(r['id'], max: 80);
      final f = Findings();
      if (id.isEmpty) {
        log.add('purchases', '?', IssueKind.rejected, 'no id');
        continue;
      }
      if (truthy(r['isDeleted'])) {
        log.add('purchases', id, IssueKind.skipped, 'deleted in ERP 1 (not imported)');
        continue;
      }
      if (!seen.add(id)) {
        log.add('purchases', id, IssueKind.rejected, 'the same id appears twice (the first one is kept)');
        continue;
      }
      final at = moment(r['date'] ?? r['createdAt']);
      if (at == null) {
        log.add('purchases', id, IssueKind.rejected, 'the date is missing or not a real date');
        continue;
      }
      final status = text(r['status']).toLowerCase();
      final cancelled = status == 'cancelled';
      final pending = status == 'pending';
      final applied = r['stockApplied'] == null ? (!pending && !cancelled) : truthy(r['stockApplied']);
      final dealer = p.dealers[text(r['dealerId'], max: 80)];
      final items = r['items'];
      var itemSum = 0;
      final moves = <PMove>[];
      if (items is List) {
        var n = 0;
        for (final it in items) {
          n++;
          if (it is! Map<String, dynamic>) continue;
          final lf = Findings();
          final qty = milli(it['qty'] ?? it['quantity'], lf, 'quantity', missing: 0) ?? 0;
          final cost = paise(it['costPrice'] ?? it['purchasePrice'] ?? it['price'], lf, 'cost', missing: 0) ?? 0;
          itemSum += _divRound(cost * qty, 1000);
          final prod = p.products[text(it['productId'], max: 80)];
          if (qty <= 0) continue;
          if (prod == null) {
            f.note('a purchase line names a product that is not in the product list (no stock added for it)');
            continue;
          }
          if (applied && !cancelled) moves.add(PMove('e1-mov-pur-$id-$n', prod.id, qty, 'purchase', 'e1-pur-$id', at.ms, cost));
        }
      }
      final total = paise(r['totalAmount'] ?? r['total'], f, 'total', missing: null) ?? itemSum;
      final paid = paise(r['amountPaid'], f, 'amount paid', missing: 0) ?? 0;
      if (total < 0 || f.rejected != null) {
        log.add('purchases', id, IssueKind.rejected, f.rejected ?? 'negative total');
        continue;
      }
      p.moves.addAll(moves);
      if (dealer != null && !cancelled && total - paid > 0) {
        p.entries.add(PEntry('e1-led-pur-$id', 'dealer', dealer.id, 'billCredit', total - paid, at.ms, billNo: text(r['invoiceNumber'] ?? id, max: 40), note: 'Purchase from ERP 1'));
      } else if (dealer == null && text(r['dealerId']).isNotEmpty) {
        f.note('the dealer is not in the dealer list (the purchase keeps the name only)');
      }
      p.records.add(PRecord('e1-pur-$id', 'purchases', at.ms, {
        'no': text(r['purchaseNumber'] ?? id, max: 40),
        'date': DateTime.fromMillisecondsSinceEpoch(at.ms),
        'dealer': dealer?.name ?? text(r['dealerName'], max: 200),
        'invoice': text(r['invoiceNumber'] ?? r['billNumber'], max: 60),
        'amount': total,
        'status': pending ? 'pending' : 'received',
        'oldId': id,
      }));
      bump('purchases');
      log.fold('purchases', id, f);
    }
  }

  // ---------------------------------------------------------------- stock adjustments
  void _adjustments() {
    var i = 0;
    for (final r in list('erp_stock_adjustments', entity: 'stock adjustments')) {
      i++;
      final id = text(r['id'], max: 80).isEmpty ? 'idx$i' : text(r['id'], max: 80);
      final f = Findings();
      final prod = p.products[text(r['productId'], max: 80)];
      if (prod == null) {
        log.add('stock adjustments', id, IssueKind.rejected, 'the product is not in the product list');
        continue;
      }
      final at = moment(r['date'] ?? r['createdAt']);
      if (at == null) {
        log.add('stock adjustments', id, IssueKind.rejected, 'the date is missing or not a real date');
        continue;
      }
      final prev = milli(r['previousStock'], f, 'previous stock', negativeOk: true, missing: null);
      final next = milli(r['newStock'], f, 'new stock', negativeOk: true, missing: null);
      int delta;
      if (prev != null && next != null) {
        delta = next - prev;
      } else {
        final q = milli(r['qty'], f, 'quantity', missing: 0) ?? 0;
        final type = text(r['type']).toLowerCase();
        delta = const {'found', 'manual add', 'add'}.contains(type) ? q : -q;
        f.repair('the old and new stock were not both saved (the change was worked out from the type)');
      }
      p.moves.add(PMove('e1-mov-adj-$id', prod.id, delta, 'adjustment', null, at.ms, 0, text(r['reason'], max: 200)));
      bump('stock adjustments');
      log.fold('stock adjustments', id, f);
    }
  }

  // ---------------------------------------------------------------- the small record kinds
  void _otherRecords() {
    void simple(String key, String kind, String entity, Map<String, Object> Function(Map<String, dynamic> r, Findings f, int atMs) build, {String? dealerKey}) {
      var i = 0;
      for (final r in list(key, entity: entity)) {
        i++;
        final id = text(r['id'], max: 80).isEmpty ? 'idx$i' : text(r['id'], max: 80);
        final f = Findings();
        if (truthy(r['isDeleted'])) {
          log.add(entity, id, IssueKind.skipped, 'deleted in ERP 1 (not imported)');
          continue;
        }
        final at = moment(r['date'] ?? r['createdAt']);
        if (at == null && kind != 'staff') {
          log.add(entity, id, IssueKind.rejected, 'the date is missing or not a real date');
          continue;
        }
        final ms = at?.ms ?? (moment(r['createdAt'])?.ms ?? p.backupMs);
        try {
          final fields = build(r, f, ms);
          if (f.rejected != null) {
            log.fold(entity, id, f);
            continue;
          }
          fields['oldId'] = id;
          fields['date'] = DateTime.fromMillisecondsSinceEpoch(ms);
          p.records.add(PRecord('e1-$kind-$id', kind, ms, fields));
          bump(entity);
          log.fold(entity, id, f);
        } catch (_) {
          log.add(entity, id, IssueKind.rejected, 'the record has an unexpected shape');
        }
      }
    }

    String custName(Map<String, dynamic> r) => p.customers[text(r['customerId'], max: 80)]?.name ?? text(r['customerName'], max: 200);
    String dealerName(Map<String, dynamic> r) => p.dealers[text(r['dealerId'], max: 80)]?.name ?? text(r['dealerName'], max: 200);

    simple('erp_sales_returns', 'salesReturns', 'sales returns', (r, f, ms) {
      final amt = paise(r['amount'] ?? r['totalAmount'], f, 'amount', missing: 0) ?? 0;
      return {'no': text(r['returnNumber'] ?? r['id'], max: 40), 'customer': custName(r), 'bill': text(r['invoice'] ?? r['invoiceId'], max: 60), 'reason': text(r['reason'], max: 200), 'amount': amt};
    });
    simple('erp_purchase_returns', 'purchaseReturns', 'purchase returns', (r, f, ms) {
      final amt = paise(r['amount'] ?? r['totalAmount'], f, 'amount', missing: 0) ?? 0;
      return {'no': text(r['returnNumber'] ?? r['id'], max: 40), 'dealer': dealerName(r), 'reason': text(r['reason'], max: 200), 'amount': amt};
    });
    simple('erp_expenses', 'expenses', 'expenses', (r, f, ms) {
      final amt = paise(r['amount'], f, 'amount', missing: 0) ?? 0;
      if (amt <= 0) f.rejected = 'the amount is not above zero';
      return {'category': text(r['category'], max: 80), 'note': text(r['description'] ?? r['note'], max: 200), 'amount': amt, 'method': text(r['method'], max: 20)};
    });
    Map<String, Object> generic(Map<String, dynamic> r, Findings f, int ms) {
      final out = <String, Object>{};
      for (final e in r.entries) {
        final k = e.key;
        if (k == 'id' || k == 'isDeleted' || k == 'date') continue;
        final v = e.value;
        if (v is String) {
          out[k] = text(v, max: 300);
        } else if (v is num && v.isFinite) {
          out[k] = const {'amount', 'budget', 'spent', 'cost', 'price', 'total', 'salary'}.contains(k) ? (paise(v, f, k, missing: 0) ?? 0) : v;
        } else if (v is bool) {
          out[k] = v;
        }
      }
      return out;
    }

    simple('erp_deliveries', 'delivery', 'deliveries', generic);
    simple('erp_warranties', 'warranty', 'warranties', generic);
    simple('erp_staff', 'staff', 'staff', generic);
    simple('erp_notifications', 'notifications', 'notifications', generic);
    for (final k in ['erp_daily_closings', 'erp_opening_cash', 'erp_product_price_history', 'erp_users', 'erp_drafts', 'erp_projects', 'erp_expense_categories', 'erp_house_projects']) {
      final v = data[k];
      if (v is List) {
        p.unmappedKeys[k] = v.length;
      } else if (v != null) {
        p.unmappedKeys[k] = 1;
      }
    }
  }

  // ---------------------------------------------------------------- balances and stock close
  /// Only the corrections the owner named are applied (each listed in the report and written to the audit table). Every other place where ERP 1's balance
  /// of a customer is lower than the unpaid bills add up to is left exactly as it is and listed as "needs the owner's decision".
  void _clearShortfalls() {
    final billByNo = {for (final b in p.bills) b.oldNo: b};
    for (final c in p.allowedCorrections) {
      final b = billByNo[c.billOldNo];
      if (b == null || b.cancelled || b.balance < c.clearPaise) {
        log.add('bills', c.billOldNo, IssueKind.note, 'a correction the owner named could not be applied (bill missing, cancelled or owing less than named)');
        continue;
      }
      final i = p.entries.indexWhere((e) => e.kind == 'billCredit' && e.billNo == c.billOldNo);
      if (i >= 0) {
        final e = p.entries[i];
        if (e.amountPaise == c.clearPaise) {
          p.entries.removeAt(i);
        } else {
          p.entries[i] = PEntry(e.id, e.partyKind, e.partyId, e.kind, e.amountPaise - c.clearPaise, e.atMs, billNo: e.billNo, note: e.note, mode: e.mode, refId: e.refId);
        }
      }
      b.balance -= c.clearPaise;
      b.received += c.clearPaise;
      p.corrections.add(AppliedCorrection(c.billOldNo, c.clearPaise, c.reason));
    }
    final sums = <String, int>{};
    for (final e in p.entries) {
      if (e.partyKind == 'customer') sums[e.partyId] = (sums[e.partyId] ?? 0) + e.amountPaise;
    }
    for (final c in p.customers.values) {
      final sum = sums[c.id] ?? 0;
      if (sum <= c.outstandingPaise) continue;
      final open = [for (final b in p.bills) if (b.customerOldId == c.oldId && !b.cancelled && b.balance > 0) '${b.oldNo} unpaid ${b.balance ~/ 100}.${(b.balance % 100).toString().padLeft(2, '0')}'];
      p.decisions.add(NeedsDecision(c.name, open, sum - c.outstandingPaise));
    }
  }

  void _closeLedgers() {
    _clearShortfalls();
    final byParty = <String, List<PEntry>>{};
    for (final e in p.entries) {
      byParty.putIfAbsent(e.partyId, () => []).add(e);
    }
    void close(PParty party, String kind, Map<String, int> sink) {
      final es = byParty[party.id] ?? const <PEntry>[];
      final sum = es.fold(0, (a, e) => a + e.amountPaise);
      final opening = party.outstandingPaise - sum;
      if (opening == 0) return;
      var at = es.isEmpty ? (party.createdMs > 0 ? party.createdMs : (p.backupMs > 0 ? p.backupMs : 946684800000)) : es.map((e) => e.atMs).reduce((a, b) => a < b ? a : b) - 1000;
      if (at <= 0) at = 946684800000;
      p.entries.add(PEntry('e1-led-open-${party.id}', kind, party.id, 'opening', opening, at, note: 'Balance carried from ERP 1'));
      sink[party.oldId] = opening;
    }

    for (final c in p.customers.values) {
      close(c, 'customer', p.openingCustomer);
    }
    for (final d in p.dealers.values) {
      close(d, 'dealer', p.openingDealer);
    }
  }

  void _closeStock() {
    final sums = <String, int>{};
    final firstAt = <String, int>{};
    for (final m in p.moves) {
      sums[m.productId] = (sums[m.productId] ?? 0) + m.qtyMilli;
      final f = firstAt[m.productId];
      if (f == null || m.atMs < f) firstAt[m.productId] = m.atMs;
    }
    for (final pr in p.products.values) {
      if (pr.placeholder) {
        // a placeholder has no stock figure in ERP 1; the sales we know about leave it at that number
        pr.stockMilli = 0;
      }
      final open = pr.stockMilli - (sums[pr.id] ?? 0);
      if (open != 0) {
        p.openingStock[pr.oldId] = open;
        final at = firstAt[pr.id] ?? (pr.createdMs > 0 ? pr.createdMs : (p.backupMs > 0 ? p.backupMs : 946684800000));
        p.moves.add(PMove('e1-mov-open-${pr.oldId}', pr.id, open, 'opening', null, at - 1000, 0, 'Stock carried from ERP 1'));
      }
    }
  }

  void _countSkippedKeys() {
    for (final e in p.unmappedKeys.entries) {
      log.add('not imported', e.key, IssueKind.note, 'no place for this list in ERP 2.0 yet (${e.value} record(s), listed only)');
    }
  }
}
