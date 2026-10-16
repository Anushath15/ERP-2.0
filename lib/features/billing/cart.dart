import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/ids.dart';
import '../../domain_lite/bill_calc.dart';
import '../../fake/data_providers.dart';
import '../../fake/models.dart';

enum DocMode { invoice, estimation }

class CartState {
  const CartState({this.lines = const [], this.customer, this.pay = PayMode.cash, this.editingNumber, this.editingDate, this.editedOn, this.paidPaise, this.touchedId, this.touchedNew = false, this.touchSeq = 0, this.touchedAtMs = 0, this.receivedPaise, this.keepAdvance = false, this.draftId});
  final List<CartLine> lines;

  /// Made when the first line is added; saving twice with the same id returns the same bill (a double click or a retry after a crash never makes two).
  final String? draftId;
  final Customer? customer;
  final PayMode pay;
  final String? editingNumber; // when editing a saved estimation: number and date stay the same
  final DateTime? editingDate, editedOn;
  final int? paidPaise;

  /// Amount received from the customer. null means "the full Grand Total" (a normal cash sale needs no typing).
  final int? receivedPaise;

  /// For a named customer who paid MORE than the total: keep the extra as an advance instead of giving change.
  final bool keepAdvance;

  /// The line that was just added or changed, used ONLY for the small on-screen animations (slide-in, pulse).
  final String? touchedId;
  final bool touchedNew;
  final int touchSeq, touchedAtMs;

  CartState copyWith({List<CartLine>? lines, Customer? customer, bool clearCustomer = false, PayMode? pay, String? editingNumber, DateTime? editingDate, DateTime? editedOn, ({String id, bool isNew})? touch, int? received, bool clearReceived = false, bool? keepAdvance, String? draftId}) => CartState(
        draftId: draftId ?? this.draftId,
        lines: lines ?? this.lines,
        customer: clearCustomer ? null : (customer ?? this.customer),
        pay: pay ?? this.pay,
        editingNumber: editingNumber ?? this.editingNumber,
        editingDate: editingDate ?? this.editingDate,
        editedOn: editedOn ?? this.editedOn,
        paidPaise: paidPaise,
        receivedPaise: clearReceived ? null : (received ?? receivedPaise),
        keepAdvance: keepAdvance ?? this.keepAdvance,
        touchedId: touch?.id ?? touchedId,
        touchedNew: touch != null ? touch.isNew : touchedNew,
        touchSeq: touch != null ? touchSeq + 1 : touchSeq,
        touchedAtMs: touch != null ? DateTime.now().millisecondsSinceEpoch : touchedAtMs,
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
      state = state.copyWith(lines: [...state.lines, CartLine(product: p, qtyMilli: qtyMilli)], touch: (id: p.id, isNew: true), draftId: state.draftId ?? newId());
    }
  }

  void setQty(int index, int qtyMilli) {
    if (qtyMilli <= 0) return remove(index);
    state = state.copyWith(lines: [for (var i = 0; i < state.lines.length; i++) i == index ? state.lines[i].copyWith(qtyMilli: qtyMilli) : state.lines[i]], touch: (id: state.lines[index].product.id, isNew: false));
  }

  void setRate(int index, int ratePaise) => state = state.copyWith(lines: [for (var i = 0; i < state.lines.length; i++) i == index ? state.lines[i].copyWith(ratePaise: ratePaise) : state.lines[i]]);

  void setDiscount(int index, int bp) => state = state.copyWith(lines: [for (var i = 0; i < state.lines.length; i++) i == index ? state.lines[i].copyWith(discountBp: bp.clamp(0, 10000)) : state.lines[i]]);

  void remove(int index) => state = state.copyWith(lines: [for (var i = 0; i < state.lines.length; i++) if (i != index) state.lines[i]]);

  void setCustomer(Customer? c) => state = c == null ? state.copyWith(clearCustomer: true) : state.copyWith(customer: c);

  /// Credit = "Paid now" mode: entering it starts at nothing paid (unless a part payment is already typed); leaving it by
  /// choosing Cash, UPI or Card with nothing paid means a normal full payment.
  void setPay(PayMode m) {
    if (m == PayMode.credit) {
      state = state.copyWith(pay: m, received: state.receivedPaise ?? 0);
    } else if (state.pay == PayMode.credit && (state.receivedPaise ?? 0) == 0) {
      state = state.copyWith(pay: m, clearReceived: true, keepAdvance: false);
    } else {
      state = state.copyWith(pay: m);
    }
  }

  /// null = the full Grand Total.
  void setReceived(int? paise) => state = paise == null ? state.copyWith(clearReceived: true, keepAdvance: false, pay: state.pay == PayMode.credit ? PayMode.cash : state.pay) : state.copyWith(received: paise);

  void setKeepAdvance(bool v) => state = state.copyWith(keepAdvance: v);

  void clear() => state = const CartState();

  /// Start editing a saved estimation in place (it keeps its number and its own date). Reads its lines from the database.
  Future<void> loadForEdit(EstimationDoc e, List<Product> products, List<Customer> customers) async {
    final d = ref.read(appDataProvider);
    final lines = await d.estimations.lines(e.number);
    final byId = {for (final p in products) p.id: p};
    final custId = await d.estimations.customerIdOf(e.number);
    final cust = customers.where((c) => c.id == custId).firstOrNull ?? customers.where((c) => c.name == e.customer).firstOrNull;
    state = CartState(
      lines: [
        for (final l in lines)
          CartLine(
            product: byId[l.productId] ?? Product(id: l.productId, name: l.name, category: '', unit: l.unit, pricePaise: l.ratePaise, costPaise: 0, stockMilli: 0, gstBp: 1800, barcode: ''),
            qtyMilli: l.qtyMilli,
            discountBp: l.discountBp,
            ratePaise: l.ratePaise,
          ),
      ],
      customer: cust,
      editingNumber: e.number,
      editingDate: e.date,
      editedOn: e.editedOn,
      draftId: newId(),
    );
  }
}

final cartProvider = NotifierProvider.family<CartNotifier, CartState, DocMode>(CartNotifier.new);

BillCalc calcFor(CartState s, {required bool inclusive, bool roundOff = true}) => calcBill(s.lines, inclusive: inclusive, roundOff: roundOff);

/// Snapshot used by the print preview screens.
class PrintDoc {
  const PrintDoc({required this.mode, required this.number, required this.date, required this.customer, required this.lines, required this.calc, this.editedOn, required this.pay, this.receivedPaise, this.changePaise = 0, this.advanceKeptPaise = 0, this.newBalancePaise});
  final DocMode mode;
  final String number;
  final DateTime date;
  final DateTime? editedOn;
  final String customer;
  final List<CartLine> lines;
  final BillCalc calc;
  final PayMode pay;

  /// Money received at the counter (null = not shown, e.g. an estimate or an old bill without the detail).
  final int? receivedPaise;
  final int changePaise, advanceKeptPaise;

  /// What the named customer owes after this bill is saved (null = walk-in or not shown).
  final int? newBalancePaise;

  /// The unpaid part, added to the customer's credit (0 when paid in full).
  int get balancePaise => receivedPaise == null ? 0 : (calc.grandTotal - receivedPaise! > 0 ? calc.grandTotal - receivedPaise! : 0);
}

class PrintDocNotifier extends Notifier<PrintDoc?> {
  @override
  PrintDoc? build() => null;
  void set(PrintDoc? d) => state = d;
}

final printDocProvider = NotifierProvider<PrintDocNotifier, PrintDoc?>(PrintDocNotifier.new);
