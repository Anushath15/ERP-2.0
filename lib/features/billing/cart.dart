import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain_lite/bill_calc.dart';
import '../../fake/models.dart';

enum DocMode { invoice, estimation }

class CartState {
  const CartState({this.lines = const [], this.customer, this.pay = PayMode.cash, this.editingNumber, this.editingDate, this.editedOn, this.paidPaise});
  final List<CartLine> lines;
  final Customer? customer;
  final PayMode pay;
  final String? editingNumber; // when editing a saved estimation: number and date stay the same
  final DateTime? editingDate, editedOn;
  final int? paidPaise;

  CartState copyWith({List<CartLine>? lines, Customer? customer, bool clearCustomer = false, PayMode? pay, String? editingNumber, DateTime? editingDate, DateTime? editedOn}) => CartState(
        lines: lines ?? this.lines,
        customer: clearCustomer ? null : (customer ?? this.customer),
        pay: pay ?? this.pay,
        editingNumber: editingNumber ?? this.editingNumber,
        editingDate: editingDate ?? this.editingDate,
        editedOn: editedOn ?? this.editedOn,
        paidPaise: paidPaise,
      );

  int qtyOf(String productId) {
    for (final l in lines) {
      if (l.product.id == productId) return l.qtyMilli;
    }
    return 0;
  }
}

class CartNotifier extends Notifier<CartState> {
  CartNotifier(this.mode);
  final DocMode mode;

  @override
  CartState build() => const CartState();

  void add(Product p, {int qtyMilli = 1000}) {
    final i = state.lines.indexWhere((l) => l.product.id == p.id);
    if (i >= 0) {
      setQty(i, state.lines[i].qtyMilli + qtyMilli);
    } else {
      state = state.copyWith(lines: [...state.lines, CartLine(product: p, qtyMilli: qtyMilli)]);
    }
  }

  void setQty(int index, int qtyMilli) {
    if (qtyMilli <= 0) return remove(index);
    state = state.copyWith(lines: [for (var i = 0; i < state.lines.length; i++) i == index ? state.lines[i].copyWith(qtyMilli: qtyMilli) : state.lines[i]]);
  }

  void setRate(int index, int ratePaise) => state = state.copyWith(lines: [for (var i = 0; i < state.lines.length; i++) i == index ? state.lines[i].copyWith(ratePaise: ratePaise) : state.lines[i]]);

  void setDiscount(int index, int bp) => state = state.copyWith(lines: [for (var i = 0; i < state.lines.length; i++) i == index ? state.lines[i].copyWith(discountBp: bp.clamp(0, 10000)) : state.lines[i]]);

  void remove(int index) => state = state.copyWith(lines: [for (var i = 0; i < state.lines.length; i++) if (i != index) state.lines[i]]);

  void setCustomer(Customer? c) => state = c == null ? state.copyWith(clearCustomer: true) : state.copyWith(customer: c);

  void setPay(PayMode m) => state = state.copyWith(pay: m);

  void clear() => state = const CartState();

  /// Start editing a saved estimation in place (it keeps its number and its own date).
  void loadForEdit(EstimationDoc e, List<Product> products, List<Customer> customers) {
    final prods = products.take(e.lines.clamp(1, 12)).toList();
    final cust = customers.where((c) => c.name == e.customer).firstOrNull;
    state = CartState(
      lines: [for (var i = 0; i < prods.length; i++) CartLine(product: prods[(i * 7) % prods.length], qtyMilli: 1000 * (1 + i % 4))],
      customer: cust,
      editingNumber: e.number,
      editingDate: e.date,
      editedOn: e.editedOn,
    );
  }
}

final cartProvider = NotifierProvider.family<CartNotifier, CartState, DocMode>(CartNotifier.new);

BillCalc calcFor(CartState s, {required bool inclusive}) => calcBill(s.lines, inclusive: inclusive);

/// Snapshot used by the print preview screens.
class PrintDoc {
  const PrintDoc({required this.mode, required this.number, required this.date, required this.customer, required this.lines, required this.calc, this.editedOn, required this.pay});
  final DocMode mode;
  final String number;
  final DateTime date;
  final DateTime? editedOn;
  final String customer;
  final List<CartLine> lines;
  final BillCalc calc;
  final PayMode pay;
}

class PrintDocNotifier extends Notifier<PrintDoc?> {
  @override
  PrintDoc? build() => null;
  void set(PrintDoc? d) => state = d;
}

final printDocProvider = NotifierProvider<PrintDocNotifier, PrintDoc?>(PrintDocNotifier.new);

class CounterNotifier extends Notifier<int> {
  CounterNotifier(this.start);
  final int start;
  @override
  int build() => start;
  void bump() => state = state + 1;
}

final invoiceCounterProvider = NotifierProvider<CounterNotifier, int>(() => CounterNotifier(20001));
final estimateCounterProvider = NotifierProvider<CounterNotifier, int>(() => CounterNotifier(301));
