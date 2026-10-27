import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/plain_error.dart';
import '../../design/open_once.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../data/repo/bill_repo.dart';
import '../../data/repo/records_repo.dart' show EstimateLine;
import '../../design/data_list.dart';
import '../../design/detail_sheet.dart';
import '../../design/form_sheet.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain_lite/bill_calc.dart';
import '../../fake/actions.dart';
import '../../fake/data_providers.dart';
import '../../fake/models.dart';
import '../../fake/stats.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart';
import '../../strings.dart';
import '../billing/cart.dart';

(String, BadgeKind) statusInfo(DocStatus s, Strings l) => switch (s) {
      DocStatus.paid => (l.statusPaid, BadgeKind.success),
      DocStatus.partly => (l.statusPartly, BadgeKind.warning),
      DocStatus.due => (l.statusDue, BadgeKind.danger),
      DocStatus.cancelled => (l.statusCancelled, BadgeKind.neutral),
      DocStatus.pending => (l.statusPending, BadgeKind.warning),
      DocStatus.delivered => (l.statusDelivered, BadgeKind.success),
      DocStatus.converted => (l.statusConverted, BadgeKind.success),
      DocStatus.open => (l.statusOpen, BadgeKind.info),
    };

/// How a saved bill reads in a list: cancelled, paid, part paid or on credit.
DocStatus billStatus(BillRow b) => b.cancelled ? DocStatus.cancelled : (b.balancePaise == 0 ? DocStatus.paid : (b.balancePaise < b.totalPaise ? DocStatus.partly : DocStatus.due));

PayMode payModeOf(int i) => PayMode.values[i.clamp(0, PayMode.values.length - 1)];

/// The sales register reads the bills page by page from the database (never all of them at once).
final billSourceProvider = Provider<PagedSource<BillRow>>((ref) {
  final repo = ref.watch(appDataProvider).bills;
  // The page read at start-up is only good until anything changes (a new bill, a payment, a cancellation, a return): the figures are read
  // again after each of those, which makes a new source, and from then on the list reads from the database. (This used to look at the bill
  // count only once, so a register opened before a sale could show the old list, even empty, when it was opened again.)
  final stats = ref.watch(statsProvider);
  final fresh = identical(stats, ref.read(bootstrapProvider).stats);
  final first = ref.read(bootstrapProvider).firstBills;
  return PagedSource<BillRow>(
    initial: fresh ? PageResult(first, first.length < 50 ? null : BillRepo.cursorOf(first.last)) : null,
    load: (q, cursor) async {
      final rows = await repo.page(search: q.text, status: q.filter, byAmount: q.sort == 1, after: cursor as BillCursor?, limit: 50);
      return PageResult(rows, rows.length < 50 ? null : BillRepo.cursorOf(rows.last));
    },
  );
});

/// Stand-in products for the lines of a saved document (the bill keeps its own copy of name, unit and rates).
List<CartLine> linesAsCart(List<({String productId, String name, String unit, int qtyMilli, int ratePaise, int discountBp, int gstBp})> lines) => [
      for (final x in lines) CartLine(product: Product(id: x.productId, name: x.name, category: '', unit: x.unit, pricePaise: x.ratePaise, costPaise: 0, stockMilli: 0, gstBp: x.gstBp, barcode: ''), qtyMilli: x.qtyMilli, discountBp: x.discountBp, ratePaise: x.ratePaise),
    ];

