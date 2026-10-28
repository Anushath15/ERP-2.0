import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/os.dart';
import '../../data/ids.dart';
import '../../domain_lite/bill_calc.dart';
import '../../fake/data_providers.dart';
import '../../fake/models.dart';
import '../../fake/store.dart' show customersProvider, productsProvider;

enum DocMode { invoice, estimation }

/// The key that says two products are "the same thing in another brand": the name with spaces and capitals ignored.
String variantKey(Product p) => p.name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Products grouped by [variantKey], only the groups with more than one brand (those are the ones where a line can be switched).
final productVariantsProvider = Provider<Map<String, List<Product>>>((ref) {
  final groups = <String, List<Product>>{};
  for (final p in ref.watch(productsProvider)) {
    groups.putIfAbsent(variantKey(p), () => []).add(p);
  }
  groups.removeWhere((_, v) => v.length < 2);
  return groups;
});

class CartState {
  const CartState({this.lines = const [], this.customer, this.pay = PayMode.cash, this.editingNumber, this.editingDate, this.editedOn, this.paidPaise, this.touchedId, this.touchedNew = false, this.touchSeq = 0, this.touchedAtMs = 0, this.receivedPaise, this.keepAdvance = false, this.draftId, this.extraDiscountPaise = 0, this.extraDiscountBp = 0});
  final List<CartLine> lines;

  /// A discount on the whole bill or estimate: an amount in paise, or (when [extraDiscountBp] is above zero) a percent in basis points.
  final int extraDiscountPaise, extraDiscountBp;

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

