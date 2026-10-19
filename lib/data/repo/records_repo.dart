import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/credit/reminder.dart';
import '../../domain/models.dart';
import '../context.dart';
import '../db/app_database.dart';
import '../ids.dart';

/// The small kinds of record the prototype lists (purchases, returns, delivery, expenses, warranty, projects, staff, notifications):
/// one JSON record each, listed by kind, newest first. Dates inside a record are kept exactly (encoded with a marker).
class RecordsRepo {
  RecordsRepo(this.cx);
  final DataContext cx;
  AppDatabase get _db => cx.db;

  static String encode(Map<String, Object> f) => jsonEncode({for (final e in f.entries) e.key: e.value is DateTime ? {'_d': (e.value as DateTime).millisecondsSinceEpoch} : e.value});

  static Map<String, Object> decode(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return {for (final e in m.entries) e.key: e.value is Map && (e.value as Map).containsKey('_d') ? DateTime.fromMillisecondsSinceEpoch((e.value as Map)['_d'] as int) : e.value as Object};
  }

  /// Newest first. [limit] keeps a screen light on a shop with years of expenses (the screens show the newest 3,000).
  Future<List<Rec>> list(String kind, {int limit = 3000}) async {
    final r = await _db.rows('SELECT id, data FROM records WHERE kind = ? AND deleted_at IS NULL ORDER BY at DESC, id DESC LIMIT ?', [kind, limit]);
    return [for (final x in r) Rec(x.read<String>('id'), decode(x.read<String>('data')))];
  }

  Future<void> put(String kind, Rec r, {required bool create}) {
    return _db.transaction(() async {
      final now = cx.nowMs();
      final at = r.f['date'] is DateTime ? (r.f['date'] as DateTime).millisecondsSinceEpoch : (r.f['time'] is DateTime ? (r.f['time'] as DateTime).millisecondsSinceEpoch : now);
      if (create) {
        await _db.exec('INSERT INTO records(id, kind, data, at, created_at, updated_at, device_id, version, hlc) VALUES (?,?,?,?,?,?,?,1,?)', [r.id, kind, encode(r.f), at, now, now, cx.deviceId, cx.hlc.next()]);
      } else {
        await _db.exec('UPDATE records SET data = ?, at = ?, updated_at = ?, version = version + 1, hlc = ?, device_id = ? WHERE id = ?', [encode(r.f), at, now, cx.hlc.next(), cx.deviceId, r.id]);
      }
      await enqueue(cx, _db, 'records', r.id);
    });
  }

  /// Saves a new record and gives it the next number of its kind (`PUR-00241`): the count of all records of the kind so far plus one.
  /// Nothing is ever hard-deleted, so numbers are never reused. Returns the record as saved.
  Future<Rec> putNumbered(String kind, Rec r, {required String prefix, required int width}) {
    return _db.transaction(() async {
      final n = await nextCounter(_db, 'rec.$kind');
      final saved = r.with_({'no': '$prefix-${n.toString().padLeft(width, '0')}'});
      await put(kind, saved, create: true);
      return saved;
    });
  }

  Future<void> remove(String id) {
    return _db.transaction(() async {
      await _db.exec('UPDATE records SET deleted_at = ?, updated_at = ?, version = version + 1, hlc = ? WHERE id = ?', [cx.nowMs(), cx.nowMs(), cx.hlc.next(), id]);
      await enqueue(cx, _db, 'records', id);
    });
  }
}

/// Saved estimates: editable, own number series (`EST-00001`), lines kept so an estimate can be edited, copied and turned into a bill.
class EstimationRepo {
  EstimationRepo(this.cx);
  final DataContext cx;
  AppDatabase get _db => cx.db;

  String numberFor(int seq) => 'EST-${seq.toString().padLeft(5, '0')}';

  Future<String> peekNextNumber() async => numberFor(await _db.scalarInt("SELECT value FROM counters WHERE name = 'est'") + 1);

  static EstimationDoc _doc(QueryRow r) => EstimationDoc(
        number: r.read<String>('number'),
        date: DateTime.fromMillisecondsSinceEpoch(r.read<int>('at')),
        customer: r.read<String>('customer_name'),
        lines: r.read<int>('line_count'),
        totalPaise: r.read<int>('total_paise'),
        editedOn: r.readNullable<int>('edited_on') == null ? null : DateTime.fromMillisecondsSinceEpoch(r.read<int>('edited_on')),
        convertedTo: r.readNullable<String>('converted_bill_id'),
        extraDiscountPaise: r.read<int>('extra_discount_paise'),
        extraDiscountBp: r.read<int>('extra_discount_bp'),
      );

  Future<List<EstimationDoc>> list({int limit = 5000}) async => [for (final r in await _db.rows('SELECT * FROM estimations WHERE deleted_at IS NULL ORDER BY at DESC, id DESC LIMIT ?', [limit])) _doc(r)];

