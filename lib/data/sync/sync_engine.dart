import '../context.dart';
import '../repo/rebuild.dart';
import 'sync_api.dart';
import 'sync_triggers.dart';

/// What one round of the sync did.
class SyncResult {
  const SyncResult({this.pushed = 0, this.pulled = 0, this.applied = 0, this.skipped = 0});
  final int pushed, pulled, applied, skipped;
}

/// Sends what changed on this computer to the cloud copy and brings in what the other computers changed (docs/supabase-sync-design.md).
///
///  * Changes are captured by database triggers into the `outbox` (one row per document, the newest edit replaces an older waiting one).
///  * [push] sends them in batches of at most 100. A batch the cloud refuses is split until the one document it dislikes is alone; that
///    document is marked "needs attention" and the others go through. No internet = nothing is lost, the rows wait.
///  * [pull] reads everything after the saved position, applies it in one transaction per page and saves the new position in the same
///    transaction. Rows that never change once written are kept as they are; edited rows follow "last writer wins" by their version stamp.
///    A document this computer has changed and not yet sent is left alone (the local change is sent next and, being newer, wins).
///  * After new documents arrive the totals (stock, balances, day totals) are rebuilt from the raw rows, because only raw rows travel.
class SyncEngine {
  SyncEngine(this.cx, this.api, {this.chan = 'cloud', this.batch = 100, this.pullLimit = 300, this.onChanged});
  final DataContext cx;

  /// Which upload queue this engine sends: 'cloud', or 'lan-' plus the other computer's id for one other counter on the shop Wi-Fi.
  final String chan;
  final SyncApi api;
  final int batch, pullLimit;

  /// Called after documents from the cloud were applied (the screens read the database again).
  final void Function()? onChanged;

  final Map<String, List<String>> _columns = {};

  /// One full round: push, then pull. Throws [SyncOffline] or [SyncAuthFailed]; documents refused for good do not stop the round.
  Future<SyncResult> run() async {
    await backfillOnce();
    final pushed = await push();
    if (!api.canPull) return SyncResult(pushed: pushed);
    final pulled = await pull();
    return SyncResult(pushed: pushed, pulled: pulled.$1, applied: pulled.$2, skipped: pulled.$3);
  }

  /// The first time: every document already in the database is queued, so the cloud copy gets what the shop had before sync was on.
  Future<void> backfillOnce() async {
    final doneKey = chan == 'cloud' ? 'backfilled' : 'backfilled:$chan';
    final done = await cx.db.row('SELECT value FROM sync_meta WHERE name = ?', [doneKey]);
    if (done != null) return;
    final now = cx.nowMs();
    await cx.db.transaction(() async {
      for (final t in syncTables) {
        await cx.db.exec("INSERT INTO outbox(coll, doc_id, op, stamp, state, attempts, hold_until, created_at, chan) SELECT '${t.name}', id, 'set', '', 'pending', 0, 0, ?, ? FROM ${t.name} WHERE true ON CONFLICT(chan, coll, doc_id) DO NOTHING", [now, chan]);
      }
      final names = sharedSettingNames.map((n) => "'$n'").join(',');
      await cx.db.exec("INSERT INTO outbox(coll, doc_id, op, stamp, state, attempts, hold_until, created_at, chan) SELECT '$settingsColl', name, 'set', '', 'pending', 0, 0, ?, ? FROM kv WHERE name IN ($names) AND true ON CONFLICT(chan, coll, doc_id) DO NOTHING", [now, chan]);
      await cx.db.exec("INSERT INTO sync_meta(name, value) VALUES (?, '1') ON CONFLICT(name) DO UPDATE SET value = excluded.value", [doneKey]);
    });
  }

  // ---------------------------------------------------------------------------------------------------------------- push

  Future<int> push() async {
    var sent = 0;
    while (true) {
      final due = await cx.db.rows("SELECT seq, coll, doc_id, stamp FROM outbox WHERE chan = ? AND state = 'pending' AND hold_until <= ? ORDER BY seq LIMIT ?", [chan, cx.nowMs(), batch]);
      if (due.isEmpty) return sent;
      final entries = <_Entry>[];
      for (final r in due) {
        final seq = r.read<int>('seq');
        var stamp = r.read<String>('stamp');
        if (stamp.isEmpty) {
          stamp = cx.hlc.next();
          await cx.db.exec("UPDATE outbox SET stamp = ? WHERE seq = ? AND stamp = ''", [stamp, seq]);
        }
        final coll = r.read<String>('coll');
        final id = r.read<String>('doc_id');
        final doc = await _read(coll, id, stamp);
        if (doc == null) {
          await cx.db.exec('DELETE FROM outbox WHERE seq = ? AND stamp = ?', [seq, stamp]); // the row is gone (an undone payment): nothing to send
          continue;
        }
        entries.add(_Entry(seq, stamp, doc));
      }
      if (entries.isEmpty) continue;
      sent += await _send(entries);
    }
  }