/// The popup of one saved bill (items, totals, how it was paid) with Print again, Return items and Cancel bill. Used by the Sales
/// register and by the customer's page. [backTo] is where the Back button of the print page returns (and reopens this popup).
Future<void> showBillPopup(BuildContext context, WidgetRef ref, BillRow b, {String? backTo}) async {
  final ctx = context;
  final l = tr(context);
  final th = Theme.of(context).textTheme;
  String custName(BillRow b) => b.customerName.isEmpty ? l.walkInCustomer : b.customerName;
  String mode(PayMode m) => switch (m) { PayMode.cash => l.payCash, PayMode.upi => l.payUpi, PayMode.card => l.payCard, PayMode.credit => l.payCredit };
  final d = await ref.read(appDataProvider).bills.detail(b.id);
  if (d == null || !ctx.mounted) return;
  final givenBack = await ref.read(appDataProvider).returns.returnedTotal(b.id);
  if (!ctx.mounted) return;
  final savedLines = linesAsCart([for (final x in d.lines) (productId: x.productId, name: x.name, unit: x.unit, qtyMilli: x.qtyMilli, ratePaise: x.ratePaise, discountBp: x.discountBp, gstBp: x.gstBp)]);
  // the reprint carries each product's HSN code, brand and MRP (from the catalog) but keeps the GST rate the bill was made with
  final catalog = {for (final p in ref.read(productsProvider)) p.id: p};
  final lines = [
    for (final x in savedLines)
      catalog[x.product.id] == null ? x : CartLine(product: catalog[x.product.id]!.copyWith(gstBp: x.product.gstBp), qtyMilli: x.qtyMilli, discountBp: x.discountBp, ratePaise: x.rate),
  ];
  // a bill saved while "round to the rupee" was off has its exact total: show the maths that matches what was saved
  var calc = calcBill(lines, inclusive: d.pricesIncludeGst, extraDiscountPaise: d.extraDiscountPaise, extraDiscountBp: d.extraDiscountBp);
  if (calc.grandTotal != b.totalPaise) calc = calcBill(lines, inclusive: d.pricesIncludeGst, roundOff: false, extraDiscountPaise: d.extraDiscountPaise, extraDiscountBp: d.extraDiscountBp);
  final cancelledNow = b.cancelled;
  final pay = payModeOf(b.payMode);
  final cust = b.customerId == null ? null : ref.read(customersProvider).where((c) => c.id == b.customerId).firstOrNull;
  unawaited(showDetail(ctx, title: b.number, subtitle: '${custName(b)}  ·  ${formatDateTime(b.at)}${b.oldBillNo == null ? '' : '  ·  ${l.oldBillNo}: ${b.oldBillNo}'}', body: [
    for (var i = 0; i < lines.length; i++)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text('${lines[i].product.billName}\n${formatQty(lines[i].qtyMilli)} ${lines[i].product.unit} × ${formatPaise(lines[i].rate)}', style: th.bodyMedium)),
          Text(formatPaise(calc.lines[i].total), style: th.titleSmall),
        ]),
      ),
    const Divider(),
    KeyValue(l.grandTotal, '₹ ${formatPaise(b.totalPaise)}', bold: true),
    KeyValue(l.colPayMode, mode(pay)),
    KeyValue(l.receivedLabel, '₹ ${formatPaise(cancelledNow ? 0 : b.paidPaise)}'),
    if (!cancelledNow) KeyValue(l.balanceDueLabel, '₹ ${formatPaise(b.balancePaise)}  ${b.balancePaise > 0 ? l.addedToCreditNote : ''}', bold: b.balancePaise > 0),
    KeyValue(l.colStatus, statusInfo(billStatus(b), l).$1),
    if (givenBack > 0) KeyValue(l.retReturned, '₹ ${formatPaise(givenBack)}'),
    if (cancelledNow) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${l.cancelledNote}${d.cancelReason == null ? '' : '\n${l.fieldReason}: ${d.cancelReason}'}', style: th.bodySmall)),
  ], actions: [
    OutlinedButton.icon(
      onPressed: () {
        Navigator.of(ctx, rootNavigator: true).pop();
        ref.read(printDocProvider.notifier).set(PrintDoc(extraDiscountBp: d.extraDiscountBp, mode: DocMode.invoice, number: b.number, date: b.at, customer: custName(b), customerPhone: cust?.phone ?? '', customerGstin: cust?.gstin ?? '', lines: lines, calc: calc, pay: pay, receivedPaise: d.received, changePaise: d.change, advanceKeptPaise: d.advanceKept, backTo: backTo ?? '/sales?open=${Uri.encodeQueryComponent(b.id)}'));
        unawaited(context.push('/print'));
      },
      icon: const Icon(Icons.print_rounded),
      label: Text(l.printAgain),
    ),
    // a regular customer's usual order: the same items again on a new bill, at today's prices
    OutlinedButton.icon(
      key: const ValueKey('bill-again'),
      onPressed: () async {
        final cart = ref.read(cartProvider(DocMode.invoice));
        if (cart.lines.isNotEmpty) {
          final ok = await confirmDialog(ctx, title: l.billAgainReplaceTitle, message: l.billAgainReplaceText, confirmLabel: l.billAgain);
          if (!ok) return;
        }
        if (!ctx.mounted) return;
        Navigator.of(ctx, rootNavigator: true).pop();
        ref.read(cartProvider(DocMode.invoice).notifier).loadCopy(lines, cust, ref.read(productsProvider));
        if (context.mounted) {
          context.go('/bill');
          toast(context, l.billAgainDone(b.number));
        }
      },
      icon: const Icon(Icons.content_copy_rounded),
      label: Text(l.billAgain),
    ),
    if (!cancelledNow)
      OutlinedButton.icon(key: const ValueKey('bill-return-items'), onPressed: () { Navigator.of(ctx, rootNavigator: true).pop(); context.go('/sales-returns/bill/${b.id}'); }, icon: const Icon(Icons.assignment_return_rounded), label: Text(l.returnItems)),
    if (!cancelledNow)
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: context.c.danger),
        onPressed: () async {
          Navigator.of(ctx, rootNavigator: true).pop();
          final v = await showFormSheet(context, title: l.cancelBillTitle(b.number), saveLabel: l.continueLabel, note: l.cancelBillOwnerOnly, fields: [FieldSpec('reason', l.fieldReason, type: FieldType.multiline, required: true, autofocus: true)]);
          if (v == null || !context.mounted) return;
          final ok = await confirmDialog(context, title: l.cancelBillConfirmTitle, message: l.cancelBillConfirmText(b.number, formatPaise(b.totalPaise, symbol: true)), confirmLabel: l.cancelBill, danger: true);
          if (ok) {
            // stock goes back and the bill's credit is reversed in the same step (nothing extra happens for a bill that never added credit)
            try {
              await ref.read(billActionsProvider).cancel(b.id, reason: v['reason']!);
              if (context.mounted) toast(context, l.billCancelled(b.number));
            } catch (e) {
              if (context.mounted) toast(context, plainError(e)); // e.g. items were already returned from this bill
            }
          }
        },
        icon: const Icon(Icons.block_rounded),
        label: Text(l.cancelBill),
      ),
  ]));
}