  /// Saves a new estimate (a new number) or, with [editNumber], saves changes in place (the number and its date stay).
  Future<EstimationDoc> save({required List<EstimateLine> lines, required int totalPaise, required String customerName, String? customerId, required DateTime at, String? editNumber, int extraDiscountPaise = 0, int extraDiscountBp = 0}) {
    return _db.transaction(() async {
      final now = cx.nowMs();
      String id;
      String number;
      if (editNumber != null) {
        final e = await _db.row('SELECT id, number FROM estimations WHERE number = ?', [editNumber]);
        if (e == null) throw StateError('No such estimate.');
        id = e.read<String>('id');
        number = editNumber;
        await _db.exec('UPDATE estimations SET customer_id = ?, customer_name = ?, total_paise = ?, line_count = ?, edited_on = ?, updated_at = ?, version = version + 1, hlc = ?, device_id = ?, extra_discount_paise = ?, extra_discount_bp = ? WHERE id = ?', [customerId, customerName, totalPaise, lines.length, at.millisecondsSinceEpoch, now, cx.hlc.next(), cx.deviceId, extraDiscountPaise, extraDiscountBp, id]);
        await _db.exec('DELETE FROM estimation_lines WHERE estimation_id = ?', [id]);
      } else {
        id = newId();
        number = numberFor(await nextCounter(_db, 'est'));
        await _db.exec(
          'INSERT INTO estimations(id, number, at, customer_id, customer_name, total_paise, line_count, created_at, updated_at, device_id, version, hlc, extra_discount_paise, extra_discount_bp) VALUES (?,?,?,?,?,?,?,?,?,?,1,?,?,?)',
          [id, number, at.millisecondsSinceEpoch, customerId, customerName, totalPaise, lines.length, now, now, cx.deviceId, cx.hlc.next(), extraDiscountPaise, extraDiscountBp],
        );
      }
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        await _db.exec('INSERT INTO estimation_lines(id, estimation_id, line_no, product_id, name, unit, qty_milli, rate_paise, discount_bp) VALUES (?,?,?,?,?,?,?,?,?)', [newId(), id, i + 1, l.productId, l.name, l.unit, l.qtyMilli, l.ratePaise, l.discountBp]);
      }
      await enqueue(cx, _db, 'estimations', id);
      return _doc((await _db.row('SELECT * FROM estimations WHERE id = ?', [id]))!);
    });
  }

  Future<List<EstimateLine>> lines(String number) async {
    final r = await _db.rows('SELECT l.* FROM estimation_lines l JOIN estimations e ON e.id = l.estimation_id WHERE e.number = ? ORDER BY l.line_no', [number]);
    return [for (final x in r) EstimateLine(productId: x.read<String>('product_id'), name: x.read<String>('name'), unit: x.read<String>('unit'), qtyMilli: x.read<int>('qty_milli'), ratePaise: x.read<int>('rate_paise'), discountBp: x.read<int>('discount_bp'))];
  }

  Future<String?> customerIdOf(String number) async => (await _db.row('SELECT customer_id FROM estimations WHERE number = ?', [number]))?.readNullable<String>('customer_id');

  /// Converting sets the bill number on the estimate. A second conversion is refused.
  Future<void> markConverted(String number, String billNumber) {
    return _db.transaction(() async {
      final e = await _db.row('SELECT id, converted_bill_id FROM estimations WHERE number = ?', [number]);
      if (e == null) throw StateError('No such estimate.');
      if (e.readNullable<String>('converted_bill_id') != null) throw StateError('This estimate was already converted.');
      await _db.exec('UPDATE estimations SET converted_bill_id = ?, updated_at = ?, version = version + 1, hlc = ? WHERE id = ?', [billNumber, cx.nowMs(), cx.hlc.next(), e.read<String>('id')]);
      await enqueue(cx, _db, 'estimations', e.read<String>('id'));
    });
  }

  Future<void> remove(String number, {required String reason}) {
    return _db.transaction(() async {
      final e = await _db.row('SELECT id FROM estimations WHERE number = ?', [number]);
      if (e == null) return;
      await _db.exec('UPDATE estimations SET deleted_at = ?, updated_at = ?, version = version + 1, hlc = ? WHERE id = ?', [cx.nowMs(), cx.nowMs(), cx.hlc.next(), e.read<String>('id')]);
      await _db.exec('INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)', [newId(), 'deleteEstimate', 'estimation', e.read<String>('id'), 'deleted', number, reason, cx.actor.name, cx.nowMs(), cx.deviceId]);
      await enqueue(cx, _db, 'estimations', e.read<String>('id'));
    });
  }
}

class EstimateLine {
  const EstimateLine({required this.productId, required this.name, required this.unit, required this.qtyMilli, required this.ratePaise, this.discountBp = 0});
  final String productId, name, unit;
  final int qtyMilli, ratePaise, discountBp;
}

