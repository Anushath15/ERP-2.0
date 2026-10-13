/// Spike S4: outbox + pull sync engine prototype (throw-away; informs docs/sync-design.md).
library;

import 'dart:convert';
import 'dart:math';
import 'package:sqlite3/sqlite3.dart';
import 'rest.dart';

const appendOnly = {'bills', 'payments', 'stockMovements', 'ledgerEntries', 'audit'};

class SimulatedKill implements Exception {}

/// Transport. Real one = Firestore REST; tests wrap it with chaos.
abstract class Remote {
  Future<DateTime> commit(List<({String coll, String id, Map<String, Object?> data})> docs);
  Future<List<Map<String, Object?>>> pull(String coll, ({String ts, String id})? cursor, int limit);
}

class RestRemote implements Remote {
  RestRemote(this.fs, this.shop);
  final FirestoreRest fs;
  final String shop;
  @override
  Future<DateTime> commit(List<({String coll, String id, Map<String, Object?> data})> docs) =>
      fs.commit([for (final d in docs) (path: 'shops/$shop/${d.coll}/${d.id}', data: d.data)]);
  @override
  Future<List<Map<String, Object?>>> pull(
          String coll, ({String ts, String id})? cursor, int limit) =>
      fs.pullAfter('shops/$shop', coll, cursor, limit: limit);
}

/// Hybrid logical clock (physical ms + counter + device) - orders edits without trusting the clock alone.
class Hlc {
  Hlc(this.device);
  final String device;
  int _ms = 0;
  int _ctr = 0;
  int Function() clock = () => DateTime.now().millisecondsSinceEpoch;

  String next() {
    final now = clock();
    if (now > _ms) {
      _ms = now;
      _ctr = 0;
    } else {
      _ctr++;
    }
    return _fmt();
  }

  /// Merge a remote stamp so our next stamp is always later than anything we have seen.
  void observe(String stamp) {
    final p = stamp.split('-');
    final ms = int.parse(p[0], radix: 16), c = int.parse(p[1], radix: 16);
    if (ms > _ms || (ms == _ms && c > _ctr)) {
      _ms = ms;
      _ctr = c;
    }
  }

  String _fmt() =>
      '${_ms.toRadixString(16).padLeft(12, '0')}-${_ctr.toRadixString(16).padLeft(4, '0')}-$device';
}

class PushStats {
  int committed = 0, networkFailures = 0, poisoned = 0, batches = 0;
  Duration? backoff;
  String? lastError;
}

class Engine {
  Engine(String path, this.deviceId, {this.pageSize = 300, this.batchSize = 500})
      : db = sqlite3.open(path),
        hlc = Hlc(deviceId) {
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA synchronous=FULL');
    db.execute('''
      CREATE TABLE IF NOT EXISTS records(
        coll TEXT NOT NULL, id TEXT NOT NULL, json TEXT NOT NULL,
        stamp TEXT NOT NULL, PRIMARY KEY(coll,id));
      CREATE TABLE IF NOT EXISTS outbox(
        coll TEXT NOT NULL, id TEXT NOT NULL, stamp TEXT NOT NULL,
        state TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT, seq INTEGER PRIMARY KEY AUTOINCREMENT,
        UNIQUE(coll,id));
      CREATE TABLE IF NOT EXISTS history(
        coll TEXT, id TEXT, json TEXT, stamp TEXT, lost_to TEXT);
      CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT);
    ''');
  }

  final Database db;
  final String deviceId;
  final Hlc hlc;
  final int pageSize;
  final int batchSize;
  final _rnd = Random(7);
  void Function()? killAfterRemoteCommit; // test hook
  bool clockSkewWarning = false;

  void close() => db.dispose();

