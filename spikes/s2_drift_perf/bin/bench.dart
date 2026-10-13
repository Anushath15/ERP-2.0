import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:s2_drift_perf/db.dart';
import 'package:uuid/uuid.dart';

final _u = const Uuid();
final _rnd = Random(42);

const brands = ['Havells', 'Anchor', 'Polycab', 'Finolex', 'Astral', 'Supreme', 'Ashirvad', 'Jaquar', 'Cera', 'Orient', 'Crompton', 'Legrand', 'Philips', 'Bosch', 'Asian Paints', 'Fevicol'];
const things = ['wire', 'switch', 'socket', 'MCB', 'pipe', 'elbow', 'tee', 'valve', 'tap', 'bulb', 'tube light', 'fan', 'hammer', 'drill bit', 'screw', 'nut bolt', 'hinge', 'lock', 'paint', 'brush', 'tape', 'cable', 'holder', 'plug', 'adaptor', 'trap', 'coupling', 'clamp', 'sealant', 'cutter'];
const sizes = ['0.5 inch', '1 inch', '1.5 sq mm', '2.5 sq mm', '4 sq mm', '16A', '6A', '32A', '9W', '12W', '20W', '100 mm', '75 mm', '3/4 inch', 'heavy', 'white', 'black', '1 litre', '4 litre'];

String productName(int i) =>
    '${brands[_rnd.nextInt(brands.length)]} ${things[_rnd.nextInt(things.length)]} ${sizes[_rnd.nextInt(sizes.length)]} #$i';

class Stats {
  Stats(List<double> ms) {
    ms.sort();
    p50 = ms[ms.length ~/ 2];
    p95 = ms[(ms.length * 0.95).floor().clamp(0, ms.length - 1)];
    max = ms.last;
  }
  late final double p50, p95, max;
  @override
  String toString() =>
      'p50=${p50.toStringAsFixed(2)}ms p95=${p95.toStringAsFixed(2)}ms max=${max.toStringAsFixed(2)}ms';
}

Future<double> timeIt(Future<void> Function() f) async {
  final sw = Stopwatch()..start();
  await f();
  return sw.elapsedMicroseconds / 1000.0;
}