  Future<int> _send(List<_Entry> entries) async {
    try {
      await api.push([for (final e in entries) e.doc]);
    } on SyncRejected catch (e) {
      if (entries.length > 1) {
        final mid = entries.length ~/ 2;
        return await _send(entries.sublist(0, mid)) + await _send(entries.sublist(mid));
      }
      await cx.db.exec("UPDATE outbox SET state = 'attention', attempts = attempts + 1, last_error = ? WHERE seq = ? AND stamp = ?", [e.message, entries.first.seq, entries.first.stamp]);
      return 0;
    }
    await cx.db.transaction(() async {
      for (final e in entries) {
        await cx.db.exec('DELETE FROM outbox WHERE seq = ? AND stamp = ?', [e.seq, e.stamp]); // edited again meanwhile = stamp changed = stays queued
        if (syncTable(e.doc.coll)?.hasHlc != true) {
          await cx.db.exec('INSERT INTO sync_rev(coll, doc_id, hlc) VALUES (?,?,?) ON CONFLICT(coll, doc_id) DO UPDATE SET hlc = excluded.hlc', [e.doc.coll, e.doc.id, e.doc.hlc]);
        }
      }
    });
    return entries.length;
  }

  /// The document for a queued row, or null when the row no longer exists.
  Future<SyncDoc?> _read(String coll, String id, String stamp) async {
    if (coll == settingsColl) {
      final r = await cx.db.row('SELECT name, value, updated_at FROM kv WHERE name = ?', [id]);
      if (r == null) return null;
      return SyncDoc(coll: coll, id: id, data: Map<String, Object?>.from(r.data), hlc: stamp);
    }
    final t = syncTable(coll);
    if (t == null) return null;
    final r = await cx.db.row('SELECT * FROM ${t.name} WHERE id = ?', [id]);
    if (r == null) return null;
    final data = Map<String, Object?>.from(r.data);
    final own = t.hasHlc ? '${data['hlc'] ?? ''}' : '';
    return SyncDoc(coll: coll, id: id, data: data, hlc: own.isNotEmpty ? own : stamp);
  }

  // ---------------------------------------------------------------------------------------------------------------- pull

  /// Returns (documents read, documents applied, documents that could not be applied).
  Future<(int, int, int)> pull() async {
    var read = 0, applied = 0, skipped = 0;
    while (true) {
      final after = int.tryParse((await cx.db.row("SELECT value FROM sync_meta WHERE name = 'pull_cursor'"))?.read<String>('value') ?? '') ?? 0;
      final docs = await api.pull(after, pullLimit);
      if (docs.isEmpty) break;
      read += docs.length;
      final page = await _applyPage(docs);
      applied += page.$1;
      skipped += page.$2;
      if (docs.length < pullLimit) break;
    }
    if (applied > 0) {
      await rebuildSummaries(cx.db);
      onChanged?.call();
    }
    return (read, applied, skipped);
  }

  /// Documents sent to this computer by another counter over the shop Wi-Fi: applied exactly like pulled ones (no position to save).
  /// Returns how many were applied.
  Future<int> applyIncoming(List<PulledDoc> docs) async {
    if (docs.isEmpty) return 0;
    final r = await _applyPage(docs, saveCursor: false);
    if (r.$1 > 0) {
      await rebuildSummaries(cx.db);
      onChanged?.call();
    }
    return r.$1;
  }

  Future<(int, int)> _applyPage(List<PulledDoc> docs, {bool saveCursor = true}) async {
    var applied = 0, skipped = 0;
    await cx.db.transaction(() async {
      await cx.db.exec("INSERT INTO sync_meta(name, value) VALUES ('$applyingFlag', '1') ON CONFLICT(name) DO UPDATE SET value = '1'");
      // foreign keys are checked at the end of the page, so a line may arrive before its bill
      await cx.db.exec('PRAGMA defer_foreign_keys = ON');
      for (final d in docs) {
        cx.hlc.receive(d.hlc);
        try {
          if (await _apply(d)) applied++;
        } catch (e) {
          skipped++;
          await cx.db.exec("INSERT INTO sync_meta(name, value) VALUES ('last_apply_error', ?) ON CONFLICT(name) DO UPDATE SET value = excluded.value", ['${d.coll}/${d.id}: $e']);
        }
      }
      await cx.db.exec("DELETE FROM sync_meta WHERE name = '$applyingFlag'");
      if (saveCursor) await cx.db.exec("INSERT INTO sync_meta(name, value) VALUES ('pull_cursor', ?) ON CONFLICT(name) DO UPDATE SET value = excluded.value", ['${docs.last.seq}']);
    });
    return (applied, skipped);
  }

