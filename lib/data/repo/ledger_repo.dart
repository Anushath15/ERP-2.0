import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/credit/account.dart';
import '../../domain/credit/dues.dart';
import '../../domain/credit/ledger.dart';
import '../../domain/credit/payment_split.dart';
import '../context.dart';
import '../db/app_database.dart';
import '../ids.dart';

/// Customer and dealer accounts in the database: the same rules as the screens (lib/domain/credit), now stored.
/// Every operation is ONE transaction: the ledger entries, the bill-wise dues, the running balance, the balance summary,
/// the payment record and the upload queue rows are written together or not at all.
class LedgerRepo {
  LedgerRepo(this.cx);
  final DataContext cx;

  AppDatabase get _db => cx.db;

  // ---------------------------------------------------------------- reading

  static DateTime _t(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

  static LedgerEntry _entry(QueryRow r) {
    final alloc = (jsonDecode(r.read<String>('allocations')) as List).map((a) => Allocation((a as Map)['b'] as String, a['p'] as int)).toList();
    return LedgerEntry(
      id: r.read<String>('id'),
      customerId: r.read<String>('party_id'),
      kind: LedgerKind.values.firstWhere((k) => k.name == r.read<String>('kind')),
      amountPaise: r.read<int>('amount_paise'),
      at: _t(r.read<int>('at')),
      billNo: r.readNullable<String>('bill_no'),
      note: r.read<String>('note'),
      by: r.read<String>('by_name'),
      mode: r.readNullable<String>('mode'),
      reverses: r.readNullable<String>('reverses'),
      allocations: alloc,
    );
  }

  static BillDue _due(QueryRow r) => BillDue(billNo: r.read<String>('bill_no'), date: _t(r.read<int>('date')), totalPaise: r.read<int>('total_paise'), paidPaise: r.read<int>('paid_paise'), cancelled: r.read<int>('cancelled') == 1);

  Future<List<LedgerEntry>> entries(String partyId, {DatabaseConnectionUser? tx}) async {
    final r = await (tx ?? _db).rows('SELECT * FROM ledger_entries WHERE party_id = ? ORDER BY at, rowid', [partyId]);
    return [for (final x in r) _entry(x)];
  }

  Future<List<BillDue>> dues(String partyId, {DatabaseConnectionUser? tx, bool openOnly = false}) async {
    final r = await (tx ?? _db).rows('SELECT * FROM party_bills WHERE party_id = ? ${openOnly ? 'AND cancelled = 0 AND total_paise > paid_paise' : ''} ORDER BY date, bill_no', [partyId]);
    return [for (final x in r) _due(x)];
  }

  Future<CreditAccount> account(String partyId, {DatabaseConnectionUser? tx}) async => CreditAccount(ledger: await entries(partyId, tx: tx), bills: await dues(partyId, tx: tx));

  /// The accounts the screens need at start-up: everybody who owes or is owed something, and anybody with an entry in the last
  /// [recentDays]. Other accounts are loaded when somebody opens them (an account of a long-quiet customer with thousands of old bills
  /// costs nothing until it is looked at).
  Future<Map<String, CreditAccount>> loadActiveAccounts(PartyKind kind, {int recentDays = 400}) async {
    final since = cx.now().subtract(Duration(days: recentDays)).millisecondsSinceEpoch;
    const ids = 'SELECT party_id FROM party_balance WHERE party_kind = ? AND (balance_paise <> 0 OR party_id IN (SELECT party_id FROM ledger_entries WHERE party_kind = ? AND at >= ?))';
    final es = await _db.rows('SELECT * FROM ledger_entries WHERE party_id IN ($ids) ORDER BY at, rowid', [kind.name, kind.name, since]);
    final bs = await _db.rows('SELECT * FROM party_bills WHERE party_id IN ($ids) ORDER BY date, bill_no', [kind.name, kind.name, since]);
    final ledger = <String, List<LedgerEntry>>{};
    final bills = <String, List<BillDue>>{};
    for (final r in es) {
      ledger.putIfAbsent(r.read<String>('party_id'), () => []).add(_entry(r));
    }
    for (final r in bs) {
      bills.putIfAbsent(r.read<String>('party_id'), () => []).add(_due(r));
    }
    return {for (final id in {...ledger.keys, ...bills.keys}) id: CreditAccount(ledger: ledger[id] ?? const [], bills: bills[id] ?? const [])};
  }

  Future<int> balanceOf(String partyId, {DatabaseConnectionUser? tx}) => (tx ?? _db).scalarInt('SELECT balance_paise FROM party_balance WHERE party_id = ?', [partyId]);

  /// Balance and open dues only (what a payment needs): cheap even for a customer with thousands of old bills.
  Future<({int balance, List<BillDue> open})> _openAccount(DatabaseConnectionUser tx, String partyId) async => (balance: await balanceOf(partyId, tx: tx), open: await dues(partyId, tx: tx, openOnly: true));

  // ---------------------------------------------------------------- writing blocks (call inside a transaction)

  static String _allocJson(List<Allocation> a) => jsonEncode([for (final x in a) {'b': x.billNo, 'p': x.paise}]);

  /// Adds one ledger entry: the running balance, the later entries' running balances (a back-dated entry), and the balance summary.
  Future<void> addEntry(DatabaseConnectionUser tx, PartyKind kind, LedgerEntry e, {String? refId, bool upload = false}) async {
    final at = e.at.millisecondsSinceEpoch;
    await tx.exec(
      'INSERT INTO ledger_entries(id, party_kind, party_id, kind, amount_paise, at, bill_no, note, by_name, mode, reverses, allocations, running_paise, ref_id, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,0,?,?,?)',
      [e.id, kind.name, e.customerId, e.kind.name, e.amountPaise, at, e.billNo, e.note, e.by, e.mode, e.reverses, _allocJson(e.allocations), refId, cx.nowMs(), cx.deviceId],
    );
    final rowid = await tx.lastRowId();
    final before = await tx.scalarInt('SELECT COALESCE(SUM(amount_paise), 0) FROM ledger_entries WHERE party_id = ? AND (at < ? OR (at = ? AND rowid <= ?))', [e.customerId, at, at, rowid]);
    await tx.exec('UPDATE ledger_entries SET running_paise = ? WHERE rowid = ?', [before, rowid]);
    await tx.exec('UPDATE ledger_entries SET running_paise = running_paise + ? WHERE party_id = ? AND (at > ? OR (at = ? AND rowid > ?))', [e.amountPaise, e.customerId, at, at, rowid]);
    final paid = e.kind == LedgerKind.payment || e.kind == LedgerKind.advance;
    await tx.exec(
      'INSERT INTO party_balance(party_id, party_kind, balance_paise, last_payment_at, entry_count) VALUES (?,?,?,?,1) '
      'ON CONFLICT(party_id) DO UPDATE SET balance_paise = balance_paise + excluded.balance_paise, entry_count = entry_count + 1, '
      'last_payment_at = CASE WHEN ? = 1 THEN MAX(COALESCE(last_payment_at, 0), excluded.last_payment_at) ELSE last_payment_at END',
      [e.customerId, kind.name, e.amountPaise, paid ? at : null, paid ? 1 : 0],
    );
    if (upload) await enqueue(cx, tx, 'ledgerEntries', e.id);
  }

  /// Takes one entry back out (only the 8-second undo of an unsent payment).
  Future<void> _removeEntry(DatabaseConnectionUser tx, String id) async {
    final r = await tx.row('SELECT party_id, amount_paise, at, rowid FROM ledger_entries WHERE id = ?', [id]);
    if (r == null) return;
    final party = r.read<String>('party_id');
    final amt = r.read<int>('amount_paise');
    final at = r.read<int>('at');
    final rowid = r.read<int>('rowid');
    await tx.exec('DELETE FROM ledger_entries WHERE id = ?', [id]);
    await tx.exec('UPDATE ledger_entries SET running_paise = running_paise - ? WHERE party_id = ? AND (at > ? OR (at = ? AND rowid > ?))', [amt, party, at, at, rowid]);
    await tx.exec('UPDATE party_balance SET balance_paise = balance_paise - ?, entry_count = entry_count - 1 WHERE party_id = ?', [amt, party]);
    await tx.exec('DELETE FROM outbox WHERE coll = ? AND doc_id = ?', ['ledgerEntries', id]);
  }

  /// Adds or updates one bill-wise due.
  Future<void> putDue(DatabaseConnectionUser tx, PartyKind kind, String partyId, BillDue d) => tx.exec(
        'INSERT INTO party_bills(id, party_kind, party_id, bill_no, date, total_paise, paid_paise, cancelled) VALUES (?,?,?,?,?,?,?,?) '
        'ON CONFLICT(party_id, bill_no) DO UPDATE SET paid_paise = excluded.paid_paise, cancelled = excluded.cancelled, total_paise = excluded.total_paise',
        ['$partyId|${d.billNo}', kind.name, partyId, d.billNo, d.date.millisecondsSinceEpoch, d.totalPaise, d.paidPaise, d.cancelled ? 1 : 0],
      );

  /// Writes back the dues that changed between [before] and [after].
  Future<void> _saveDues(DatabaseConnectionUser tx, PartyKind kind, String partyId, List<BillDue> before, List<BillDue> after) async {
    final old = {for (final b in before) b.billNo: b};
    for (final b in after) {
      final o = old[b.billNo];
      if (o == null || o.paidPaise != b.paidPaise || o.cancelled != b.cancelled || o.totalPaise != b.totalPaise) await putDue(tx, kind, partyId, b);
    }
  }

  // ---------------------------------------------------------------- called by a bill or purchase being saved

  /// The unpaid part of a bill (or purchase) goes on the account; extra money handed over may be kept as an advance.
  /// Call inside the transaction that saves the bill.
  Future<void> addBillCredit(DatabaseConnectionUser tx, PartyKind kind, {required String partyId, required String billNo, required DateTime at, required int total, required int received, int advance = 0}) async {
    final split = splitPayment(total: total, received: received);
    if (split.balance > 0) {
      await addEntry(tx, kind, LedgerEntry.billCredit(id: newId(), customerId: partyId, paise: split.balance, at: at, billNo: billNo, by: cx.actor.name));
      await putDue(tx, kind, partyId, BillDue(billNo: billNo, date: at, totalPaise: total, paidPaise: total - split.balance));
    }
    if (advance > 0) {
      await addEntry(tx, kind, LedgerEntry.advance(id: newId(), customerId: partyId, paise: advance, at: at, billNo: billNo, by: cx.actor.name, note: 'Extra money kept as advance'));
    }
    await tx.exec('UPDATE party_balance SET last_bill_at = ? WHERE party_id = ?', [at.millisecondsSinceEpoch, partyId]);
  }

  /// A bill was cancelled: its credit is reversed. Does nothing for a bill that added no credit. Returns whether an entry was made.
  Future<bool> cancelBillCredit(DatabaseConnectionUser tx, PartyKind kind, {required String partyId, required String billNo, required DateTime at, required String reason}) async {
    final ledger = await entries(partyId, tx: tx);
    if (!ledger.any((x) => x.billNo == billNo && x.kind == LedgerKind.billCredit)) return false;
    final all = await dues(partyId, tx: tx);
    if (all.any((b) => b.billNo == billNo && b.cancelled)) return false;
    final rev = reverseBillCredit(entries: ledger, customerId: partyId, billNo: billNo, at: at, reason: reason, by: cx.actor.name, entryId: newId());
    await addEntry(tx, kind, rev);
    await putDue(tx, kind, partyId, all.firstWhere((b) => b.billNo == billNo).cancel());
    return true;
  }

  // ---------------------------------------------------------------- operations the screens call

  String _receiptPrefix(PartyKind k) => k == PartyKind.customer ? 'RCP' : 'PAY';
  String _paidMoreNote(PartyKind k) => k == PartyKind.customer ? 'Paid more than was due' : 'Paid more than was due';

  /// A payment: applied to the oldest unpaid bills (or only [onlyBills]); any rest becomes an advance.
  Future<PaymentReceipt> receivePayment(PartyKind kind, {required String partyId, required String partyName, required int amount, required String mode, required DateTime at, String note = '', Set<String>? onlyBills}) {
    return _db.transaction(() async {
      final a = await _openAccount(_db, partyId);
      final res = allocatePayment(bills: a.open, amount: amount, onlyBills: onlyBills);
      final unbilled = a.balance - a.open.fold<int>(0, (s, b) => s + b.outstanding);
      final toUnbilled = onlyBills == null ? (unbilled > 0 ? (res.advancePaise < unbilled ? res.advancePaise : unbilled) : 0) : 0;
      final advance = res.advancePaise - toUnbilled;
      final payId = newId();
      final no = '${_receiptPrefix(kind)}-${(await nextCounter(_db, 'rcp.${kind.name}')).toString().padLeft(4, '0')}';
      await _db.exec(
        'INSERT INTO payments(id, party_kind, party_id, amount_paise, advance_paise, mode, at, note, receipt_no, allocations, by_name, created_at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [payId, kind.name, partyId, amount, advance, mode, at.millisecondsSinceEpoch, note, no, _allocJson(res.allocations), cx.actor.name, cx.nowMs(), cx.deviceId],
      );
      if (res.appliedPaise + toUnbilled > 0) {
        await addEntry(_db, kind, LedgerEntry.payment(id: newId(), customerId: partyId, paise: res.appliedPaise + toUnbilled, at: at, mode: mode, note: note, by: cx.actor.name, allocations: res.allocations), refId: payId);
      }
      if (advance > 0) {
        await addEntry(_db, kind, LedgerEntry.advance(id: newId(), customerId: partyId, paise: advance, at: at, mode: mode, note: note.isEmpty ? _paidMoreNote(kind) : note, by: cx.actor.name), refId: payId);
      }
      await _saveDues(_db, kind, partyId, a.open, applyAllocations(a.open, res.allocations));
      await enqueue(cx, _db, 'payments', payId, holdMs: 10000); // held back 10 s so the Undo can still take it away
      return PaymentReceipt(id: payId, number: no, customerId: partyId, customerName: partyName, amountPaise: amount, mode: mode, at: at, note: note, allocations: res.allocations, advancePaise: advance, balanceAfter: await balanceOf(partyId, tx: _db));
    });
  }

  /// "Settle fully": records the whole balance as received (or paid). Returns null when nothing is owed.
  Future<PaymentReceipt?> settleFully(PartyKind kind, {required String partyId, required String partyName, required String mode, required DateTime at, String note = ''}) async {
    final owed = await balanceOf(partyId);
    if (owed <= 0) return null;
    return receivePayment(kind, partyId: partyId, partyName: partyName, amount: owed, mode: mode, at: at, note: note.isEmpty ? 'Settled fully' : note);
  }

  /// Takes a just-made payment back (the 8-second Undo). Works only while nothing else was added to the account and the
  /// payment was not uploaded yet; then no trace is left (no update or delete of a synced document is ever needed).
  Future<bool> undoPayment(PartyKind kind, PaymentReceipt r) {
    return _db.transaction(() async {
      final p = await _db.row('SELECT allocations, party_id FROM payments WHERE id = ?', [r.id]);
      if (p == null) return false;
      final partyId = p.read<String>('party_id');
      final mine = await _db.rows('SELECT id, rowid FROM ledger_entries WHERE ref_id = ?', [r.id]);
      final maxRow = mine.isEmpty ? 0 : mine.map((x) => x.read<int>('rowid')).reduce((a, b) => a > b ? a : b);
      if (maxRow > 0 && await _db.scalarInt('SELECT COUNT(*) FROM ledger_entries WHERE party_id = ? AND rowid > ?', [partyId, maxRow]) > 0) return false;
      final queued = await _db.row("SELECT state FROM outbox WHERE coll = 'payments' AND doc_id = ?", [r.id]);
      if (queued == null || queued.read<String>('state') != 'pending') return false; // already uploaded (or on its way): never taken back
      final before = await dues(partyId, tx: _db);
      final alloc = (jsonDecode(p.read<String>('allocations')) as List).map((a) => Allocation((a as Map)['b'] as String, a['p'] as int)).toList();
      for (final m in mine) {
        await _removeEntry(_db, m.read<String>('id'));
      }
      await _saveDues(_db, kind, partyId, before, restoreAllocations(before, alloc));
      await _db.exec('DELETE FROM payments WHERE id = ?', [r.id]);
      await _db.exec("DELETE FROM outbox WHERE coll = 'payments' AND doc_id = ?", [r.id]);
      await _db.exec('UPDATE counters SET value = value - 1 WHERE name = ? AND value = ?', ['rcp.${kind.name}', int.tryParse(r.number.split('-').last) ?? -1]);
      return true;
    });
  }

  /// Credit added by hand. It becomes a bill-like line so it ages and payments settle it oldest-first. Returns its number.
  Future<String> addManualCredit(PartyKind kind, {required String partyId, required int amount, required DateTime at, required String reason}) {
    return _db.transaction(() async {
      final no = 'CR-${(await nextCounter(_db, 'cr.${kind.name}')).toString().padLeft(3, '0')}';
      final e = LedgerEntry.manualCredit(id: newId(), customerId: partyId, paise: amount, at: at, reason: reason, by: cx.actor.name, billNo: no);
      await addEntry(_db, kind, e, upload: true);
      await putDue(_db, kind, partyId, BillDue(billNo: no, date: at, totalPaise: amount, paidPaise: 0));
      return no;
    });
  }

  /// A correction by hand, either way. Plus = they owe more (a bill-like line); minus = they owe less (taken off the oldest bills).
  Future<void> addAdjustment(PartyKind kind, {required String partyId, required int signedPaise, required DateTime at, required String reason}) {
    return _db.transaction(() async {
      if (signedPaise > 0) {
        final no = 'ADJ-${(await nextCounter(_db, 'adj.${kind.name}')).toString().padLeft(3, '0')}';
        await addEntry(_db, kind, LedgerEntry.adjustment(id: newId(), customerId: partyId, signedPaise: signedPaise, at: at, reason: reason, by: cx.actor.name, billNo: no), upload: true);
        await putDue(_db, kind, partyId, BillDue(billNo: no, date: at, totalPaise: signedPaise, paidPaise: 0));
      } else {
        final open = await dues(partyId, tx: _db, openOnly: true);
        final res = allocatePayment(bills: open, amount: -signedPaise);
        await addEntry(_db, kind, LedgerEntry.adjustment(id: newId(), customerId: partyId, signedPaise: signedPaise, at: at, reason: reason, by: cx.actor.name, allocations: res.allocations), upload: true);
        await _saveDues(_db, kind, partyId, open, applyAllocations(open, res.allocations));
      }
    });
  }

  /// A starting balance for someone who already owed (or paid ahead) before this program. Positive = owes.
  Future<void> addOpening(PartyKind kind, {required String partyId, required int amount, required DateTime at}) {
    if (amount == 0) return Future.value();
    return _db.transaction(() async {
      await addEntry(_db, kind, LedgerEntry.opening(id: newId(), customerId: partyId, paise: amount, at: at, by: cx.actor.name), upload: true);
      if (amount > 0) await putDue(_db, kind, partyId, BillDue(billNo: 'OPEN-$partyId', date: at, totalPaise: amount, paidPaise: 0));
    });
  }

  /// Fixes a wrong entry with a NEW entry (the wrong one stays visible). Throws when it cannot be reversed or already was.
  Future<void> reverseEntry(PartyKind kind, {required String partyId, required String entryId, required String reason, required DateTime at}) {
    return _db.transaction(() async {
      final row = await _db.row('SELECT * FROM ledger_entries WHERE id = ? AND party_id = ?', [entryId, partyId]);
      if (row == null) throw StateError('no such entry');
      final orig = _entry(row);
      if (await _db.scalarInt('SELECT COUNT(*) FROM ledger_entries WHERE reverses = ?', [entryId]) > 0) throw StateError('already reversed');
      final rev = LedgerEntry.reversal(id: newId(), customerId: partyId, original: orig, at: at, reason: reason, by: cx.actor.name);
      var bills = await dues(partyId, tx: _db);
      final before = bills;
      switch (orig.kind) {
        case LedgerKind.payment || LedgerKind.writeOff:
          bills = restoreAllocations(bills, orig.allocations);
        case LedgerKind.manualCredit || LedgerKind.opening:
          bills = [for (final b in bills) b.billNo == (orig.billNo ?? 'OPEN-$partyId') ? b.cancel() : b];
        case LedgerKind.adjustment:
          bills = orig.amountPaise > 0 ? [for (final b in bills) b.billNo == orig.billNo ? b.cancel() : b] : restoreAllocations(bills, orig.allocations);
        default:
      }
      await addEntry(_db, kind, rev, upload: true);
      await _saveDues(_db, kind, partyId, before, bills);
    });
  }

  /// Owner only. Cannot write off more than is owed.
  Future<void> writeOff(PartyKind kind, {required String partyId, required int amount, required String reason, required DateTime at}) {
    return _db.transaction(() async {
      final bal = await balanceOf(partyId, tx: _db);
      if (amount > (bal > 0 ? bal : 0)) throw StateError('cannot write off more than is owed');
      final open = await dues(partyId, tx: _db, openOnly: true);
      final res = allocatePayment(bills: open, amount: amount);
      await addEntry(_db, kind, LedgerEntry.writeOff(id: newId(), customerId: partyId, paise: amount, at: at, reason: reason, by: cx.actor.name, allocations: res.allocations), upload: true);
      await _saveDues(_db, kind, partyId, open, applyAllocations(open, res.allocations));
      await _db.exec(
        'INSERT INTO audit(id, what, entity, entity_id, field, old_value, new_value, by_name, at, device_id) VALUES (?,?,?,?,?,?,?,?,?,?)',
        [newId(), 'writeOff', kind.name, partyId, 'balance', '$bal', '${bal - amount}', cx.actor.name, cx.nowMs(), cx.deviceId],
      );
    });
  }

  // ---------------------------------------------------------------- lists for the screens

  /// People with a balance (or all with [onlyOwing] false), biggest first. [search] matches the name or phone.
  Future<List<({String id, String name, String phone, String city, int balance, int? lastBillAt, int? lastPaymentAt})>> balances(PartyKind kind, {bool onlyOwing = true, String search = '', int limit = 500, int offset = 0}) async {
    final t = kind == PartyKind.customer ? 'customers' : 'dealers';
    final q = search.trim();
    final r = await _db.rows(
      'SELECT p.id, p.name, p.phone, p.city, COALESCE(b.balance_paise, 0) AS balance, b.last_bill_at, b.last_payment_at FROM $t p LEFT JOIN party_balance b ON b.party_id = p.id '
      'WHERE p.deleted_at IS NULL ${onlyOwing ? 'AND COALESCE(b.balance_paise, 0) <> 0' : ''} ${q.isEmpty ? '' : "AND (p.name LIKE ? ESCAPE '\\' OR p.phone LIKE ? ESCAPE '\\')"} '
      'ORDER BY ABS(COALESCE(b.balance_paise, 0)) DESC, p.name COLLATE NOCASE LIMIT ? OFFSET ?',
      [if (q.isNotEmpty) ...['%${_like(q)}%', '%${_like(q)}%'], limit, offset],
    );
    return [for (final x in r) (id: x.read<String>('id'), name: x.read<String>('name'), phone: x.read<String>('phone'), city: x.read<String>('city'), balance: x.read<int>('balance'), lastBillAt: x.readNullable<int>('last_bill_at'), lastPaymentAt: x.readNullable<int>('last_payment_at'))];
  }

  static String _like(String s) => s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}
