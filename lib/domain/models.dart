/// The shapes the screens work with (products, customers, bill lines, list rows). Plain Dart: no Flutter, no database.
library;

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.pricePaise,
    required this.costPaise,
    required this.stockMilli,
    required this.gstBp,
    required this.barcode,
    this.hsn = '8302',
    this.minStockMilli = 5000,
    this.code = '',
    this.brand = '',
    this.mrpPaise = 0,
  });
  final String id, name, category, unit, barcode, hsn;

  /// Made by the program from the category when the product is first saved (ELE-0001); empty only before that.
  final String code;
  final String brand;

  /// The maximum retail price printed on the product (GST included); 0 = not entered.
  final int mrpPaise;
  final int pricePaise, costPaise, stockMilli, gstBp, minStockMilli;

  /// The name as it is printed and listed on a bill or estimate: the brand in brackets in front, so the customer sees which make he is buying, e.g. (HAVELLS)SWITCH.
  String get billName => brand.trim().isEmpty ? name : '(${brand.trim()})$name';

  bool get outOfStock => stockMilli <= 0;
  bool get lowStock => stockMilli > 0 && stockMilli <= minStockMilli;

  Product copyWith({String? name, String? category, String? unit, int? pricePaise, int? costPaise, int? stockMilli, int? gstBp, String? barcode, String? hsn, int? minStockMilli, String? code, String? brand, int? mrpPaise}) => Product(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        pricePaise: pricePaise ?? this.pricePaise,
        costPaise: costPaise ?? this.costPaise,
        stockMilli: stockMilli ?? this.stockMilli,
        gstBp: gstBp ?? this.gstBp,
        barcode: barcode ?? this.barcode,
        hsn: hsn ?? this.hsn,
        minStockMilli: minStockMilli ?? this.minStockMilli,
        code: code ?? this.code,
        brand: brand ?? this.brand,
        mrpPaise: mrpPaise ?? this.mrpPaise,
      );
}

class Customer {
  const Customer({required this.id, required this.name, required this.phone, required this.city, required this.balancePaise, this.creditLimitPaise = 5000000, this.address = '', this.gstin = ''});
  final String id, name, phone, city, address;

  /// The customer's GST number: optional, printed on the bill when there is one.
  final String gstin;
  final int balancePaise; // money they owe us
  final int creditLimitPaise;

  Customer copyWith({String? name, String? phone, String? city, String? address, int? creditLimitPaise, String? gstin}) => Customer(id: id, name: name ?? this.name, phone: phone ?? this.phone, city: city ?? this.city, balancePaise: balancePaise, creditLimitPaise: creditLimitPaise ?? this.creditLimitPaise, address: address ?? this.address, gstin: gstin ?? this.gstin);
}

class CartLine {
  const CartLine({required this.product, required this.qtyMilli, this.discountBp = 0, int? ratePaise}) : ratePaise = ratePaise ?? -1;
  final Product product;
  final int qtyMilli;
  final int discountBp; // per-item discount, basis points
  final int ratePaise;
  int get rate => ratePaise >= 0 ? ratePaise : product.pricePaise;
  CartLine copyWith({int? qtyMilli, int? discountBp, int? ratePaise}) =>
      CartLine(product: product, qtyMilli: qtyMilli ?? this.qtyMilli, discountBp: discountBp ?? this.discountBp, ratePaise: ratePaise ?? rate);
}

enum PayMode { cash, upi, card, credit }

enum DocStatus { paid, partly, due, cancelled, pending, delivered, converted, open }

class BillSummary {
  const BillSummary({
    required this.number,
    required this.date,
    required this.customer,
    required this.items,
    required this.totalPaise,
    required this.paidPaise,
    required this.mode,
    required this.status,
  });
  final String number, customer;
  final DateTime date;
  final int items, totalPaise, paidPaise;
  final PayMode mode;
  final DocStatus status;
}

/// A generic row for the simple list screens: an id plus named fields.
class Rec {
  const Rec(this.id, this.f);
  final String id;
  final Map<String, Object> f;
  String s(String k) => '${f[k] ?? ''}';
  int i(String k) => (f[k] as int?) ?? 0;
  Rec with_(Map<String, Object> more) => Rec(id, {...f, ...more});
}

class EstimationDoc {
  const EstimationDoc({required this.number, required this.date, required this.customer, required this.lines, required this.totalPaise, this.editedOn, this.convertedTo, this.extraDiscountPaise = 0, this.extraDiscountBp = 0});
  final String number, customer;
  final DateTime date;
  final DateTime? editedOn;
  final String? convertedTo;
  final int lines, totalPaise;

  /// The whole-estimate discount: the amount, and the percent it was typed as (0 when typed as an amount).
  final int extraDiscountPaise, extraDiscountBp;
}
