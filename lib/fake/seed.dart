/// Deterministic fake data for the Phase 1 prototype. All names are invented/synthetic style data.
library;

import 'dart:collection';
import 'dart:math';
import 'models.dart';

const categories = ['Electrical', 'Plumbing', 'Hardware', 'Paints', 'Tools', 'Fasteners', 'Lighting', 'Fans', 'Locks', 'Adhesives'];

const _brands = ['HAVELLS', 'ANCHOR', 'POLYCAB', 'FINOLEX', 'ASTRAL', 'SUPREME', 'ASHIRVAD', 'JAQUAR', 'CERA', 'ORIENT', 'CROMPTON', 'LEGRAND', 'PHILIPS', 'BOSCH', 'ASIAN PAINTS', 'FEVICOL', 'GODREJ', 'TAPARIA', 'STANLEY', 'SYSKA'];
const _colors = ['WHITE', 'BLACK', 'RED', 'BLUE', 'YELLOW', 'GREEN', 'GREY'];
const _inch = ['1/2"', '3/4"', '1"', '1 1/4"', '1 1/2"', '2"', '3"', '4"', '6"', '8"', '10"', '12"'];
const _mm = ['25', '32', '40', '45', '50', '55', '65', '75', '90', '100', '110', '125', '160'];
const _sqmm = ['0.75', '1', '1.5', '2.5', '4', '6', '10'];
const _amps = ['6', '10', '16', '20', '32', '40', '63'];
const _watts = ['5', '7', '9', '12', '15', '18', '20', '36'];

/// (template, category, unit, minPrice, maxPrice paise, gst bp). Tokens: {B} brand, {C} colour, {I} inch, {M} mm, {S} sqmm, {A} amps, {W} watts.
const _templates = <(String, String, String, int, int, int)>[
  ('{I}HACKSAW BLADE', 'Tools', 'pcs', 2500, 9000, 1800),
  ('{M}MM DOOR EYE LONG SHACKLE LOCK', 'Locks', 'pcs', 9000, 45000, 1800),
  ('{M}MM BRASS PADLOCK {B}', 'Locks', 'pcs', 15000, 85000, 1800),
  ('{I} TOWER BOLT {C}', 'Hardware', 'pcs', 1500, 12000, 1800),
  ('{I} BARREL BOLT HEAVY', 'Hardware', 'pcs', 1800, 14000, 1800),
  ('{I} GI WIRE NAIL 1KG', 'Fasteners', 'kg', 9000, 14000, 1800),
  ('{I} X {M}MM WOOD SCREW BOX', 'Fasteners', 'box', 4000, 22000, 1800),
  ('{B} {A}A 1 WAY SWITCH {C}', 'Electrical', 'pcs', 1800, 9500, 1800),
  ('{B} {A}A 3 PIN SOCKET {C}', 'Electrical', 'pcs', 2200, 12500, 1800),
  ('{B} {S} SQMM FR WIRE 90M {C}', 'Electrical', 'coil', 90000, 650000, 1800),
  ('{B} {A}A MCB {A}0V SINGLE POLE', 'Electrical', 'pcs', 18000, 62000, 1800),
  ('{B} {W}W LED BULB B22 WARM WHITE', 'Lighting', 'pcs', 6000, 22000, 1200),
  ('{B} {W}W LED BATTEN TUBE LIGHT', 'Lighting', 'pcs', 24000, 58000, 1200),
  ('{B} {M}0MM CEILING FAN {C}', 'Fans', 'pcs', 180000, 420000, 1800),
  ('{B} CPVC {I} ELBOW', 'Plumbing', 'pcs', 1500, 18000, 1800),
  ('{B} CPVC {I} TEE', 'Plumbing', 'pcs', 2000, 22000, 1800),
  ('{B} PVC {I} PIPE 3M', 'Plumbing', 'pcs', 18000, 98000, 1800),
  ('{B} {I} BRASS BIB COCK', 'Plumbing', 'pcs', 24000, 120000, 1800),
  ('{B} {I} BALL VALVE', 'Plumbing', 'pcs', 12000, 85000, 1800),
  ('{B} EMULSION PAINT {W} LTR {C}', 'Paints', 'tin', 45000, 480000, 1800),
  ('{B} SH ADHESIVE {W}0 GM', 'Adhesives', 'pcs', 6000, 38000, 1800),
  ('{B} {I} SPANNER SET', 'Tools', 'set', 35000, 190000, 1800),
  ('{B} {M}MM DRILL BIT HSS', 'Tools', 'pcs', 3000, 24000, 1800),
  ('{B} {I} PAINT BRUSH', 'Paints', 'pcs', 2000, 15000, 1800),
  ('{B} PVC INSULATION TAPE {C}', 'Electrical', 'pcs', 1500, 6500, 1800),
];