Future<void> main(List<String> args) async {
  final nProducts = int.parse(args.isNotEmpty ? args[0] : '5000');
  final nCustomers = int.parse(args.length > 1 ? args[1] : '5000');
  final nBills = int.parse(args.length > 2 ? args[2] : '50000');
  final sync = args.length > 3 ? args[3] : 'FULL';
  final path =
      '${Directory.systemTemp.path}\\perf_${DateTime.now().microsecondsSinceEpoch}.sqlite';
  print('== products=$nProducts customers=$nCustomers bills=$nBills synchronous=$sync');
  final db = PerfDb(NativeDatabase(File(path)), sync: sync);
  await db.customSelect('SELECT 1').get();

  final pids = <String>[];
  final cids = <String>[];
  final names = <String>[];
  final now = DateTime(2026, 10, 13).millisecondsSinceEpoch;

  var t = await timeIt(() async {
    await db.transaction(() async {
      await db.batch((b) {
        for (var i = 0; i < nProducts; i++) {
          final id = _u.v7();
          pids.add(id);
          final n = productName(i);
          names.add(n);
          b.insert(
              db.products,
              ProductsCompanion.insert(
                  id: id,
                  name: n,
                  barcode: Value('89012${i.toString().padLeft(7, '0')}'),
                  pricePaise: 1000 + _rnd.nextInt(500000),
                  updatedAt: now));
        }
        for (var i = 0; i < nCustomers; i++) {
          final id = _u.v7();
          cids.add(id);
          b.insert(
              db.customers,
              CustomersCompanion.insert(
                  id: id,
                  name: 'Customer ${i.toRadixString(36)} Traders',
                  phone: Value('98${(40000000 + i)}'),
                  updatedAt: now));
        }
      });
      await db.customStatement(
          'INSERT INTO product_fts(rowid,name,barcode) SELECT rowid,name,barcode FROM products');
    });
  });
  print('seed products+customers: ${t.toStringAsFixed(0)} ms');

  t = await timeIt(() async {
    for (var start = 0; start < nBills; start += 5000) {
      await db.transaction(() async {
        await db.batch((b) {
          for (var i = start; i < min(start + 5000, nBills); i++) {
            final id = _u.v7();
            final at = now - (nBills - i) * 600000;
            final cid = cids[_rnd.nextInt(cids.length)];
            var total = 0;
            for (var l = 0; l < 4; l++) {
              final pid = pids[_rnd.nextInt(pids.length)];
              final amt = 5000 + _rnd.nextInt(300000);
              total += amt;
              b.insert(
                  db.billLines,
                  BillLinesCompanion.insert(
                      id: _u.v7(),
                      billId: id,
                      productId: pid,
                      qtyMilli: 1000 * (1 + _rnd.nextInt(5)),
                      amountPaise: amt));
              b.insert(
                  db.stockMovements,
                  StockMovementsCompanion.insert(
                      id: _u.v7(), productId: pid, qtyMilli: -1000, kind: 'sale', at: at));
            }
            b.insert(
                db.bills,
                BillsCompanion.insert(
                    id: id,
                    number: 'A-${i + 1}',
                    customerId: Value(cid),
                    totalPaise: total,
                    billedAt: at,
                    updatedAt: at,
                    idemKey: id));
            b.insert(
                db.ledgerEntries,
                LedgerEntriesCompanion.insert(
                    id: _u.v7(), customerId: cid, amountPaise: total, at: at));
          }
        });
      });
    }
  });
  print('seed $nBills bills (+${nBills * 4} lines/movements, $nBills ledger): ${t.toStringAsFixed(0)} ms');
  await db.customStatement('ANALYZE');
  print('db size: ${(File(path).lengthSync() / 1048576).toStringAsFixed(1)} MB');

  // 1. product search per keystroke (FTS5 prefix)
  final searchMs = <double>[];
  for (var k = 0; k < 150; k++) {
    final n = names[_rnd.nextInt(names.length)].toLowerCase();
    final typed = n.substring(0, min(n.length, 14));
    for (var c = 1; c <= typed.length; c++) {
      final q = typed.substring(0, c).trim();
      if (q.isEmpty) continue;
      final toks = q
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .map((s) => '"${s.replaceAll('"', '')}"*')
          .join(' ');
      searchMs.add(await timeIt(() async {
        await db.customSelect(
            'SELECT p.id,p.name,p.price_paise FROM product_fts f JOIN products p ON p.rowid=f.rowid WHERE product_fts MATCH ? AND p.deleted_at IS NULL ORDER BY rank LIMIT 50',
            variables: [Variable<String>(toks)]).get();
      }));
    }
  }
  print('product search FTS5 per keystroke (${searchMs.length} samples): ${Stats(searchMs)}  budget<16ms');

  final bc = <double>[];
  for (var i = 0; i < 300; i++) {
    final code = '89012${_rnd.nextInt(nProducts).toString().padLeft(7, '0')}';
    bc.add(await timeIt(() async {
      await db.customSelect('SELECT id,name FROM products WHERE barcode=?',
          variables: [Variable<String>(code)]).get();
    }));
  }
  print('barcode lookup (NO index, full scan): ${Stats(bc)}');

  final cs = <double>[];
  for (var i = 0; i < 200; i++) {
    final q = 'customer ${_rnd.nextInt(2000).toRadixString(36)}';
    cs.add(await timeIt(() async {
      await db.customSelect('SELECT id,name FROM customers WHERE name LIKE ? LIMIT 50',
          variables: [Variable<String>('$q%')]).get();
    }));
  }
  print('customer search (LIKE prefix): ${Stats(cs)}');

  final lp = <double>[];
  for (var i = 0; i < 100; i++) {
    lp.add(await timeIt(() async {
      await db.customSelect(
          'SELECT b.*, c.name AS cname FROM bills b LEFT JOIN customers c ON c.id=b.customer_id ORDER BY b.billed_at DESC LIMIT 50 OFFSET ?',
          variables: [Variable<int>(i * 400)]).get();
    }));
  }
  print('bill list page (50 rows, offsets 0..40000, joined): ${Stats(lp)}  budget<300ms');

  final sv = <double>[];
  for (var i = 0; i < 300; i++) {
    sv.add(await timeIt(() async {
      await db.transaction(() async {
        final id = _u.v7();
        final seq = await db.customSelect('SELECT COUNT(*)+1 AS n FROM bills').getSingle();
        final cid = cids[_rnd.nextInt(cids.length)];
        var total = 0;
        for (var l = 0; l < 4; l++) {
          final pid = pids[_rnd.nextInt(pids.length)];
          final amt = 5000 + _rnd.nextInt(300000);
          total += amt;
          await db.into(db.billLines).insert(BillLinesCompanion.insert(
              id: _u.v7(), billId: id, productId: pid, qtyMilli: 1000, amountPaise: amt));
          await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
              id: _u.v7(), productId: pid, qtyMilli: -1000, kind: 'sale', at: now));
        }
        await db.into(db.bills).insert(BillsCompanion.insert(
            id: id,
            number: 'A-${seq.read<int>('n')}',
            customerId: Value(cid),
            totalPaise: total,
            billedAt: now,
            updatedAt: now,
            idemKey: id));
        await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
            id: _u.v7(), customerId: cid, amountPaise: total, at: now));
        await db.into(db.outbox).insertOnConflictUpdate(
            OutboxCompanion.insert(recordId: id, kind: 'bill', at: now));
      });
    }));
  }
  print('save bill (1 txn, 4 lines, COUNT-based number): ${Stats(sv)}  budget<150ms');

  final r1 = await timeIt(() async {
    await db.customSelect(
        "SELECT strftime('%Y-%m-%d', billed_at/1000,'unixepoch') d, COUNT(*) n, SUM(total_paise) s FROM bills WHERE billed_at>=? GROUP BY d",
        variables: [Variable<int>(now - 30 * 86400000)]).get();
  });
  final r2 = await timeIt(() async {
    await db.customSelect(
        'SELECT product_id, SUM(amount_paise) s FROM bill_lines GROUP BY product_id ORDER BY s DESC LIMIT 20').get();
  });
  final r3 = await timeIt(() async {
    await db.customSelect('SELECT product_id, SUM(qty_milli) q FROM stock_movements GROUP BY product_id').get();
  });
  final r4 = await timeIt(() async {
    await db.customSelect('SELECT customer_id, SUM(amount_paise) q FROM ledger_entries GROUP BY customer_id').get();
  });
  final r5 = await timeIt(() async {
    await db.customSelect(
        'SELECT p.id, COALESCE((SELECT SUM(qty_milli) FROM stock_movements m WHERE m.product_id=p.id),0) q FROM products p ORDER BY p.name LIMIT 50').get();
  });
  print('report: 30-day sales by day: ${r1.toStringAsFixed(1)} ms');
  print('report: top 20 products over ${nBills * 4} lines: ${r2.toStringAsFixed(1)} ms');
  print('report: stock of ALL products (sum movements): ${r3.toStringAsFixed(1)} ms');
  print('report: balance of ALL customers (sum ledger): ${r4.toStringAsFixed(1)} ms');
  print('screen: inventory page of 50 w/ live stock subquery: ${r5.toStringAsFixed(1)} ms');

  final qc = await timeIt(() async => db.customSelect('PRAGMA quick_check').get());
  final ic = await timeIt(() async => db.customSelect('PRAGMA integrity_check').get());
  print('quick_check: ${qc.toStringAsFixed(0)} ms; integrity_check: ${ic.toStringAsFixed(0)} ms');
  await db.close();
  for (final s in ['', '-wal', '-shm']) {
    try {
      File('$path$s').deleteSync();
    } catch (_) {}
  }
}
