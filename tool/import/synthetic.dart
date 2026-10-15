/// Makes a SYNTHETIC ERP 1 backup (invented shop, invented people) in the same shape ERP 1 writes, for tests and for timing the importer.
///
///   dart run tool/import/synthetic.dart [bills=2000] [out=build/synthetic_erp1.json]
///
/// It is not real shop data. Money is written as decimal rupees and quantities as decimals, like ERP 1, and a few records are deliberately
/// wrong (see [Synthetic.flaws]) so the importer has something to report.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

class Synthetic {
  Synthetic({this.bills = 2000, this.products = 300, this.customers = 120, this.dealers = 15, this.seed = 7, this.flaws = true});
  final int bills, products, customers, dealers, seed;
  final bool flaws;

  /// What was put in on purpose: the importer's report should mention each.
  final planted = <String>[];

  Map<String, Object?> build() {
    final r = Random(seed);
    double rs(num paise) => paise / 100;
    final prods = <Map<String, Object?>>[];
    for (var i = 1; i <= products; i++) {
      final cost = 1000 + r.nextInt(90000);
      prods.add({
        'id': 'PRD-${i.toString().padLeft(5, '0')}',
        'name': 'Item $i ${['pipe', 'wire', 'switch', 'bulb', 'paint', 'tap', 'bolt'][i % 7]}',
        'category': ['Plumbing', 'Electrical', 'Paint', 'Hardware'][i % 4],
        'unit': i % 9 == 0 ? 'm' : 'pcs',
        'price': rs((cost * 1.25).round()),
        'buyingPrice': i % 17 == 0 ? 0 : rs(cost),
        'avgCost': rs((cost * 1.02).round()),
        'taxRate': [18, 12, 5, 28][i % 4],
        'barcode': 'BC${100000 + i}',
        'minStock': 5,
        'stock': r.nextInt(400) / (i % 9 == 0 ? 4 : 1),
        'status': i % 23 == 0 ? 'Inactive' : 'Active',
        'isDeleted': false,
        'createdAt': '2024-04-01T09:00:00.000Z',
      });
    }
    final custs = <Map<String, Object?>>[
      for (var i = 1; i <= customers; i++)
        {'id': 'CUS-${i.toString().padLeft(5, '0')}', 'name': 'Customer $i', 'phone': '9${(800000000 + i * 7919).toString().padLeft(9, '0')}', 'area': 'Area ${i % 9}', 'address': 'Street $i', 'creditLimit': 50000, 'outstanding': 0.0, 'isDeleted': false, 'whatsapp': '9000000000', 'creditDays': 30},
    ];
    final deals = <Map<String, Object?>>[
      for (var i = 1; i <= dealers; i++) {'id': 'DLR-${i.toString().padLeft(4, '0')}', 'companyName': 'Dealer $i Traders', 'phone': '8${(700000000 + i * 104729).toString().padLeft(9, '0')}', 'outstanding': 0.0}
    ];
    final owed = <String, int>{}; // customer paise owed, built from the bills so the figures are consistent
    final invoices = <Map<String, Object?>>[];
    final start = DateTime.utc(2024, 4, 1, 4, 0);
    for (var n = 1; n <= bills; n++) {
      final when = start.add(Duration(minutes: (n * 37) % (60 * 24 * 600 ~/ 1) + n * 3));
      final lines = 1 + r.nextInt(5);
      final items = <Object?>[];
      var sum = 0;
      var tax = 0;
      for (var k = 0; k < lines; k++) {
        final pr = prods[r.nextInt(prods.length)];
        final qty = 1 + r.nextInt(4);
        final priceP = ((pr['price'] as double) * 100).round();
        final t = priceP * qty;
        final gst = pr['taxRate'] as int;
        final lineTax = t - (t * 10000 / (10000 + gst * 100)).round();
        sum += t;
        tax += lineTax;
        items.add({'productId': pr['id'], 'name': pr['name'], 'qty': qty, 'price': rs(priceP), 'taxRate': gst, 'pricingMode': 'inclusive', 'costPrice': pr['buyingPrice'], 'hsnCode': '8481', 'discountPercent': 0, 'discountAmount': 0, 'total': rs(t)});
      }
      final cust = n % 3 == 0 ? custs[r.nextInt(custs.length)] : null;
      final cancelled = n % 41 == 0;
      final credit = cust != null && n % 6 == 0;
      final paid = credit ? (sum * (r.nextInt(2) == 0 ? 0 : 0.4)).round() : sum;
      if (credit && !cancelled) owed[cust['id'] as String] = (owed[cust['id'] as String] ?? 0) + (sum - paid);
      invoices.add({
        'id': 'INV-2425-${n.toString().padLeft(6, '0')}',
        'date': when.toIso8601String(),
        'customerId': cust?['id'],
        'customerName': cust?['name'] ?? 'Walk-in Customer',
        'items': items,
        'subtotal': rs(sum - tax),
        'discount': 0,
        'taxableAmount': rs(sum - tax),
        'cgstTotal': rs(tax ~/ 2),
        'sgstTotal': rs(tax - tax ~/ 2),
        'igstTotal': 0,
        'roundOff': 0,
        'totalAmount': rs(sum),
        'paymentMode': credit ? 'Credit' : ['Cash', 'UPI', 'Card'][n % 3],
        'amountPaid': rs(paid),
        'paymentStatus': paid == sum ? 'Paid Full' : (paid == 0 ? 'Pending' : 'Partial'),
        if (cancelled) ...{'status': 'Cancelled', 'cancelReason': 'Wrong item'},
        'isDeleted': false,
      });
    }
    // payments: each customer pays back part of what they owe
    final pays = <Map<String, Object?>>[];
    var pn = 0;
    for (final e in owed.entries.toList()) {
      if (e.value < 200) continue;
      final amt = (e.value * 0.5).floor();
      pn++;
      pays.add({'id': 'CPAY-${pn.toString().padLeft(5, '0')}', 'customerId': e.key, 'amount': rs(amt), 'method': 'Cash', 'date': '2025-06-${(1 + pn % 27).toString().padLeft(2, '0')}'});
      owed[e.key] = e.value - amt;
    }
    for (final c in custs) {
      c['outstanding'] = rs(owed[c['id']] ?? 0);
    }
    // two customers have an old balance typed in by hand (the importer must carry it as an opening entry)
    custs[0]['outstanding'] = (custs[0]['outstanding'] as double) + 1250.5;
    custs[1]['outstanding'] = -300.0;
    final purchases = <Map<String, Object?>>[];
    for (var i = 1; i <= 40; i++) {
      final dlr = deals[i % deals.length];
      final pr = prods[i % prods.length];
      final total = 5000 + r.nextInt(50000);
      final paid = i % 3 == 0 ? total : total ~/ 2;
      final pend = i % 10 == 0;
      purchases.add({'id': 'PUR-${i.toString().padLeft(5, '0')}', 'date': '2024-1${i % 3}-15', 'dealerId': dlr['id'], 'dealerName': dlr['companyName'], 'items': [
        {'productId': pr['id'], 'qty': 10, 'costPrice': total / 10}
      ], 'totalAmount': total.toDouble(), 'amountPaid': paid.toDouble(), 'status': pend ? 'Pending' : 'Received', 'stockApplied': !pend});
      if (!pend) dlr['outstanding'] = (dlr['outstanding'] as double) + (total - paid);
    }
    final adjustments = [
      for (var i = 1; i <= 12; i++) {'id': 'ADJ-${i.toString().padLeft(6, '0')}', 'productId': prods[i]['id'], 'type': 'Damaged', 'qty': 1, 'reason': 'Broken', 'date': '2025-01-${(1 + i).toString().padLeft(2, '0')}T10:00:00.000Z', 'previousStock': 10, 'newStock': 9}
    ];
    final expenses = [
      for (var i = 1; i <= 30; i++) {'id': 'EXP-$i', 'date': '2025-02-${(1 + i % 27).toString().padLeft(2, '0')}', 'category': 'Tea', 'amount': 40.0 + i, 'method': 'Cash', 'description': 'Tea and snacks'}
    ];
    final data = <String, Object?>{
      'erp_products': prods,
      'erp_categories': [for (final c in ['Plumbing', 'Electrical', 'Paint', 'Hardware']) {'id': 'CAT-$c', 'name': c}],
      'erp_customers': custs,
      'erp_dealers': deals,
      'erp_sales_invoices': invoices,
      'erp_credit_payments': pays,
      'erp_purchases': purchases,
      'erp_stock_adjustments': adjustments,
      'erp_expenses': expenses,
      'erp_sales_returns': [
        {'id': 'SRT-1', 'date': '2025-03-01', 'invoice': 'INV-2425-000003', 'customerId': custs[2]['id'], 'product': 'Item 1', 'qty': 1, 'amount': 120.0, 'reason': 'Defective', 'status': 'Approved'}
      ],
      'erp_estimations': [
        {'id': 'EST-1', 'date': '2025-03-05T10:00:00.000Z', 'customerName': 'Walk-in Customer', 'items': [
          {'productId': prods[0]['id'], 'name': prods[0]['name'], 'qty': 2, 'price': prods[0]['price'], 'taxRate': 18, 'total': (prods[0]['price'] as double) * 2}
        ], 'totalAmount': (prods[0]['price'] as double) * 2, 'status': 'Draft'}
      ],
      'erp_settings': {'shopName': 'Synthetic Traders', 'ownerName': 'Test Owner', 'address': '1 Test Road', 'gstin': '33AAAAA0000A1Z5', 'phone': '9999999999', 'invoicePrefix': 'INV-'},
      'erp_system_state': {'lastSalesInvoice_2425': bills},
      'erp_daily_closings': [
        {'id': 'DC-1', 'date': '2025-03-31', 'cash': 1000}
      ],
    };
    if (flaws && invoices.length > 10 && prods.length > 30) {
      // things a real backup could contain
      (invoices[3]['items']! as List<Object?>).add({'productId': 'GONE-1', 'name': 'Deleted product', 'qty': 1, 'price': 10.0, 'total': 10.0});
      planted.add('a bill line for a product that is not in the product list');
      invoices[4]['date'] = 'not a date';
      planted.add('a bill with an unreadable date');
      invoices[5]['totalAmount'] = 'abc';
      planted.add('a bill with a total that is not a number');
      invoices.add(Map<String, Object?>.from(invoices[6]));
      planted.add('the same bill number twice');
      ((invoices[7]['items']) as List<Object?>)[0] = 'junk';
      planted.add('a bill line that is not an object');
      invoices[8]['amountPaid'] = 99999999.0;
      planted.add('amount paid above the total');
      prods[2]['stock'] = -3;
      planted.add('negative stock');
      prods[3]['barcode'] = prods[4]['barcode'];
      planted.add('a barcode used by two products');
      (data['erp_expenses'] as List).add({'id': 'EXP-X', 'date': '2025-02-01', 'amount': -5, 'category': 'Bad'});
      planted.add('an expense with a negative amount');
      (data['erp_credit_payments'] as List).add({'id': 'CPAY-X', 'customerId': 'NOBODY', 'amount': 10, 'date': '2025-01-01'});
      planted.add('a payment for a customer that does not exist');
      prods[5]['price'] = 10.123;
      planted.add('a price with three decimals');
      data['erp_mystery_list'] = [1, 2, 3];
      planted.add('a list the importer has no home for');
    }
    return {
      '_metadata': {'format': 'senthil_erp_full_backup_v2', 'timestamp': '2025-07-01T10:00:00.000Z', 'keyCount': data.length, 'recordCount': 0, 'checksum': 'synthetic'},
      'data': data,
    };
  }
}

void main(List<String> args) {
  final n = args.isNotEmpty ? int.parse(args[0]) : 2000;
  final out = args.length > 1 ? args[1] : 'build/synthetic_erp1.json';
  final s = Synthetic(bills: n, products: n > 20000 ? 5000 : 300, customers: n > 20000 ? 2000 : 120);
  final m = s.build();
  File(out).parent.createSync(recursive: true);
  File(out).writeAsStringSync(jsonEncode(m));
  stdout.writeln('wrote $out (${File(out).lengthSync() ~/ 1024} KB, $n bills). Planted flaws:');
  for (final p in s.planted) {
    stdout.writeln('  - $p');
  }
}
