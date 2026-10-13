import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
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
/// Save, Save and Print, Preview) is pinned and never moves, however many lines the bill has.
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
    return PrintDoc(mode: mode, number: _number(), date: _date(), editedOn: cart.editingNumber != null ? ref.read(clockProvider) : null, customer: cart.customer?.name ?? tr(context).walkInCustomer, lines: cart.lines, calc: calc, pay: cart.pay);
  }

  void _save({bool print = false}) {
    final l = tr(context);
    final doc = _snapshot();
    final editing = ref.read(cartProvider(mode)).editingNumber != null;
    if (!editing) {
      mode == DocMode.invoice ? ref.read(invoiceCounterProvider.notifier).bump() : ref.read(estimateCounterProvider.notifier).bump();
    }
    if (mode == DocMode.estimation) {
      final e = EstimationDoc(number: doc.number, date: doc.date, customer: doc.customer, lines: doc.lines.length, totalPaise: doc.calc.grandTotal, editedOn: editing ? doc.editedOn : null);
      final n = ref.read(estimationsProvider.notifier);
      editing ? n.replace(e) : n.add(e);
    }
    ref.read(cartProvider(mode).notifier).clear();
    toast(context, mode == DocMode.invoice ? l.billSaved(doc.number) : l.estimateSaved(doc.number));
    if (print) {
      ref.read(printDocProvider.notifier).set(doc);
      context.push('/print');
    }
    setState(() => _phoneTab = 0);
  }

  void _preview() {
    ref.read(printDocProvider.notifier).set(_snapshot());
    context.push('/print');
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

    final picker = TextScaleBy(factor: settings.billingScale, child: ProductPicker(products: products, inBill: inBill, onAdd: _addProduct, onQuickAdd: _quickAdd));

    Widget lines() => TextScaleBy(factor: settings.billingScale, child: BillLines(mode: mode, cart: cart, calc: calc, onQty: notifier.setQty, onRemove: notifier.remove, onRate: notifier.setRate, onDiscount: notifier.setDiscount));
    final footer = BillFooter(mode: mode, cart: cart, calc: calc, onPay: notifier.setPay, onSave: _save, onSavePrint: () => _save(print: true), onPreview: _preview, onClear: _clear);

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
        if (cart.lines.isNotEmpty) _save();
      },
      const SingleActivator(LogicalKeyboardKey.f9): () {
        if (cart.lines.isNotEmpty) _save(print: true);
      },
      const SingleActivator(LogicalKeyboardKey.f8): () {
        if (cart.lines.isNotEmpty) _preview();
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
                  Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 6), child: BillHeader(mode: mode, cart: cart, number: number, date: date, onPickCustomer: _pickCustomer)),
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
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), child: BillHeader(mode: mode, cart: cart, number: number, date: date, onPickCustomer: _pickCustomer)),
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
    FieldSpec('phone', l.fieldPhone, type: FieldType.phone),
    FieldSpec('city', l.fieldCity),
  ]);
}
