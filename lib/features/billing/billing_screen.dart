import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../core/sound.dart';
import '../../domain/credit/payment_split.dart';
import '../../domain/credit/reminder.dart' show normalizePhone;
import '../../design/motion.dart';
import '../../fake/credit_store.dart';
import '../../design/effects.dart';
import '../../design/form_sheet.dart';
import '../../design/segments.dart';
import '../../design/text_zoom.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/models.dart';
import '../../fake/store.dart';
import '../products/product_form.dart';
import 'bill_panel.dart';
import 'cart.dart';
import 'customer_picker.dart';
import 'product_picker.dart';

/// POS billing, also used for estimations (mode = estimation).
/// Layout rule: the product table and the bill lines scroll INSIDE themselves. The footer (grand total, payment mode,
/// Save, Save and Print) is pinned and never moves, however many lines the bill has.
class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key, required this.mode});
  final DocMode mode;
  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  int _phoneTab = 0; // 0 = products, 1 = bill

  DocMode get mode => widget.mode;

  void _addProduct(Product p) {
    final cart = ref.read(cartProvider(mode));
    final already = cart.qtyOf(p.id);
    ref.read(cartProvider(mode).notifier).add(p);
    final l = tr(context);
    if (mode == DocMode.invoice && already + 1000 > p.stockMilli) {
      // Warning only. Selling at stock 0 is allowed.
      toast(context, p.stockMilli <= 0 ? l.warnNoStockToast(p.name) : l.warnLowStockToast(p.name, formatQty(p.stockMilli)));
    }
  }

  Future<void> _quickAdd(String text) async {
    final l = tr(context);
    final res = await showProductForm(context, initialName: text, saveLabel: l.saveAndAddToBill);
    if (res == null) return;
    ref.read(productsProvider.notifier).add(res);
    ref.read(cartProvider(mode).notifier).add(res);
    if (mounted) toast(context, l.productAdded(res.name));
  }

  Future<void> _pickCustomer() async {
    final c = await showCustomerPicker(context);
    if (c != null) ref.read(cartProvider(mode).notifier).setCustomer(c.id == '__walkin' ? null : c);
  }

  String _number() {
    final cart = ref.read(cartProvider(mode));
    if (cart.editingNumber != null) return cart.editingNumber!;
    return mode == DocMode.invoice ? 'A-${ref.read(invoiceCounterProvider).toString().padLeft(6, '0')}' : 'EST-${ref.read(estimateCounterProvider).toString().padLeft(5, '0')}';
  }

  DateTime _date() => ref.read(cartProvider(mode)).editingDate ?? ref.read(clockProvider);

  PrintDoc _snapshot() {
    final cart = ref.read(cartProvider(mode));
    final s = ref.read(settingsProvider);
    final calc = calcFor(cart, inclusive: s.pricesIncludeGst);
    int? received;
    var change = 0, advance = 0;
    if (mode == DocMode.invoice) {
      final split = splitPayment(total: calc.grandTotal, received: cart.receivedPaise ?? calc.grandTotal);
      received = split.received;
      change = split.change;
      advance = cart.customer != null && cart.keepAdvance ? split.change : 0;
      if (advance > 0) change = 0; // kept on account instead of given back
    }
    return PrintDoc(mode: mode, number: _number(), date: _date(), editedOn: cart.editingNumber != null ? ref.read(clockProvider) : null, customer: cart.customer?.name ?? tr(context).walkInCustomer, lines: cart.lines, calc: calc, pay: cart.pay, receivedPaise: received, changePaise: change, advanceKeptPaise: advance, newBalancePaise: mode == DocMode.invoice && cart.customer != null ? ref.read(creditProvider.notifier).balanceOf(cart.customer!.id) + (calc.grandTotal - (received ?? calc.grandTotal) > 0 ? calc.grandTotal - (received ?? calc.grandTotal) : 0) - advance : null);
  }

  /// A bill with an unpaid balance needs a named customer: pick one or add one. Returns null if the person gives up
  /// (the bill is then NOT saved).
  Future<Customer?> _askCustomer(int balance) async {
    final l = tr(context);
    final choice = await showDialog<String>(
      context: context,
      animationStyle: dialogStyle(context),
      builder: (ctx) => AlertDialog(
        title: Text(l.needCustomerTitle),
        content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Text(l.needCustomerText(formatPaise(balance, symbol: true)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: Text(l.cancel)),
          OutlinedButton.icon(onPressed: () => Navigator.pop(ctx, 'new'), icon: const Icon(Icons.person_add_alt), label: Text(l.addNewCustomer)),
          FilledButton.icon(key: const ValueKey('pickCustomerForCredit'), onPressed: () => Navigator.pop(ctx, 'pick'), icon: const Icon(Icons.person_search_outlined), label: Text(l.chooseCustomer)),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'cancel') return null;
    if (choice == 'pick') {
      final c = await showCustomerPicker(context);
      return c == null || c.id == '__walkin' ? null : c;
    }
    final v = await showQuickCustomer(context);
    if (v == null) return null;
    final c = Customer(id: 'c-new-${ref.read(customersProvider).length + 1}', name: v['name']!, phone: v['phone'] ?? '', city: v['city'] ?? '', balancePaise: 0);
    ref.read(customersProvider.notifier).add(c);
    return c;
  }

  /// Returns false when the credit limit stops this bill (or the owner says no).
  Future<bool> _checkLimit(Customer customer, int balance) async {
    final l = tr(context);
    final st = ref.read(settingsProvider);
    if (st.creditLimitMode == CreditLimitMode.off) return true;
    final owes = ref.read(creditProvider.notifier).balanceOf(customer.id);
    final after = owes + balance;
    final limit = customer.creditLimitPaise;
    if (after <= limit) return true;
    String m(int p) => formatPaise(p, symbol: true);
    if (st.creditLimitMode == CreditLimitMode.block) {
      await showDialog<void>(context: context, animationStyle: dialogStyle(context), builder: (ctx) => AlertDialog(title: Text(l.creditLimitBlockTitle), content: Text(l.creditLimitBlockText(customer.name, m(limit))), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close))]));
      return false;
    }
    return confirmDialog(context, title: l.creditLimitWarnTitle, message: l.creditLimitWarnText(customer.name, m(owes < 0 ? 0 : owes), m(after), m(limit)), confirmLabel: l.saveAnyway);
  }

  Future<void> _save({bool print = false}) async {
    final l = tr(context);
    var cart = ref.read(cartProvider(mode));
    if (cart.lines.isEmpty) return;
    if (mode == DocMode.invoice) {
      // Everything below only waits (await) when a question has to be asked; a normal fully-paid sale saves in the same frame.
      final total = calcFor(cart, inclusive: ref.read(settingsProvider).pricesIncludeGst).grandTotal;
      final split = splitPayment(total: total, received: cart.receivedPaise ?? total);
      if (split.balance > 0 && cart.customer == null) {
        final chosen = await _askCustomer(split.balance);
        if (chosen == null || !mounted) return; // not resolved: do not save
        ref.read(cartProvider(mode).notifier).setCustomer(chosen);
        cart = ref.read(cartProvider(mode));
      }
      if (split.balance > 0 && cart.customer != null && !await _checkLimit(cart.customer!, split.balance)) return;
      if (!mounted) return;
    }
    final doc = _snapshot();
    final editing = ref.read(cartProvider(mode)).editingNumber != null;
    if (!editing) {
      mode == DocMode.invoice ? ref.read(invoiceCounterProvider.notifier).bump() : ref.read(estimateCounterProvider.notifier).bump();
    }
    if (mode == DocMode.invoice) {
      final c = ref.read(cartProvider(mode)).customer;
      if (c != null) ref.read(creditProvider.notifier).addBill(customerId: c.id, billNo: doc.number, at: doc.date, total: doc.calc.grandTotal, received: doc.receivedPaise ?? doc.calc.grandTotal, advance: doc.advanceKeptPaise);
    }
    if (mode == DocMode.estimation) {
      final e = EstimationDoc(number: doc.number, date: doc.date, customer: doc.customer, lines: doc.lines.length, totalPaise: doc.calc.grandTotal, editedOn: editing ? doc.editedOn : null);
      final n = ref.read(estimationsProvider.notifier);
      editing ? n.replace(e) : n.add(e);
    }
    ref.read(cartProvider(mode).notifier).clear();
    String m(int p) => formatPaise(p, symbol: true);
    toast(context, mode != DocMode.invoice ? l.estimateSaved(doc.number) : (doc.balancePaise > 0 && doc.newBalancePaise != null ? l.billSavedCredit(doc.number, m(doc.receivedPaise! > doc.calc.grandTotal ? doc.calc.grandTotal : doc.receivedPaise!), m(doc.balancePaise), doc.customer, m(doc.newBalancePaise!)) : l.billSaved(doc.number)));
    playSound(ref, SoundKind.save);
    showSuccessCheck(context);
    if (print) {
      ref.read(printDocProvider.notifier).set(doc);
      unawaited(context.push('/print'));
    }
    setState(() => _phoneTab = 0);
  }

  Future<void> _clear() async {
    final l = tr(context);
    final ok = await confirmDialog(context, title: l.clearBillTitle, message: l.clearBillText, confirmLabel: l.clearBill, danger: true);
    if (ok) ref.read(cartProvider(mode).notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final cart = ref.watch(cartProvider(mode));
    final products = ref.watch(productsProvider);
    final settings = ref.watch(settingsProvider);
    final calc = calcFor(cart, inclusive: settings.pricesIncludeGst);
    final inBill = {for (final ln in cart.lines) ln.product.id: ln.qtyMilli};
    final notifier = ref.read(cartProvider(mode).notifier);
    final phone = context.isPhone;
    final number = _number();
    final date = _date();

    final picker = TextScaleBy(factor: settings.billingScale, child: ProductPicker(products: products, inBill: inBill, onAdd: _addProduct, onQuickAdd: _quickAdd, onScan: () => playSound(ref, SoundKind.scan)));

    Widget lines() => TextScaleBy(factor: settings.billingScale, child: BillLines(mode: mode, cart: cart, calc: calc, onQty: notifier.setQty, onRemove: notifier.remove, onRate: notifier.setRate, onDiscount: notifier.setDiscount));
    final footer = BillFooter(mode: mode, cart: cart, calc: calc, onPay: notifier.setPay, onReceived: notifier.setReceived, onKeepAdvance: notifier.setKeepAdvance, customerName: cart.customer?.name, customerBalance: cart.customer == null ? null : ref.watch(creditProvider)[cart.customer!.id]?.balance ?? 0, onSave: _save, onSavePrint: () => _save(print: true), onClear: _clear);

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
        if (cart.lines.isNotEmpty) _save();
      },
      // preview only: fills the bill with 100 sample lines so the owner can check that the pinned footer stays put
      const SingleActivator(LogicalKeyboardKey.keyL, control: true, shift: true): () {
        for (var i = 0; i < 100 && i * 3 < products.length; i++) {
          notifier.add(products[i * 3]);
        }
      },
      const SingleActivator(LogicalKeyboardKey.f9): () {
        if (cart.lines.isNotEmpty) _save(print: true);
      },
    };

    Widget body;
    if (phone) {
      body = Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: SlideSegments<int>(
            options: [(0, l.tabProducts, Icons.inventory_2_outlined), (1, l.tabBill(cart.lines.length.toString()), Icons.receipt_long_outlined)],
            selected: _phoneTab,
            onChanged: (v) => setState(() => _phoneTab = v),
          ),
        ),
        Expanded(
          child: _phoneTab == 0
              ? Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 8), child: picker)
              : Column(children: [
                  Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 6), child: BillHeader(mode: mode, cart: cart, number: number, date: date, onPickCustomer: _pickCustomer, balance: cart.customer == null ? 0 : (ref.watch(creditProvider)[cart.customer!.id]?.balance ?? 0))),
                  Expanded(child: lines()),
                ]),
        ),
        footer,
      ]);
    } else {
      final left = Padding(padding: const EdgeInsets.fromLTRB(16, 14, 8, 14), child: picker);
      final right = Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: context.c.border.withValues(alpha: 0.6)))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), child: BillHeader(mode: mode, cart: cart, number: number, date: date, onPickCustomer: _pickCustomer, balance: cart.customer == null ? 0 : (ref.watch(creditProvider)[cart.customer!.id]?.balance ?? 0))),
          Divider(height: 1, color: context.c.border.withValues(alpha: 0.6)),
          Expanded(child: lines()),
          footer,
        ]),
      );
      final wide = context.isDesktop;
      body = Row(children: [
        Expanded(flex: wide ? 11 : 10, child: left),
        Expanded(flex: wide ? 10 : 11, child: right),
      ]);
    }

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: false,
        child: Semantics(label: mode == DocMode.invoice ? l.navNewBill : l.navNewEstimate, child: body),
      ),
    );
  }
}

/// Customer list in a sheet/dialog with search over thousands of customers (virtualised).
Future<Customer?> showCustomerPicker(BuildContext context) => showCustomerPickerImpl(context);

Future<Map<String, String>?> showQuickCustomer(BuildContext context) {
  final l = tr(context);
  return showFormSheet(context, title: l.addCustomer, saveLabel: l.save, fields: [
    FieldSpec('name', l.fieldName, required: true, autofocus: true),
    FieldSpec('phone', l.fieldPhone, type: FieldType.phone, hint: '98765 43210', check: (v) => normalizePhone(v) == null ? l.errPhone : null),
    FieldSpec('city', l.fieldCity),
  ]);
}