class SalesRegisterScreen extends ConsumerWidget {
  const SalesRegisterScreen({super.key, this.openBillId});

  /// Opens this bill's popup at once (the Back button of the print page returns here).
  final String? openBillId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final stats = ref.watch(statsProvider);
    final source = ref.watch(billSourceProvider);
    final todayTotal = stats.today.sales;
    final due = stats.toCollect;
    String custName(BillRow b) => b.customerName.isEmpty ? l.walkInCustomer : b.customerName;
    Widget badge(BillRow b) {
      final (t, k) = statusInfo(billStatus(b), l);
      return StatusBadge(t, kind: k);
    }

    String mode(PayMode m) => switch (m) { PayMode.cash => l.payCash, PayMode.upi => l.payUpi, PayMode.card => l.payCard, PayMode.credit => l.payCredit };

    Future<void> openBill(BuildContext ctx, BillRow b) => showBillPopup(context, ref, b);

    final list = DataListScreen<BillRow>(
      title: l.navSalesRegister,
      subtitle: l.salesRegisterSubtitle(stats.billCount.toString()),
      source: source,
      refreshKey: stats.billCount,
      searchHint: l.searchBillHint,
      addLabel: l.navNewBill,
      onAdd: () => context.go('/bill'),
      stats: [
        StatCard(label: l.statTodaySales, value: '₹ ${formatPaise(todayTotal)}', icon: Icons.trending_up_rounded, tone: context.c.success),
        StatCard(label: l.statBillsToday, value: stats.today.bills.toString(), icon: Icons.receipt_long_rounded),
        StatCard(label: l.statToCollect, value: '₹ ${formatPaise(due)}', icon: Icons.south_west_rounded, tone: context.c.warning),
      ],
      filters: [
        FilterSpec<BillRow>(l.statusPaid, (_) => true),
        FilterSpec<BillRow>(l.statusPartly, (_) => true),
        FilterSpec<BillRow>(l.statusDue, (_) => true),
        FilterSpec<BillRow>(l.statusCancelled, (_) => true),
      ],
      sorts: [(l.sortAmountHigh, (a, b) => 0)],
      columns: [
        ColumnSpec(l.colBillNo, (c, b) => Cell(b.number, bold: true), width: 110),
        ColumnSpec(l.colDate, (c, b) => Cell(formatDateTime(b.at), muted: true), width: 170),
        ColumnSpec(l.colCustomer, (c, b) => Cell(custName(b)), flex: 4),
        ColumnSpec(l.statItems, (c, b) => Cell('${b.items}', muted: true), width: 60, numeric: true),
        ColumnSpec(l.colPayMode, (c, b) => Cell(mode(payModeOf(b.payMode)), muted: true), width: 90),
        ColumnSpec(l.colAmount, (c, b) => Cell(formatPaise(b.totalPaise), bold: true), width: 110, numeric: true),
        ColumnSpec(l.colStatus, (c, b) => badge(b), width: 110),
      ],
      phoneTitle: (c, b) => TitleAmount(custName(b), '₹ ${formatPaise(b.totalPaise)}'),
      phoneSubtitle: (b) => '${b.number}  ·  ${formatDateTime(b.at)}',
      phoneTrailing: (c, b) => badge(b),
      onTap: (ctx, b) => unawaited(openBill(ctx, b)),
    );
    return OpenOnce(
      key: ValueKey('open-bill-${openBillId ?? ''}'),
      run: openBillId == null ? null : () async {
        final d = await ref.read(appDataProvider).bills.detail(openBillId!);
        if (d != null && context.mounted) await openBill(context, d.row);
      },
      child: list,
    );
  }
}