  // ---- local write: record + outbox in ONE transaction; repeated edits coalesce ----
  void save(String coll, String id, Map<String, Object?> data) {
    final stamp = hlc.next();
    final body = {
      ...data,
      'id': id,
      'deviceId': deviceId,
      'updatedAt': int.parse(stamp.split('-')[0], radix: 16),
      'hlc': stamp,
    };
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute('INSERT OR REPLACE INTO records(coll,id,json,stamp) VALUES(?,?,?,?)',
          [coll, id, jsonEncode(body), stamp]);
      db.execute('''INSERT INTO outbox(coll,id,stamp,state) VALUES(?,?,?,'pending')
                    ON CONFLICT(coll,id) DO UPDATE SET stamp=excluded.stamp, state='pending', attempts=0''',
          [coll, id, stamp]);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  int get pendingCount =>
      db.select("SELECT COUNT(*) c FROM outbox WHERE state='pending'").first['c'] as int;
  int get attentionCount =>
      db.select("SELECT COUNT(*) c FROM outbox WHERE state='attention'").first['c'] as int;
  int get recordCount => db.select('SELECT COUNT(*) c FROM records').first['c'] as int;

  Duration _backoff(int attempt) {
    final cap = min(300000, 1000 * pow(2, min(attempt, 9)).toInt());
    return Duration(milliseconds: _rnd.nextInt(cap) + cap ~/ 2); // jitter
  }

  // ---- push ----
  Future<PushStats> pushAll(Remote r, {int maxBatches = 1000}) async {
    final st = PushStats();
    for (var i = 0; i < maxBatches; i++) {
      final rows = db.select(
          "SELECT o.coll,o.id,o.stamp,r.json FROM outbox o JOIN records r USING(coll,id) WHERE o.state='pending' ORDER BY o.seq LIMIT $batchSize");
      if (rows.isEmpty) return st;
      final batch = [
        for (final row in rows)
          (coll: row['coll'] as String, id: row['id'] as String, stamp: row['stamp'] as String, json: row['json'] as String)
      ];
      st.batches++;
      try {
        await _pushBatch(r, batch, st);
      } on FbException catch (e) {
        if (e.isNetwork || e.status >= 500 || e.status == 429 || e.code == 'UNAVAILABLE') {
          st.networkFailures++;
          st.lastError = e.toString();
          final a = db.select("SELECT MAX(attempts) a FROM outbox WHERE state='pending'").first['a'] as int? ?? 0;
          db.execute("UPDATE outbox SET attempts=attempts+1 WHERE state='pending'");
          st.backoff = _backoff(a);
          return st; // caller sleeps for st.backoff and retries later
        }
        rethrow;
      }
    }
    return st;
  }

  Future<void> _pushBatch(Remote r,
      List<({String coll, String id, String stamp, String json})> batch, PushStats st) async {
    try {
      final commitTime = await r.commit([
        for (final b in batch) (coll: b.coll, id: b.id, data: jsonDecode(b.json) as Map<String, Object?>)
      ]);
      if ((DateTime.fromMillisecondsSinceEpoch(hlc.clock()).difference(commitTime)).abs() > const Duration(minutes: 5)) {
        clockSkewWarning = true;
      }
      killAfterRemoteCommit?.call(); // simulate power cut before we mark rows as sent
      _ack(batch);
      st.committed += batch.length;
    } on FbException catch (e) {
      final transient = e.isNetwork || e.status >= 500 || e.status == 429 || e.code == 'UNAVAILABLE';
      // A server 5xx that repeats for the same multi-record batch is treated like a rejection:
      // splitting the batch finds the poisoned record (the emulator answers 500 for a rejected 500-batch).
      final repeated5xx = e.status >= 500 && batch.length > 1 && _attempts(batch) >= 2;
      if (transient && !repeated5xx) rethrow;
      // A permanent rejection of an atomic batch: bisect to isolate the poisoned record(s).
      if (batch.length == 1) {
        db.execute("UPDATE outbox SET state='attention', last_error=? WHERE coll=? AND id=?",
            [e.code, batch.first.coll, batch.first.id]);
        st.poisoned++;
        return;
      }
      final mid = batch.length ~/ 2;
      await _pushBatch(r, batch.sublist(0, mid), st);
      await _pushBatch(r, batch.sublist(mid), st);
    }
  }

  int _attempts(List<({String coll, String id, String stamp, String json})> b) =>
      db.select('SELECT MAX(attempts) a FROM outbox WHERE coll=? AND id=?', [b.first.coll, b.first.id]).first['a'] as int? ?? 0;

  /// Remove from the outbox only rows whose stamp is unchanged (record not edited meanwhile).
  void _ack(List<({String coll, String id, String stamp, String json})> batch) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final stmt = db.prepare('DELETE FROM outbox WHERE coll=? AND id=? AND stamp=?');
      for (final b in batch) {
        stmt.execute([b.coll, b.id, b.stamp]);
      }
      stmt.dispose();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  // ---- pull ----
  ({String ts, String id})? _cursor(String coll) {
    final r = db.select('SELECT v FROM meta WHERE k=?', ['cursor:$coll']);
    if (r.isEmpty) return null;
    final p = (r.first['v'] as String).split('|');
    return (ts: p[0], id: p[1]);
  }

  Future<int> pull(Remote r, List<String> colls) async {
    var applied = 0;
    for (final coll in colls) {
      while (true) {
        final page = await r.pull(coll, _cursor(coll), pageSize);
        if (page.isEmpty) break;
        db.execute('BEGIN IMMEDIATE');
        try {
          for (final d in page) {
            applied += _apply(coll, d) ? 1 : 0;
          }
          final last = page.last;
          db.execute('INSERT OR REPLACE INTO meta(k,v) VALUES(?,?)',
              ['cursor:$coll', '${last['serverAt']}|${last['id']}']);
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
        if (page.length < pageSize) break;
      }
    }
    return applied;
  }

  bool _apply(String coll, Map<String, Object?> d) {
    final id = d['id'] as String;
    final stamp = (d['hlc'] ?? '') as String;
    if (stamp.isNotEmpty) hlc.observe(stamp);
    final mine = db.select('SELECT json,stamp FROM records WHERE coll=? AND id=?', [coll, id]);
    final body = {...d}..remove('serverAt');
    if (mine.isEmpty) {
      db.execute('INSERT INTO records(coll,id,json,stamp) VALUES(?,?,?,?)', [coll, id, jsonEncode(body), stamp]);
      return true;
    }
    if (appendOnly.contains(coll)) return false; // immutable: nothing to merge
    final myStamp = mine.first['stamp'] as String;
    if (stamp.compareTo(myStamp) > 0) {
      // remote wins; keep our version in history so nothing is silently lost
      db.execute('INSERT INTO history(coll,id,json,stamp,lost_to) VALUES(?,?,?,?,?)',
          [coll, id, mine.first['json'], myStamp, stamp]);
      db.execute('UPDATE records SET json=?, stamp=? WHERE coll=? AND id=?', [jsonEncode(body), stamp, coll, id]);
      db.execute("DELETE FROM outbox WHERE coll=? AND id=? AND stamp<?", [coll, id, stamp]);
      return true;
    } else if (stamp.compareTo(myStamp) < 0) {
      db.execute('INSERT INTO history(coll,id,json,stamp,lost_to) VALUES(?,?,?,?,?)',
          [coll, id, jsonEncode(body), stamp, myStamp]);
    }
    return false;
  }

  Map<String, String> snapshot(String coll) => {
        for (final r in db.select('SELECT id,json FROM records WHERE coll=?', [coll]))
          r['id'] as String: _canon(r['json'] as String)
      };

  String _canon(String json) {
    final m = (jsonDecode(json) as Map<String, dynamic>)..remove('serverAt');
    final keys = m.keys.toList()..sort();
    return jsonEncode({for (final k in keys) k: m[k]});
  }
}