/// "Reminders opened in WhatsApp": one small record each. Held back 10 s before it may upload so "Not sent? Undo" leaves no trace.
class ReminderRepo {
  ReminderRepo(this.cx);
  final DataContext cx;
  AppDatabase get _db => cx.db;

  Future<List<ReminderRecord>> recent({int days = 400}) async {
    final since = cx.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final r = await _db.rows('SELECT * FROM reminders WHERE at >= ? ORDER BY at', [since]);
    return [for (final x in r) ReminderRecord(id: x.read<String>('id'), customerId: x.read<String>('customer_id'), at: DateTime.fromMillisecondsSinceEpoch(x.read<int>('at')), amountDuePaise: x.read<int>('amount_due_paise'), message: x.read<String>('message'), by: x.read<String>('by_name'))];
  }

  Future<ReminderRecord> record({String? id, required String customerId, required int amountDue, required String message, required DateTime at}) {
    return _db.transaction(() async {
      id ??= newId();
      await _db.exec('INSERT INTO reminders(id, customer_id, at, amount_due_paise, message, by_name, created_at, device_id) VALUES (?,?,?,?,?,?,?,?)', [id, customerId, at.millisecondsSinceEpoch, amountDue, message, cx.actor.name, cx.nowMs(), cx.deviceId]);
      await enqueue(cx, _db, 'reminders', id!, holdMs: 10000);
      return ReminderRecord(id: id!, customerId: customerId, at: at, amountDuePaise: amountDue, message: message, by: cx.actor.name);
    });
  }

  /// Takes the record away (only while it is still waiting to upload).
  Future<bool> undo(String id) {
    return _db.transaction(() async {
      final q = await _db.row("SELECT state FROM outbox WHERE coll = 'reminders' AND doc_id = ?", [id]);
      if (q == null || q.read<String>('state') != 'pending') return false;
      await _db.exec('DELETE FROM reminders WHERE id = ?', [id]);
      await _db.exec("DELETE FROM outbox WHERE coll = 'reminders' AND doc_id = ?", [id]);
      return true;
    });
  }
}

/// Stock changes by hand (counted stock, damaged, lost, opening stock): a movement of kind adjustment, never an edit of the figure.
class StockRepo {
  StockRepo(this.cx);
  final DataContext cx;
  AppDatabase get _db => cx.db;

  Future<void> adjust({required String productId, required int qtyMilli, required String reason, required DateTime at, String kind = 'adjustment'}) {
    if (qtyMilli == 0) throw ArgumentError('A stock change cannot be zero.');
    if (reason.trim().isEmpty) throw ArgumentError('A stock change needs a reason.');
    return _db.transaction(() async {
      final id = newId();
      await _db.exec('INSERT INTO stock_movements(id, product_id, qty_milli, kind, note, at, created_at, device_id) VALUES (?,?,?,?,?,?,?,?)', [id, productId, qtyMilli, kind, reason.trim(), at.millisecondsSinceEpoch, cx.nowMs(), cx.deviceId]);
      await _db.exec('INSERT INTO stock_cache(product_id, qty_milli) VALUES (?,?) ON CONFLICT(product_id) DO UPDATE SET qty_milli = qty_milli + excluded.qty_milli', [productId, qtyMilli]);
      await enqueue(cx, _db, 'stockMovements', id);
    });
  }

  /// Newest first: `{date, product, qty, reason}` as the list screen shows them.
  Future<List<Rec>> adjustments({int limit = 3000}) async {
    final r = await _db.rows("SELECT m.id, m.at, m.qty_milli, m.note, p.name FROM stock_movements m JOIN products p ON p.id = m.product_id WHERE m.kind IN ('adjustment','opening') ORDER BY m.at DESC, m.id DESC LIMIT ?", [limit]);
    return [for (final x in r) Rec(x.read<String>('id'), {'date': DateTime.fromMillisecondsSinceEpoch(x.read<int>('at')), 'product': x.read<String>('name'), 'qty': x.read<int>('qty_milli'), 'reason': x.read<String>('note')})];
  }
}

/// Small shop-wide settings and the shop profile, as JSON text under a name.
class SettingsRepo {
  SettingsRepo(this.cx);
  final DataContext cx;
  AppDatabase get _db => cx.db;

  Future<String?> get(String name) async => (await _db.row('SELECT value FROM kv WHERE name = ?', [name]))?.read<String>('value');

  Future<void> put(String name, String value, {bool upload = false}) async {
    await _db.exec('INSERT INTO kv(name, value, updated_at) VALUES (?,?,?) ON CONFLICT(name) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at', [name, value, cx.nowMs()]);
    if (upload) await enqueue(cx, _db, 'settingsShared', name);
  }
}
