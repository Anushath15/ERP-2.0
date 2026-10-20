/// Switching the shop data file, safely. The program is NOT running on the live file while this happens: a request is written, the program
/// restarts its data, and [applyPendingSwap] does the work before the live file is opened.
///
/// Nothing is deleted. The file in use is MOVED (with its log files) into `previous/<time>/` and stays there; the new file is checked before it takes
/// its place and checked again after; any failure puts everything back as it was.
library;

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import '../db/app_database.dart';
import 'swap_types.dart';

String _live(String dir) => p.join(dir, 'shop.sqlite');
String _pendingFile(String dir) => p.join(dir, 'swap.pending.json');
String _resultFile(String dir) => p.join(dir, 'swap.result.json');
const _exts = ['', '-wal', '-shm'];

String _stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

Future<void> requestImportSwap({required String dataDir, required String newFile, required Map<String, int> expected, required String source}) async {
  if (!p.isWithin(dataDir, newFile)) throw ArgumentError('The new data file must be inside the data folder.');
  await File(_pendingFile(dataDir)).writeAsString(jsonEncode({'kind': 'import', 'file': p.relative(newFile, from: dataDir), 'expected': expected, 'source': source, 'requestedAt': DateTime.now().toIso8601String()}));
}

/// A restore from a backup file: the file is first COPIED into the data folder (the backup itself is never moved or changed), then the same careful
/// switch as an import happens at start-up, and finally this computer's own bill letter and bill counters are carried over so a bill number is never reused.
Future<void> requestRestore({required String dataDir, required String backupFile, required String source}) async {
  final imp = Directory(p.join(dataDir, 'import'))..createSync(recursive: true);
  final copy = p.join(imp.path, 'restore-${_stamp(DateTime.now())}.sqlite');
  await File(backupFile).copy(copy);
  await File(_pendingFile(dataDir)).writeAsString(jsonEncode({'kind': 'restore', 'file': p.relative(copy, from: dataDir), 'expected': <String, int>{}, 'source': source, 'requestedAt': DateTime.now().toIso8601String()}));
}

Future<void> requestGoBack({required String dataDir, required String stamp}) async {
  await File(_pendingFile(dataDir)).writeAsString(jsonEncode({'kind': 'goback', 'stamp': stamp, 'requestedAt': DateTime.now().toIso8601String()}));
}

Map<String, int>? _counts(String file) {
  Database? db;
  try {
    db = sqlite3.open(file, mode: OpenMode.readOnly);
    // live rows only, the same way the import counts what it wrote (a product removed in ERP 1 is kept but not counted)
    int n(String t, {bool live = false}) => db!.select(live ? 'SELECT COUNT(*) FROM $t WHERE deleted_at IS NULL' : 'SELECT COUNT(*) FROM $t').first.values.first as int;
    return {'products': n('products', live: true), 'customers': n('customers', live: true), 'bills': n('bills')};
  } catch (_) {
    return null;
  } finally {
    db?.close();
  }
}

/// null = fine; otherwise the plain-English reason the file cannot be used.
String? _verify(String file, {Map<String, int>? expected, bool full = true}) {
  Database? db;
  try {
    db = sqlite3.open(file, mode: OpenMode.readOnly);
    final v = db.select('PRAGMA user_version').first.values.first as int;
    if (v < 1 || v > currentSchemaVersion) return 'The new data file is from a different version of the program.';
    final c = db.select(full ? 'PRAGMA integrity_check' : 'PRAGMA quick_check');
    if (c.length != 1 || c.first.values.first != 'ok') return 'The new data file did not pass the integrity check.';
    if (expected != null) {
      int n(String t) => db!.select(t == 'bills' ? 'SELECT COUNT(*) FROM $t' : 'SELECT COUNT(*) FROM $t WHERE deleted_at IS NULL').first.values.first as int;
      for (final e in expected.entries) {
        if (const {'products', 'customers', 'bills'}.contains(e.key)) {
          final got = n(e.key);
          if (got != e.value) return 'The new data file holds $got ${e.key} but ${e.value} were expected.';
        }
      }
    }
    return null;
  } catch (e) {
    return 'The new data file could not be opened ($e).';
  } finally {
    db?.close();
  }
}

Future<void> _writeResult(String dir, SwapResult r) =>
    File(_resultFile(dir)).writeAsString(jsonEncode({'ok': r.ok, 'kind': r.kind, 'message': r.message, 'at': r.at.toIso8601String(), 'prev': r.prevStamp, 'counts': r.counts}));

