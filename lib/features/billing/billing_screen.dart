import 'dart:async';
import '../../core/validators.dart';
import 'package:flutter/material.dart';
import '../../design/qr_view.dart';
import '../../domain/upi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/money.dart';
import '../../core/plain_error.dart';
import '../../data/ids.dart';
import '../../data/repo/bill_repo.dart';
import '../../data/repo/records_repo.dart' show EstimateLine;
import '../../domain_lite/bill_calc.dart';
import '../../fake/actions.dart';
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
import '../../core/data_mode.dart';
import '../../design/widgets.dart';
import '../../fake/data_providers.dart' show appModeProvider;
import '../../fake/models.dart';
import '../../fake/store.dart';
import '../../fake/shop_profile.dart';
import '../products/product_form.dart';
import 'bill_panel.dart';
import 'discount_profit_bar.dart';
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

  /// The customer asked for a GST bill: type their GST number here, it is saved on the customer (so next time it is already there)
  /// and printed on this tax invoice.
  Future<void> _editGst() async {
    final cust = ref.read(cartProvider(mode)).customer;
    if (cust == null) return;
    final l = tr(context);
    final v = await showFormSheet(context, title: l.gstEditTitle, saveLabel: l.save, note: l.gstEditNote, fields: [
      FieldSpec('gstin', 'GSTIN', initial: cust.gstin, kind: TextKind.gstin, autofocus: true),
    ]);
    if (v == null || !mounted) return;
    final updated = cust.copyWith(gstin: v['gstin'] ?? '');
    ref.read(customersProvider.notifier).update(updated);
    ref.read(cartProvider(mode).notifier).setCustomer(updated);
  }

  /// The UPI QR code for what the customer is paying now (the amount typed in "Amount received", or the whole total), full size,
  /// so the customer can scan it at the counter. The amount is already inside the code.
  Future<void> _showUpiQr(BillCalc calc) async {
    final l = tr(context);
    final shop = ref.read(shopProvider);
    final received = ref.read(cartProvider(mode)).receivedPaise;
    final pay = received == null || received > calc.grandTotal ? calc.grandTotal : received;
    final uri = upiPayUri(upiId: shop.upiId, payeeName: shop.name, amountPaise: pay, note: _number());
    if (uri == null) {
      toast(context, l.upiNoId);
      return;
    }
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(l.upiQrTitle, textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          QrView(key: const ValueKey('upiQrBig'), data: uri, size: 260),
          const SizedBox(height: 10),
          Text('₹ ${formatPaise(pay)}', key: const ValueKey('upiQrAmount'), style: Theme.of(ctx).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(l.upiQrHelp, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodySmall),
          if (ref.read(appModeProvider) == DataMode.demo) Padding(padding: const EdgeInsets.only(top: 10), child: StatusBadge(l.upiDemoWarn, key: const ValueKey('upiDemoWarn'), kind: BadgeKind.warning, icon: Icons.warning_amber_rounded)),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(), child: Text(l.close))],
      ),
    );
  }

  String _number() {
    final cart = ref.read(cartProvider(mode));
    if (cart.editingNumber != null) return cart.editingNumber!;
    final n = ref.watch(nextNumbersProvider);
    return mode == DocMode.invoice ? n.invoice : n.estimate;
  }

  DateTime _date() => ref.read(cartProvider(mode)).editingDate ?? ref.read(clockProvider);

  /// What is printed for a document: from the SAVED bill (its real number and amounts), or for an estimate from the cart.
  PrintDoc _docFrom(CartState cart, BillCalc calc, {required String number, required DateTime date, int? received, int change = 0, int advance = 0, int? newBalance, DateTime? editedOn}) =>
      PrintDoc(extraDiscountBp: cart.extraDiscountBp, mode: mode, number: number, date: date, editedOn: editedOn, customer: cart.customer?.name ?? tr(context).walkInCustomer, customerPhone: cart.customer?.phone ?? '', customerGstin: cart.customer?.gstin ?? '', lines: cart.lines, calc: calc, pay: cart.pay, receivedPaise: received, changePaise: change, advanceKeptPaise: advance, newBalancePaise: newBalance);

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
          OutlinedButton.icon(onPressed: () => Navigator.pop(ctx, 'new'), icon: const Icon(Icons.person_add_alt_rounded), label: Text(l.addNewCustomer)),
          FilledButton.icon(key: const ValueKey('pickCustomerForCredit'), onPressed: () => Navigator.pop(ctx, 'pick'), icon: const Icon(Icons.person_search_rounded), label: Text(l.chooseCustomer)),
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
    final c = Customer(id: newId(), name: v['name']!, phone: v['phone'] ?? '', city: v['city'] ?? '', gstin: v['gstin'] ?? '', balancePaise: 0);
    ref.read(customersProvider.notifier).add(c);
    return c;
  }

  /// Returns false when the credit limit stops this bill (or the owner says no).
  Future<bool> _checkLimit(Customer customer, int balance) async {
    final l = tr(context);
    final st = ref.read(shopProvider);
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

  bool _saving = false;

  Future<void> _save({bool print = false}) async {
    if (_saving) return; // a second press while the first is being written changes nothing
    _saving = true;
    try {
      await _doSave(print: print);
    } finally {
      _saving = false;
    }
  }

  Future<void> _doSave({required bool print}) async {
    final l = tr(context);
    var cart = ref.read(cartProvider(mode));
    if (cart.lines.isEmpty) return;
    final shop = ref.read(shopProvider);
    if (mode == DocMode.invoice) {
      // Everything below only waits (await) when a question has to be asked; a normal fully-paid sale saves at once.
      final total = calcFor(cart, inclusive: shop.pricesIncludeGst, roundOff: shop.roundOff).grandTotal;
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
    cart = ref.read(cartProvider(mode));
    final calc = calcFor(cart, inclusive: shop.pricesIncludeGst, roundOff: shop.roundOff);
    final editing = cart.editingNumber != null;
    final at = _date();
    PrintDoc doc;
    try {
      if (mode == DocMode.invoice) {
        final input = SaveBillInput(
          idemKey: cart.draftId ?? newId(),
          at: at,
          lines: [for (final ln in cart.lines) BillLineInput(productId: ln.product.id, name: ln.product.billName, unit: ln.product.unit, qtyMilli: ln.qtyMilli, ratePaise: ln.rate, gstBp: ln.product.gstBp, discountBp: ln.discountBp, costPaise: ln.product.costPaise)],
          customerId: cart.customer?.id,
          customerName: cart.customer?.name ?? '',
          payMode: cart.pay.index,
          receivedPaise: cart.receivedPaise,
          keepAdvance: cart.keepAdvance,
          pricesIncludeGst: shop.pricesIncludeGst,
          roundOff: shop.roundOff,
          extraDiscountPaise: cart.extraDiscountPaise,
          extraDiscountBp: cart.extraDiscountBp,
        );
        final saved = await ref.read(billActionsProvider).save(input);
        final balanceNow = cart.customer == null ? null : ref.read(creditProvider.notifier).balanceOf(cart.customer!.id);
        doc = _docFrom(cart, calc, number: saved.number, date: saved.at, received: saved.receivedPaise, change: saved.changePaise, advance: saved.advanceKeptPaise, newBalance: balanceNow);
      } else {
        final e = await ref.read(estimationsProvider.notifier).save(
              lines: [for (final ln in cart.lines) EstimateLine(productId: ln.product.id, name: ln.product.billName, unit: ln.product.unit, qtyMilli: ln.qtyMilli, ratePaise: ln.rate, discountBp: ln.discountBp)],
              totalPaise: calc.grandTotal,
              customerName: cart.customer?.name ?? '',
              customerId: cart.customer?.id,
              at: editing ? cart.editingDate! : at,
              editNumber: cart.editingNumber,
              extraDiscountPaise: cart.extraDiscountPaise,
              extraDiscountBp: cart.extraDiscountBp,
            );
        doc = _docFrom(cart, calc, number: e.number, date: e.date, editedOn: editing ? ref.read(clockProvider) : null);
      }
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: Text(l.saveFailedTitle), content: Text(l.saveFailedText(plainError(e))), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close))]));
      return; // nothing was saved: the bill stays on the screen so nothing has to be typed again
    }
    if (!mounted) return;
    ref.read(cartProvider(mode).notifier).clear();
    String m(int p) => formatPaise(p, symbol: true);
    toast(context, mode != DocMode.invoice ? l.estimateSaved(doc.number) : (doc.balancePaise > 0 && doc.newBalancePaise != null ? l.billSavedCredit(doc.number, m(doc.receivedPaise! > doc.calc.grandTotal ? doc.calc.grandTotal : doc.receivedPaise!), m(doc.balancePaise), doc.customer, m(doc.newBalancePaise!)) : l.billSaved(doc.number)));
    playSound(ref, SoundKind.save);
    showSuccessCheck(context);
    if (print) {
      ref.read(printDocProvider.notifier).set(doc);
      ref.read(autoPrintProvider.notifier).set(true);
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
    final shopNow = ref.watch(shopProvider);
    final calc = calcFor(cart, inclusive: shopNow.pricesIncludeGst, roundOff: shopNow.roundOff);
    final inBill = {for (final ln in cart.lines) ln.product.id: ln.qtyMilli};
    final notifier = ref.read(cartProvider(mode).notifier);
    final phone = context.isPhone;
    final number = _number();
    final date = _date();

    final picker = TextScaleBy(factor: settings.billingScale, child: ProductPicker(products: products, inBill: inBill, onAdd: _addProduct, onQuickAdd: _quickAdd, onScan: () => playSound(ref, SoundKind.scan)));

    final discountBar = DiscountProfitBar(mode: mode, cart: cart, calc: calc, onAmount: notifier.setExtraDiscountAmount, onPercent: notifier.setExtraDiscountPercent);
    Widget lines() => TextScaleBy(factor: settings.billingScale, child: BillLines(mode: mode, cart: cart, calc: calc, onQty: notifier.setQty, onRemove: notifier.remove, onRate: notifier.setRate, onDiscount: notifier.setDiscount, trailing: discountBar, variants: settings.featureOn(AppFeature.brandSwitch) ? ref.watch(productVariantsProvider) : const {}, onBrand: notifier.swapProduct));
    final footer = BillFooter(mode: mode, cart: cart, calc: calc, onPay: notifier.setPay, onReceived: notifier.setReceived, onKeepAdvance: notifier.setKeepAdvance, customerName: cart.customer?.name, customerBalance: cart.customer == null ? null : ref.watch(creditProvider)[cart.customer!.id]?.balance ?? 0, onShowQr: mode == DocMode.invoice && cart.pay == PayMode.upi ? () => _showUpiQr(calc) : null, onSave: _save, onSavePrint: () => _save(print: true), onClear: _clear);

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
            options: [(0, l.tabProducts, Icons.inventory_2_rounded), (1, l.tabBill(cart.lines.length.toString()), Icons.receipt_long_rounded)],
            selected: _phoneTab,
            onChanged: (v) => setState(() => _phoneTab = v),
          ),
        ),
        Expanded(
          child: _phoneTab == 0
              ? Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 8), child: picker)
              : Column(children: [
                  Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 6), child: BillHeader(mode: mode, cart: cart, number: number, date: date, onPickCustomer: _pickCustomer, onEditGst: mode == DocMode.invoice ? _editGst : null, balance: cart.customer == null ? 0 : (ref.watch(creditProvider)[cart.customer!.id]?.balance ?? 0))),
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
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), child: BillHeader(mode: mode, cart: cart, number: number, date: date, onPickCustomer: _pickCustomer, onEditGst: mode == DocMode.invoice ? _editGst : null, balance: cart.customer == null ? 0 : (ref.watch(creditProvider)[cart.customer!.id]?.balance ?? 0))),
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
    FieldSpec('phone', l.fieldPhone, type: FieldType.phone, hint: '98765 43210', required: true, check: (v) => normalizePhone(v) == null ? l.errPhone : null),
    FieldSpec('city', l.fieldCity),
    FieldSpec('gstin', l.fieldGstinOptional, kind: TextKind.gstin),
  ]);
}