  CartState copyWith({List<CartLine>? lines, Customer? customer, bool clearCustomer = false, PayMode? pay, String? editingNumber, DateTime? editingDate, DateTime? editedOn, ({String id, bool isNew})? touch, int? received, bool clearReceived = false, bool? keepAdvance, String? draftId, ({int paise, int bp})? extraDiscount}) => CartState(
        extraDiscountPaise: extraDiscount?.paise ?? extraDiscountPaise,
        extraDiscountBp: extraDiscount?.bp ?? extraDiscountBp,
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

/// An unfinished bill or estimate is saved on this phone after every change and brought back when the Bill page opens again, so leaving the
/// program (or Android closing it) never loses a half-made bill. Switched on only on an Android phone: on a computer nothing changes.
final cartDraftEnabledProvider = Provider<bool>((ref) => onAndroid);

/// A saved draft older than this is ignored (its prices are stale).
const cartDraftMaxAge = Duration(days: 3);

/// The draft as text; '' for an empty cart.
String encodeCartDraft(CartState s, {int? nowMs}) {
  if (s.lines.isEmpty) return '';
  return jsonEncode({
    'v': 1,
    't': nowMs ?? DateTime.now().millisecondsSinceEpoch,
    'id': s.draftId,
    'lines': [for (final l in s.lines) {'p': l.product.id, 'q': l.qtyMilli, 'd': l.discountBp, 'r': l.ratePaise}],
    'c': s.customer?.id,
    'pay': s.pay.name,
    'recv': s.receivedPaise,
    'adv': s.keepAdvance,
    'xp': s.extraDiscountPaise,
    'xb': s.extraDiscountBp,
  });
}

/// The cart a draft describes, or null when it is empty, too old, unreadable, or none of its products exist any more.
CartState? decodeCartDraft(String raw, List<Product> products, List<Customer> customers, {int? nowMs}) {
  try {
    if (raw.isEmpty) return null;
    final m = jsonDecode(raw);
    if (m is! Map || m['v'] != 1) return null;
    final t = (m['t'] as num?)?.toInt() ?? 0;
    if ((nowMs ?? DateTime.now().millisecondsSinceEpoch) - t > cartDraftMaxAge.inMilliseconds) return null;
    final byId = {for (final p in products) p.id: p};
    final lines = <CartLine>[];
    for (final e in (m['lines'] as List)) {
      final p = byId[e['p']];
      if (p == null) continue;
      final r = (e['r'] as num?)?.toInt() ?? -1;
      lines.add(CartLine(product: p, qtyMilli: (e['q'] as num).toInt(), discountBp: (e['d'] as num?)?.toInt() ?? 0, ratePaise: r >= 0 ? r : null));
    }
    if (lines.isEmpty) return null;
    final cid = m['c'];
    final pay = PayMode.values.where((x) => x.name == m['pay']).firstOrNull ?? PayMode.cash;
    return CartState(
      lines: lines,
      customer: cid == null ? null : customers.where((c) => c.id == cid).firstOrNull,
      pay: pay,
      receivedPaise: (m['recv'] as num?)?.toInt(),
      keepAdvance: m['adv'] == true,
      extraDiscountPaise: (m['xp'] as num?)?.toInt() ?? 0,
      extraDiscountBp: (m['xb'] as num?)?.toInt() ?? 0,
      draftId: (m['id'] as String?) ?? newId(),
    );
  } catch (_) {
    return null;
  }
}

class CartNotifier extends Notifier<CartState> {
  CartNotifier(this.mode);
  final DocMode mode;
  String? _savedDraft;

  @override
  CartState build() {
    listenSelf((prev, next) {
      // an empty cart after an empty cart has nothing to save, and must never wipe the draft the last session left behind
      if (next.lines.isEmpty && (prev == null || prev.lines.isEmpty)) return;
      _saveDraft(next);
    });
    return const CartState();
  }

  String get _draftKey => mode == DocMode.invoice ? 'draft.bill' : 'draft.estimate';

  /// Local to this phone (never uploaded). An estimate being edited is already saved, so it has no draft.
  void _saveDraft(CartState s) {
    if (!ref.read(cartDraftEnabledProvider) || s.editingNumber != null) return;
    final text = encodeCartDraft(s);
    final same = jsonDecode(text.isEmpty ? '{}' : text);
    if (_savedDraft != null && _sameDraft(_savedDraft!, text, same)) return;
    _savedDraft = text;
    try {
      unawaited(ref.read(appDataProvider).settings.put(_draftKey, text).catchError((Object _) {}));
    } catch (_) {
      // the draft is a convenience; billing never waits for it
    }
  }

  /// Two drafts are the same when only their time stamp differs.
  bool _sameDraft(String oldText, String newText, Object? newJson) {
    if (oldText == newText) return true;
    if (oldText.isEmpty || newText.isEmpty) return false;
    final a = Map<String, dynamic>.of(jsonDecode(oldText) as Map<String, dynamic>)..remove('t');
    final b = Map<String, dynamic>.of(newJson! as Map<String, dynamic>)..remove('t');
    return jsonEncode(a) == jsonEncode(b);
  }

  /// Brings back the saved draft when the cart is empty. True when something was restored.
  Future<bool> restoreDraft() async {
    if (!ref.read(cartDraftEnabledProvider) || state.lines.isNotEmpty || state.editingNumber != null) return false;
    final products = ref.read(productsProvider);
    if (products.isEmpty) return false;
    final raw = await ref.read(appDataProvider).settings.get(_draftKey);
    if (raw == null || raw.isEmpty) return false;
    final restored = decodeCartDraft(raw, products, ref.read(customersProvider));
    if (restored == null || state.lines.isNotEmpty) return false; // nothing usable, or the cart was filled meanwhile
    state = restored;
    return true;
  }

  void add(Product p, {int qtyMilli = 1000}) {
    final i = state.lines.indexWhere((l) => l.product.id == p.id);
    if (i >= 0) {
      setQty(i, state.lines[i].qtyMilli + qtyMilli);
    } else {
      state = state.copyWith(lines: [...state.lines, CartLine(product: p, qtyMilli: qtyMilli)], touch: (id: p.id, isNew: true), draftId: state.draftId ?? newId());
    }
  }

  /// The customer wants another brand of the same product: this line becomes that brand's product, with that brand's rate, keeping the
  /// quantity and the discount. When the other brand is already on the bill the two lines are joined.
  void swapProduct(int index, Product other) {
    if (index < 0 || index >= state.lines.length || state.lines[index].product.id == other.id) return;
    final old = state.lines[index];
    final j = state.lines.indexWhere((l) => l.product.id == other.id);
    if (j >= 0) {
      state = state.copyWith(lines: [
        for (var i = 0; i < state.lines.length; i++)
          if (i == j) state.lines[i].copyWith(qtyMilli: state.lines[i].qtyMilli + old.qtyMilli) else if (i != index) state.lines[i]
      ], touch: (id: other.id, isNew: false));
      return;
    }
    state = state.copyWith(lines: [for (var i = 0; i < state.lines.length; i++) i == index ? CartLine(product: other, qtyMilli: old.qtyMilli, discountBp: old.discountBp) : state.lines[i]], touch: (id: other.id, isNew: false));
  }

  void setQty(int index, int qtyMilli) {
    if (qtyMilli <= 0) return remove(index);
    state = state.copyWith(lines: [for (var i = 0; i < state.lines.length; i++) i == index ? state.lines[i].copyWith(qtyMilli: qtyMilli) : state.lines[i]], touch: (id: state.lines[index].product.id, isNew: false));
  }

  void setRate(int index, int ratePaise) => state = state.copyWith(lines: [for (var i = 0; i < state.lines.length; i++) i == index ? state.lines[i].copyWith(ratePaise: ratePaise) : state.lines[i]]);

  void setDiscount(int index, int bp) => state = state.copyWith(lines: [for (var i = 0; i < state.lines.length; i++) i == index ? state.lines[i].copyWith(discountBp: bp.clamp(0, 10000)) : state.lines[i]]);

  /// A discount on the whole bill typed as an amount (rupees in paise). Zero removes it.
  void setExtraDiscountAmount(int paise) => state = state.copyWith(extraDiscount: (paise: paise < 0 ? 0 : paise, bp: 0));

  /// A discount on the whole bill typed as a percent (in basis points: 5% = 500). Zero removes it.
  void setExtraDiscountPercent(int bp) => state = state.copyWith(extraDiscount: (paise: 0, bp: bp.clamp(0, 10000)));

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

  /// The product's prices were changed (from the Change price box): the lines of that product take the new product, so the profit follows.
  void refreshProduct(Product p) {
    if (!state.lines.any((l) => l.product.id == p.id)) return;
    state = state.copyWith(lines: [for (final l in state.lines) l.product.id == p.id ? CartLine(product: p, qtyMilli: l.qtyMilli, discountBp: l.discountBp, ratePaise: l.ratePaise < 0 ? null : l.ratePaise) : l]);
  }

  void clear() => state = const CartState();

  /// "Bill again": a new bill with the items and quantities of an old one, for the same customer. Each item takes today's selling price from the
  /// product list (prices may have changed since); an item no longer in the list keeps the old bill's rate.
  void loadCopy(List<CartLine> old, Customer? customer, List<Product> products) {
    final byId = {for (final p in products) p.id: p};
    state = CartState(
      lines: [
        for (final l in old)
          byId[l.product.id] == null ? CartLine(product: l.product, qtyMilli: l.qtyMilli, discountBp: l.discountBp, ratePaise: l.rate) : CartLine(product: byId[l.product.id]!, qtyMilli: l.qtyMilli, discountBp: l.discountBp),
      ],
      customer: customer,
      draftId: newId(),
    );
  }

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
      extraDiscountPaise: e.extraDiscountBp > 0 ? 0 : e.extraDiscountPaise,
      extraDiscountBp: e.extraDiscountBp,
      editingNumber: e.number,
      editingDate: e.date,
      editedOn: e.editedOn,
      draftId: newId(),
    );
  }
}

final cartProvider = NotifierProvider.family<CartNotifier, CartState, DocMode>(CartNotifier.new);

BillCalc calcFor(CartState s, {required bool inclusive, bool roundOff = true}) =>
    calcBill(s.lines, inclusive: inclusive, roundOff: roundOff, extraDiscountPaise: s.extraDiscountPaise, extraDiscountBp: s.extraDiscountBp);

/// Snapshot used by the print preview screens.
class PrintDoc {
  const PrintDoc({required this.mode, required this.number, required this.date, required this.customer, required this.lines, required this.calc, this.editedOn, required this.pay, this.receivedPaise, this.changePaise = 0, this.advanceKeptPaise = 0, this.newBalancePaise, this.backTo, this.extraDiscountBp = 0, this.customerPhone = '', this.customerGstin = ''});
  final DocMode mode;

  /// The customer's phone and GST number, printed under the name (empty for a walk-in or when not saved).
  final String customerPhone, customerGstin;

  /// Where the Back button of the print page goes (a route); null = the page the person came from.
  final String? backTo;

  /// The percent the whole-bill discount was typed as (basis points), 0 when it was typed as an amount.
  final int extraDiscountBp;
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