class EstimationsScreen extends ConsumerWidget {
  const EstimationsScreen({super.key, this.openNumber});

  /// Opens this estimate's popup at once (the Back button of the print page returns here).
  final String? openNumber;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(estimationsProvider);
    final products = ref.watch(productsProvider);
    final customers = ref.watch(customersProvider);
    final th = Theme.of(context).textTheme;
    Widget status(EstimationDoc e) => e.convertedTo != null ? StatusBadge(l.statusConverted, kind: BadgeKind.success, icon: Icons.check_rounded) : (e.editedOn != null ? StatusBadge(l.statusEdited, kind: BadgeKind.info, icon: Icons.edit_rounded) : StatusBadge(l.statusOpen, kind: BadgeKind.neutral));

    Future<List<CartLine>> cartLines(EstimationDoc e) async {
      final ls = await ref.read(appDataProvider).estimations.lines(e.number);
      final byId = {for (final p in products) p.id: p};
      return [
        for (final x in ls)
          CartLine(product: byId[x.productId] ?? Product(id: x.productId, name: x.name, category: '', unit: x.unit, pricePaise: x.ratePaise, costPaise: 0, stockMilli: 0, gstBp: 1800, barcode: ''), qtyMilli: x.qtyMilli, discountBp: x.discountBp, ratePaise: x.ratePaise),
      ];
    }