  Future<bool> _apply(PulledDoc d) async {
    final waiting = await cx.db.row("SELECT 1 AS x FROM outbox WHERE coll = ? AND doc_id = ? AND state IN ('pending','attention')", [d.coll, d.id]);
    if (waiting != null) return false; // this computer has an unsent change of its own: it is sent next and wins by its newer stamp
    if (d.coll == settingsColl) return _applySetting(d);
    final t = syncTable(d.coll);
    if (t == null) return false; // a collection a newer program version added: ignored, not an error
    if (t.appendOnly) return _upsert(t, d, replace: false);
    if (!t.hasHlc) {
      final rev = await cx.db.row('SELECT hlc FROM sync_rev WHERE coll = ? AND doc_id = ?', [d.coll, d.id]);
      if (rev != null && rev.read<String>('hlc').compareTo(d.hlc) >= 0) return false;
      final ok = await _upsert(t, d, replace: true);
      if (ok) await cx.db.exec('INSERT INTO sync_rev(coll, doc_id, hlc) VALUES (?,?,?) ON CONFLICT(coll, doc_id) DO UPDATE SET hlc = excluded.hlc', [d.coll, d.id, d.hlc]);
      return ok;
    }
    return _upsert(t, d, replace: true, byHlc: true);
  }

  Future<bool> _applySetting(PulledDoc d) async {
    final rev = await cx.db.row('SELECT hlc FROM sync_rev WHERE coll = ? AND doc_id = ?', [d.coll, d.id]);
    if (rev != null && rev.read<String>('hlc').compareTo(d.hlc) >= 0) return false;
    if (!sharedSettingNames.contains(d.id)) return false;
    await cx.db.exec('INSERT INTO kv(name, value, updated_at) VALUES (?,?,?) ON CONFLICT(name) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at',
        [d.id, '${d.data['value'] ?? ''}', (d.data['updated_at'] as num?)?.toInt() ?? cx.nowMs()]);
    await cx.db.exec('INSERT INTO sync_rev(coll, doc_id, hlc) VALUES (?,?,?) ON CONFLICT(coll, doc_id) DO UPDATE SET hlc = excluded.hlc', [d.coll, d.id, d.hlc]);
    return true;
  }

  Future<List<String>> _tableColumns(String table) async {
    return _columns[table] ??= [for (final r in await cx.db.rows('PRAGMA table_info($table)')) r.read<String>('name')];
  }

  Future<bool> _upsert(SyncTable t, PulledDoc d, {required bool replace, bool byHlc = false}) async {
    final have = await _tableColumns(t.name);
    final data = Map<String, Object?>.from(d.data)..['id'] = d.id;
    final cols = [for (final c in have) if (data.containsKey(c)) c];
    final marks = List.filled(cols.length, '?').join(',');
    final sets = [for (final c in cols) if (c != 'id') '$c = excluded.$c'].join(', ');
    final conflict = !replace
        ? 'ON CONFLICT(id) DO NOTHING'
        : 'ON CONFLICT(id) DO UPDATE SET $sets${byHlc ? ' WHERE excluded.hlc > ${t.name}.hlc' : ''}';
    Future<int> go(Map<String, Object?> row) async {
      await cx.db.exec('INSERT INTO ${t.name}(${cols.join(',')}) VALUES ($marks) $conflict', [for (final c in cols) row[c]]);
      return cx.db.scalarInt('SELECT changes()');
    }

    try {
      return await go(data) > 0;
    } catch (e) {
      // Two computers gave the next bill the same number (both were offline): this one keeps its own, the arriving one gets a short
      // suffix, so both stay on record and neither is lost.
      if ('$e'.contains('UNIQUE') && data['number'] is String && cols.contains('number')) {
        final tag = d.deviceId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
        final copy = Map<String, Object?>.from(data)..['number'] = '${data['number']}-${tag.length > 4 ? tag.substring(0, 4).toUpperCase() : tag.toUpperCase()}';
        return await go(copy) > 0;
      }
      rethrow;
    }
  }
}

class _Entry {
  _Entry(this.seq, this.stamp, this.doc);
  final int seq;
  final String stamp;
  final SyncDoc doc;
}