Future<SwapResult?> lastSwapResult(String dataDir) async {
  try {
    final f = File(_resultFile(dataDir));
    if (!f.existsSync()) return null;
    final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    return SwapResult(
      ok: j['ok'] == true,
      kind: '${j['kind']}',
      message: '${j['message']}',
      at: DateTime.parse('${j['at']}'),
      prevStamp: '${j['prev'] ?? ''}',
      counts: {for (final e in (j['counts'] as Map? ?? {}).entries) '${e.key}': (e.value as num).toInt()},
    );
  } catch (_) {
    return null;
  }
}

Future<void> clearSwapResult(String dataDir) async {
  final f = File(_resultFile(dataDir));
  if (f.existsSync()) f.deleteSync();
}

void _moveSet(String fromBase, String toBase, List<String> moved) {
  for (final e in _exts) {
    final f = File('$fromBase$e');
    if (f.existsSync()) {
      f.renameSync('$toBase$e');
      moved.add(e);
    }
  }
}

/// Runs at start-up, BEFORE the live file is opened. Returns what happened, or null when nothing was waiting.
Future<SwapResult?> applyPendingSwap(String dataDir, {DateTime? now}) async {
  final pf = File(_pendingFile(dataDir));
  if (!pf.existsSync()) return null;
  final at = now ?? DateTime.now();
  Map<String, dynamic> req;
  try {
    req = jsonDecode(await pf.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    pf.renameSync(p.join(dataDir, 'swap.pending.unreadable'));
    final r = SwapResult(ok: false, kind: 'import', message: 'A waiting data switch could not be read and was ignored. Your data is as it was.', at: at);
    await _writeResult(dataDir, r);
    return r;
  }
  final kind = '${req['kind']}';
  SwapResult fail(String m) => SwapResult(ok: false, kind: kind, message: '$m Your data is as it was.', at: at);
  late SwapResult result;
  try {
    result = kind == 'goback' ? await _goBack(dataDir, '${req['stamp']}', at, fail) : await _importSwap(dataDir, req, at, fail, restore: kind == 'restore');
  } catch (e) {
    result = fail('The switch could not be completed ($e).');
  }
  if (pf.existsSync()) pf.deleteSync();
  await _writeResult(dataDir, result);
  return result;
}

Future<SwapResult> _importSwap(String dir, Map<String, dynamic> req, DateTime at, SwapResult Function(String) fail, {bool restore = false}) async {
  final newFile = p.normalize(p.join(dir, '${req['file']}'));
  if (!p.isWithin(dir, newFile) || !File(newFile).existsSync()) return fail('The new data file was not found.');
  final expected = {for (final e in (req['expected'] as Map? ?? {}).entries) '${e.key}': (e.value as num).toInt()};
  final bad = _verify(newFile, expected: expected, full: File(newFile).lengthSync() < 500 * 1024 * 1024);
  if (bad != null) return fail(bad);

  final live = _live(dir);
  final stamp = _stamp(at);
  final prev = Directory(p.join(dir, 'previous', stamp))..createSync(recursive: true);
  final liveExists = File(live).existsSync();
  final before = liveExists ? _counts(live) : null;
  final beforeBytes = liveExists ? File(live).lengthSync() : 0;
  final moved = <String>[];
  try {
    _moveSet(live, p.join(prev.path, 'shop.sqlite'), moved);
    File(newFile).renameSync(live);
    if (restore && moved.isNotEmpty) _carryOver(p.join(prev.path, 'shop.sqlite'), live);
    final after = _verify(live, expected: expected, full: false);
    if (after != null) throw StateError(after);
  } catch (e) {
    // put everything back exactly as it was
    final broken = File(live);
    if (broken.existsSync()) broken.renameSync(p.join(dir, 'rejected-$stamp.sqlite'));
    for (final ext in moved) {
      final f = File('${p.join(prev.path, 'shop.sqlite')}$ext');
      if (f.existsSync()) f.renameSync('$live$ext');
    }
    return fail('The new data could not be put in place ($e).');
  }
  await File(p.join(prev.path, 'meta.json')).writeAsString(jsonEncode({
    'at': at.toIso8601String(),
    'reason': restore ? 'Before restoring from a backup (${req['source'] ?? ''})' : 'Before importing from ERP 1 (${req['source'] ?? ''})',
    'products': before?['products'],
    'customers': before?['customers'],
    'bills': before?['bills'],
    'bytes': beforeBytes,
    'hadData': moved.isNotEmpty,
  }));
  return SwapResult(ok: true, kind: restore ? 'restore' : 'import', message: restore ? 'Your data was restored from the backup.' : 'Your ERP 1 data is now in use.', at: at, prevStamp: stamp, counts: _counts(live) ?? const <String, int>{});
}

Future<SwapResult> _goBack(String dir, String stamp, DateTime at, SwapResult Function(String) fail) async {
  final prev = p.join(dir, 'previous', stamp);
  final prevFile = p.join(prev, 'shop.sqlite');
  if (!p.isWithin(p.join(dir, 'previous'), prev) || !File(prevFile).existsSync()) return fail('The earlier data was not found.');
  final live = _live(dir);
  final newStamp = '${_stamp(at)}-before-go-back';
  final aside = Directory(p.join(dir, 'previous', newStamp))..createSync(recursive: true);
  final liveExists = File(live).existsSync();
  final before = liveExists ? _counts(live) : null;
  final beforeBytes = liveExists ? File(live).lengthSync() : 0;
  final movedLive = <String>[], movedPrev = <String>[];
  try {
    _moveSet(live, p.join(aside.path, 'shop.sqlite'), movedLive);
    _moveSet(prevFile, live, movedPrev);
  } catch (e) {
    for (final ext in movedPrev) {
      final f = File('$live$ext');
      if (f.existsSync()) f.renameSync('$prevFile$ext');
    }
    for (final ext in movedLive) {
      final f = File('${p.join(aside.path, 'shop.sqlite')}$ext');
      if (f.existsSync()) f.renameSync('$live$ext');
    }
    return fail('Going back could not be completed ($e).');
  }
  await File(p.join(aside.path, 'meta.json')).writeAsString(jsonEncode({
    'at': at.toIso8601String(),
    'reason': 'The data that was in use before you went back',
    'products': before?['products'],
    'customers': before?['customers'],
    'bills': before?['bills'],
    'bytes': beforeBytes,
    'hadData': movedLive.isNotEmpty,
  }));
  final metaOld = File(p.join(prev, 'meta.json'));
  if (metaOld.existsSync()) metaOld.renameSync(p.join(prev, 'meta.restored.json'));
  return SwapResult(ok: true, kind: 'goback', message: 'You are back on the earlier data.', at: at, prevStamp: newStamp, counts: _counts(live) ?? const <String, int>{});
}

/// After a restore from an OLDER backup: this computer keeps its bill letter (and the shop's list of letters), and every bill counter keeps the higher
/// of the two values, so a bill number that was already used after the backup was made is never handed out again.
void _carryOver(String previousFile, String restoredFile) {
  Database? old, now;
  try {
    old = sqlite3.open(previousFile, mode: OpenMode.readOnly);
    now = sqlite3.open(restoredFile);
    final oldSeries = old.select("SELECT value FROM kv WHERE name = 'shop.series'");
    if (oldSeries.isNotEmpty) {
      final merged = <String, dynamic>{};
      final cur = now.select("SELECT value FROM kv WHERE name = 'shop.series'");
      for (final raw in [if (cur.isNotEmpty) cur.first.values.first as String, oldSeries.first.values.first as String]) {
        try {
          final m = jsonDecode(raw);
          if (m is Map) {
            for (final e in m.entries) {
              merged.putIfAbsent('${e.key}', () => e.value);
            }
          }
        } catch (_) {}
      }
      now.execute("INSERT INTO kv(name, value, updated_at) VALUES ('shop.series', ?, ?) ON CONFLICT(name) DO UPDATE SET value = excluded.value", [jsonEncode(merged), DateTime.now().millisecondsSinceEpoch]);
    }
    for (final r in old.select("SELECT name, value FROM counters WHERE name LIKE 'inv.%'")) {
      now.execute('INSERT INTO counters(name, value) VALUES (?, ?) ON CONFLICT(name) DO UPDATE SET value = MAX(value, excluded.value)', [r['name'], r['value']]);
    }
  } finally {
    old?.close();
    now?.close();
  }
}

/// The earlier data sets that can still be gone back to (30 days), newest first.
Future<List<PreviousData>> previousData(String dataDir, {DateTime? now}) async {
  final root = Directory(p.join(dataDir, 'previous'));
  if (!root.existsSync()) return const [];
  final t = now ?? DateTime.now();
  final out = <PreviousData>[];
  for (final d in root.listSync().whereType<Directory>()) {
    final meta = File(p.join(d.path, 'meta.json'));
    if (!meta.existsSync() || !File(p.join(d.path, 'shop.sqlite')).existsSync()) continue;
    try {
      final j = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
      final at = DateTime.parse('${j['at']}');
      if (t.difference(at).inDays > 30 || j['hadData'] == false) continue;
      int? n(String k) => (j[k] as num?)?.toInt();
      out.add(PreviousData(stamp: p.basename(d.path), at: at, products: n('products'), customers: n('customers'), bills: n('bills'), bytes: n('bytes') ?? 0, reason: '${j['reason'] ?? ''}'));
    } catch (_) {}
  }
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}