    void showEstimate(BuildContext ctx, EstimationDoc e) {
        final converted = e.convertedTo != null;
        showDetail(ctx, title: e.number, subtitle: '${e.customer.isEmpty ? l.walkInCustomer : e.customer}  ·  ${formatDate(e.date)}', body: [
          KeyValue(l.colDate, formatDate(e.date)),
          if (e.editedOn != null) KeyValue(l.rcEditedOn, formatDate(e.editedOn!)),
          KeyValue(l.statItems, '${e.lines}'),
          KeyValue(l.grandTotal, '₹ ${formatPaise(e.totalPaise)}', bold: true),
          if (converted) Padding(padding: const EdgeInsets.only(top: 8), child: StatusBadge(l.convertedTo(e.convertedTo!), kind: BadgeKind.success, icon: Icons.check_rounded)),
          const SizedBox(height: 8),
          Text(l.estimateNoStock, style: th.bodySmall),
        ], actions: [
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.of(ctx, rootNavigator: true).pop();
              final lines = await cartLines(e);
              final inclusive = ref.read(shopProvider).pricesIncludeGst;
              final estCust = ref.read(customersProvider).where((c) => c.name == e.customer).firstOrNull;
              ref.read(printDocProvider.notifier).set(PrintDoc(mode: DocMode.estimation, number: e.number, date: e.date, editedOn: e.editedOn, customer: e.customer.isEmpty ? l.walkInCustomer : e.customer, customerPhone: estCust?.phone ?? '', lines: lines, calc: calcBill(lines, inclusive: inclusive, extraDiscountPaise: e.extraDiscountPaise, extraDiscountBp: e.extraDiscountBp), pay: PayMode.cash, extraDiscountBp: e.extraDiscountBp, backTo: '/estimates?open=${Uri.encodeQueryComponent(e.number)}'));
              if (context.mounted) unawaited(context.push('/print'));
            },
            icon: const Icon(Icons.print_rounded),
            label: Text(l.print),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.of(ctx, rootNavigator: true).pop();
              await ref.read(cartProvider(DocMode.estimation).notifier).loadForEdit(e, products, customers);
              if (context.mounted) context.go('/estimate');
            },
            icon: const Icon(Icons.edit_rounded),
            label: Text(l.edit),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.of(ctx, rootNavigator: true).pop();
              final ls = await ref.read(appDataProvider).estimations.lines(e.number);
              final custId = await ref.read(appDataProvider).estimations.customerIdOf(e.number);
              await ref.read(estimationsProvider.notifier).save(lines: ls, totalPaise: e.totalPaise, customerName: e.customer, customerId: custId, at: ref.read(clockProvider), extraDiscountPaise: e.extraDiscountPaise, extraDiscountBp: e.extraDiscountBp);
              if (context.mounted) toast(context, l.duplicated);
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(l.duplicate),
          ),
          FilledButton.icon(
            onPressed: converted
                ? null
                : () async {
                    Navigator.of(ctx, rootNavigator: true).pop();
                    final no = ref.read(nextNumbersProvider).invoice;
                    final ok = await confirmDialog(context, title: l.convertTitle, message: l.convertText(e.number, no), confirmLabel: l.convertToInvoice);
                    if (!ok) return;
                    final d = ref.read(appDataProvider);
                    final ls = await d.estimations.lines(e.number);
                    final custId = await d.estimations.customerIdOf(e.number);
                    final bill = await ref.read(billActionsProvider).save(SaveBillInput(
                      idemKey: 'convert-${e.number}',
                      at: ref.read(clockProvider),
                      lines: [for (final x in ls) _lineInput(x, products)],
                      customerId: custId,
                      customerName: e.customer,
                      pricesIncludeGst: ref.read(shopProvider).pricesIncludeGst,
                      roundOff: ref.read(shopProvider).roundOff,
                      extraDiscountPaise: e.extraDiscountPaise,
                      extraDiscountBp: e.extraDiscountBp,
                      fromEstimate: e.number,
                    ));
                    await ref.read(estimationsProvider.notifier).reload();
                    if (context.mounted) toast(context, l.convertedToast(e.number, bill.number));
                  },
            icon: const Icon(Icons.receipt_long_rounded),
            label: Text(l.convertToInvoice),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: context.c.danger),
            onPressed: () async {
              Navigator.of(ctx, rootNavigator: true).pop();
              final v = await showFormSheet(context, title: l.deleteEstimateTitle(e.number), saveLabel: l.continueLabel, fields: [FieldSpec('reason', l.fieldReason, type: FieldType.multiline, required: true, autofocus: true)]);
              if (v == null || !context.mounted) return;
              final ok = await confirmDialog(context, title: l.deleteEstimateConfirmTitle, message: l.deleteEstimateConfirmText(e.number, formatPaise(e.totalPaise, symbol: true)), confirmLabel: l.delete, danger: true);
              if (ok) {
                await ref.read(estimationsProvider.notifier).remove(e.number, reason: v['reason']!);
                if (context.mounted) toast(context, l.deleted);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(l.delete),
          ),
        ]);
    }

    final list = DataListScreen<EstimationDoc>(
      title: l.navSavedEstimates,
      subtitle: l.estimatesSubtitle,
      items: items,
      searchText: (e) => '${e.number} ${e.customer}',
      searchHint: l.searchEstimateHint,
      addLabel: l.navNewEstimate,
      onAdd: () => context.go('/estimate'),
      emptyTitle: l.noEstimates,
      emptyText: l.noEstimatesHelp,
      filters: [
        FilterSpec(l.statusOpen, (e) => e.convertedTo == null),
        FilterSpec(l.statusEdited, (e) => e.editedOn != null),
        FilterSpec(l.statusConverted, (e) => e.convertedTo != null),
      ],
      columns: [
        ColumnSpec(l.colEstNo, (c, e) => Cell(e.number, bold: true), width: 120),
        ColumnSpec(l.colDate, (c, e) => Cell(formatDate(e.date), muted: true), width: 100),
        ColumnSpec(l.colCustomer, (c, e) => Cell(e.customer.isEmpty ? l.walkInCustomer : e.customer), flex: 4),
        ColumnSpec(l.statItems, (c, e) => Cell('${e.lines}', muted: true), width: 60, numeric: true),
        ColumnSpec(l.colAmount, (c, e) => Cell(formatPaise(e.totalPaise), bold: true), width: 110, numeric: true),
        ColumnSpec(l.colStatus, (c, e) => status(e), width: 130),
      ],
      phoneTitle: (c, e) => TitleAmount(e.customer.isEmpty ? l.walkInCustomer : e.customer, '₹ ${formatPaise(e.totalPaise)}'),
      phoneSubtitle: (e) => '${e.number}  ·  ${formatDate(e.date)}',
      phoneTrailing: (c, e) => status(e),
      onTap: showEstimate,
    );
    return OpenOnce(
      key: ValueKey('open-estimate-${openNumber ?? ''}'),
      run: openNumber == null ? null : () {
        final e = items.where((x) => x.number == openNumber).firstOrNull;
        if (e != null) showEstimate(context, e);
      },
      child: list,
    );
  }
}

BillLineInput _lineInput(EstimateLine x, List<Product> products) {
  final p = products.where((e) => e.id == x.productId).firstOrNull;
  return BillLineInput(productId: x.productId, name: x.name, unit: x.unit, qtyMilli: x.qtyMilli, ratePaise: x.ratePaise, gstBp: p?.gstBp ?? 1800, discountBp: x.discountBp, costPaise: p?.costPaise ?? 0);
}