String _fill(String t, Random r) {
  String pick(List<String> l) => l[r.nextInt(l.length)];
  return t
      .replaceAll('{B}', pick(_brands))
      .replaceAll('{C}', pick(_colors))
      .replaceAll('{I}', pick(_inch))
      .replaceAll('{M}', pick(_mm))
      .replaceAll('{S}', pick(_sqmm))
      .replaceAll('{A}', pick(_amps))
      .replaceAll('{W}', pick(_watts));
}

List<Product> seedProducts({int count = 757}) {
  final r = Random(2026);
  final seen = <String>{};
  final out = <Product>[];
  var misses = 0;
  while (out.length < count) {
    final t = _templates[r.nextInt(_templates.length)];
    var name = _fill(t.$1, r);
    if (!seen.add(name)) {
      // a very big catalogue (the 50,000-product speed test) runs out of different combinations: make the name different
      if (++misses < 500) continue;
      name = '$name ${out.length + 1}';
      seen.add(name);
      misses = 0;
    }
    final price = ((t.$4 + r.nextInt(t.$5 - t.$4 + 1)) ~/ 50) * 50;
    final i = out.length;
    final stockRoll = r.nextInt(100);
    final stock = stockRoll < 7 ? 0 : (stockRoll < 17 ? 1000 * (1 + r.nextInt(4)) : 1000 * (5 + r.nextInt(120)));
    out.add(Product(
      id: 'p${i + 1}',
      name: name,
      category: t.$2,
      unit: t.$3,
      pricePaise: price,
      costPaise: (price * (62 + r.nextInt(20)) ~/ 100),
      stockMilli: stock,
      gstBp: t.$6,
      barcode: '89012${(34000 + i * 7).toString().padLeft(7, '0')}',
    ));
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}

const _first = ['Murugan', 'Selvam', 'Kumar', 'Rajesh', 'Anand', 'Senthil', 'Ganesh', 'Saravanan', 'Ramesh', 'Vignesh', 'Lakshmi', 'Meena', 'Priya', 'Karthik', 'Mani', 'Bala', 'Dinesh', 'Prakash', 'Suresh', 'Mahesh', 'Arun', 'Gopal', 'Hari', 'Ilango', 'Jegan', 'Kannan', 'Mohan', 'Nandha', 'Palani', 'Raja'];
const _second = ['Electricals', 'Traders', 'Constructions', 'Builders', 'Contractor', 'Engineering', 'Hardware', 'Agencies', 'Enterprises', 'Stores', 'Plumbing Works', '& Sons', 'Interiors', 'Associates'];
const _cities = ['Coimbatore', 'Tiruppur', 'Erode', 'Salem', 'Madurai', 'Karur', 'Namakkal', 'Chennai', 'Trichy', 'Pollachi'];

List<Customer> seedCustomers({int count = 5000}) {
  final r = Random(77);
  return List.generate(count, (i) {
    final roll = r.nextInt(100);
    final withDue = roll < 3;
    final advance = roll == 3; // about 1 in 100 customers has paid in advance
    return Customer(
      id: 'c${i + 1}',
      name: '${_first[r.nextInt(_first.length)]} ${_second[r.nextInt(_second.length)]}${i >= 300 ? ' ${i % 97 + 1}' : ''}',
      phone: i % 25 == 7 ? '' : '98${(40000000 + r.nextInt(59999999)).toString()}', // a few customers have no number saved
      city: _cities[r.nextInt(_cities.length)],
      balancePaise: withDue ? 50000 + r.nextInt(1500000) : (advance ? -(100000 + r.nextInt(1200000)) : 0),
    );
  });
}

class BillBook {
  BillBook(this.base, {this.count = 20000, required this.customers});
  final DateTime base;
  final int count;
  final List<Customer> customers;

  /// Bill `index` (0 = newest). Deterministic, generated on demand so 20,000 bills cost nothing up front.
  BillSummary at(int index) {
    // Fast deterministic hash (no Random object per bill, so 20,000 bills cost milliseconds).
    var h = (index + 1) * 2654435761 & 0xFFFFFFFF;
    int next(int n) {
      h = (h ^ (h << 13)) & 0xFFFFFFFF;
      h = (h ^ (h >> 17)) & 0xFFFFFFFF;
      h = (h ^ (h << 5)) & 0xFFFFFFFF;
      return h % n;
    }

    final number = count - index;
    final date = base.subtract(Duration(minutes: 11 * index + next(8)));
    final total = 8000 + next(next(1800000) + 1);
    final walkIn = next(100) < 45;
    final cust = walkIn ? 'Walk-in customer' : customers[next(customers.length)].name;
    final k = next(100);
    final status = k < 80 ? DocStatus.paid : (k < 90 ? DocStatus.partly : (k < 97 ? DocStatus.due : DocStatus.cancelled));
    final paid = status == DocStatus.paid ? total : (status == DocStatus.partly ? total ~/ 2 : 0);
    final mode = walkIn ? (next(2) == 0 ? PayMode.cash : PayMode.upi) : PayMode.values[next(4)];
    return BillSummary(
      number: 'A-${number.toString().padLeft(6, '0')}',
      date: date,
      customer: cust,
      items: 1 + next(9),
      totalPaise: total,
      paidPaise: paid,
      mode: status == DocStatus.due ? PayMode.credit : mode,
      status: status,
    );
  }

  /// All bills as a lazy list: a bill is only built when something asks for it (and then kept), so opening the
  /// sales register costs nothing up front even with 20,000 bills.
  List<BillSummary> all() => LazyBills(this);
}

List<EstimationDoc> seedEstimations(DateTime base, List<Customer> customers, {int count = 300}) {
  final r = Random(5);
  return List.generate(count, (i) {
    final k = r.nextInt(100);
    final d = base.subtract(Duration(hours: 5 * i + r.nextInt(4)));
    return EstimationDoc(
      number: 'EST-${(count - i).toString().padLeft(5, '0')}',
      date: d,
      customer: customers[r.nextInt(customers.length)].name,
      lines: 1 + r.nextInt(14),
      totalPaise: 50000 + r.nextInt(9000000),
      editedOn: k < 22 ? d.add(Duration(hours: 3 + r.nextInt(30))) : null,
      convertedTo: k >= 22 && k < 40 ? 'A-${(19000 - i).toString().padLeft(6, '0')}' : null,
    );
  });
}

// ---------- generic record lists ----------
List<Rec> seedDealers() {
  const names = ['Sri Murugan Electricals Wholesale', 'Kovai Pipes & Fittings', 'Annai Hardware Distributors', 'Lakshmi Paints Depot', 'National Cable House', 'Sakthi Tools Agency', 'Ganapathy Fasteners', 'Universal Lighting Co', 'Pandian Locks & Hardware', 'Vel Adhesives Traders'];
  final r = Random(9);
  return List.generate(40, (i) => Rec('d${i + 1}', {
        'name': i < names.length ? names[i] : '${names[i % names.length]} ${i ~/ names.length + 1}',
        'phone': '94${(30000000 + r.nextInt(60000000))}',
        'city': _cities[r.nextInt(_cities.length)],
        'balance': r.nextInt(100) < 55 ? 100000 + r.nextInt(8000000) : 0,
      }));
}

List<Rec> seedCategories(List<Product> products) => [
      for (var i = 0; i < categories.length; i++)
        Rec('k$i', {'name': categories[i], 'items': products.where((p) => p.category == categories[i]).length})
    ];

List<Rec> seedPurchases(DateTime base, List<Rec> dealers, {int count = 240}) {
  final r = Random(31);
  return List.generate(count, (i) => Rec('pu$i', {
        'no': 'PUR-${(count - i).toString().padLeft(5, '0')}',
        'date': base.subtract(Duration(days: i ~/ 3, hours: r.nextInt(10))),
        'dealer': dealers[r.nextInt(dealers.length)].s('name'),
        'invoice': 'INV/${1000 + r.nextInt(8999)}',
        'amount': 500000 + r.nextInt(30000000),
        'status': r.nextInt(100) < 85 ? 'received' : 'pending',
      }));
}

List<Rec> seedPurchaseReturns(DateTime base, List<Rec> dealers) {
  final r = Random(32);
  return List.generate(30, (i) => Rec('pr$i', {
        'no': 'PRT-${(30 - i).toString().padLeft(4, '0')}',
        'date': base.subtract(Duration(days: i * 3)),
        'dealer': dealers[r.nextInt(dealers.length)].s('name'),
        'reason': ['Damaged in transport', 'Wrong size sent', 'Quality problem', 'Extra stock'][r.nextInt(4)],
        'amount': 80000 + r.nextInt(3000000),
      }));
}

List<Rec> seedSalesReturns(DateTime base, List<Customer> customers) {
  final r = Random(33);
  return List.generate(60, (i) => Rec('sr$i', {
        'no': 'SRT-${(60 - i).toString().padLeft(4, '0')}',
        'date': base.subtract(Duration(days: i, hours: r.nextInt(8))),
        'customer': customers[r.nextInt(customers.length)].name,
        'bill': 'A-${(19990 - i * 13).toString().padLeft(6, '0')}',
        'reason': ['Wrong item', 'Customer changed mind', 'Damaged', 'Not working'][r.nextInt(4)],
        'amount': 20000 + r.nextInt(900000),
      }));
}

List<Rec> seedDelivery(DateTime base, List<Customer> customers) {
  final r = Random(34);
  const st = ['pending', 'out', 'delivered', 'delivered', 'delivered'];
  return List.generate(80, (i) => Rec('dl$i', {
        'bill': 'A-${(19995 - i * 7).toString().padLeft(6, '0')}',
        'date': base.subtract(Duration(hours: i * 6)),
        'customer': customers[r.nextInt(customers.length)].name,
        'address': '${1 + r.nextInt(120)}, ${['Gandhi Road', 'Market Street', 'Nehru Nagar', 'Bypass Road', 'Temple Street'][r.nextInt(5)]}, ${_cities[r.nextInt(_cities.length)]}',
        'status': i < 6 ? 'pending' : st[r.nextInt(st.length)],
      }));
}

List<Rec> seedAdjustments(DateTime base, List<Product> products) {
  final r = Random(35);
  const reasons = ['Counted stock, found extra', 'Damaged / broken', 'Lost or missing', 'Used in shop', 'Opening stock'];
  return List.generate(120, (i) {
    final neg = r.nextInt(100) < 60;
    return Rec('ad$i', {
      'date': base.subtract(Duration(days: i ~/ 2, hours: r.nextInt(9))),
      'product': products[r.nextInt(products.length)].name,
      'qty': (neg ? -1 : 1) * 1000 * (1 + r.nextInt(8)),
      'reason': reasons[r.nextInt(reasons.length)],
    });
  });
}

List<Rec> seedExpenses(DateTime base) {
  final r = Random(36);
  const cats = ['Shop rent', 'Electricity', 'Staff salary', 'Transport', 'Tea and snacks', 'Repairs', 'Phone and internet', 'Packing material'];
  return List.generate(320, (i) {
    final c = cats[r.nextInt(cats.length)];
    return Rec('ex$i', {
      'date': base.subtract(Duration(days: i ~/ 5, hours: r.nextInt(8))),
      'category': c,
      'note': c == 'Staff salary' ? 'Monthly salary' : (c == 'Shop rent' ? 'Rent for the month' : 'Paid in cash'),
      'amount': c == 'Shop rent' ? 2500000 : (c == 'Staff salary' ? 1800000 : 20000 + r.nextInt(450000)),
    });
  });
}

List<Rec> seedWarranty(DateTime base, List<Customer> customers, List<Product> products) {
  final r = Random(37);
  return List.generate(120, (i) {
    final months = [6, 12, 24, 36][r.nextInt(4)];
    final sold = base.subtract(Duration(days: 10 + r.nextInt(500)));
    return Rec('wa$i', {
      'customer': customers[r.nextInt(customers.length)].name,
      'item': products[r.nextInt(products.length)].name,
      'serial': 'SN${100000 + r.nextInt(899999)}',
      'sold': sold,
      'till': DateTime(sold.year, sold.month + months, sold.day),
    });
  });
}

List<Rec> seedProjects() {
  const names = ['Villa wiring - Race Course Road', 'Apartment plumbing - 24 flats', 'Textile unit lighting', 'School block fans and lights', 'House renovation - Gandhipuram', 'Hostel pipeline work'];
  final r = Random(38);
  return List.generate(names.length, (i) {
    final budget = 20000000 + r.nextInt(60000000);
    return Rec('hp$i', {
      'name': names[i],
      'customer': '${_first[r.nextInt(_first.length)]} ${_second[r.nextInt(_second.length)]}',
      'budget': budget,
      'spent': budget * (20 + r.nextInt(70)) ~/ 100,
      'status': ['running', 'running', 'done', 'planning'][r.nextInt(4)],
    });
  });
}

List<Rec> seedStaff() => const [
      Rec('s1', {'name': 'Senthil Kumar', 'email': 'owner@example.com', 'role': 'owner'}),
      Rec('s2', {'name': 'Murugesan', 'email': 'father@example.com', 'role': 'manager'}),
      Rec('s3', {'name': 'Priya', 'email': 'priya@example.com', 'role': 'cashier'}),
      Rec('s4', {'name': 'Ravi', 'email': 'ravi@example.com', 'role': 'cashier'}),
    ];

List<Rec> seedNotifications(DateTime base) => [
      Rec('n1', {'kind': 'stock', 'text': '12 items are almost finished', 'time': base.subtract(const Duration(minutes: 20)), 'read': 0}),
      Rec('n2', {'kind': 'money', 'text': 'Murugan Traders has not paid for 45 days (Rs. 38,400.00)', 'time': base.subtract(const Duration(hours: 3)), 'read': 0}),
      Rec('n3', {'kind': 'backup', 'text': 'Backup done this morning at 9:02 am', 'time': base.subtract(const Duration(hours: 8)), 'read': 1}),
      Rec('n4', {'kind': 'sync', 'text': 'All your data is safely copied online', 'time': base.subtract(const Duration(hours: 9)), 'read': 1}),
      Rec('n5', {'kind': 'warranty', 'text': '3 warranties finish this month', 'time': base.subtract(const Duration(days: 1)), 'read': 1}),
      Rec('n6', {'kind': 'estimate', 'text': 'EST-00231 was not converted to a bill yet (7 days)', 'time': base.subtract(const Duration(days: 2)), 'read': 1}),
    ];

class LazyBills extends ListBase<BillSummary> {
  LazyBills(this.book);
  final BillBook book;
  final _cache = <int, BillSummary>{};
  @override
  int get length => book.count;
  @override
  set length(int v) => throw UnsupportedError('read-only');
  @override
  BillSummary operator [](int i) => _cache.putIfAbsent(i, () => book.at(i));
  @override
  void operator []=(int i, BillSummary v) => throw UnsupportedError('read-only');
}
