import 'dart:async';
import 'package:flutter/material.dart';
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
  // the page read at start-up is only good until the first new bill: after that the list reads from the database
  final fresh = ref.read(statsProvider).billCount == ref.read(bootstrapProvider).stats.billCount;
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

class SalesRegisterScreen extends ConsumerWidget {
  const SalesRegisterScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final stats = ref.watch(statsProvider);
    final source = ref.watch(billSourceProvider);
    final th = Theme.of(context).textTheme;
    final todayTotal = stats.today.sales;
    final due = stats.toCollect;
    String custName(BillRow b) => b.customerName.isEmpty ? l.walkInCustomer : b.customerName;
    Widget badge(BillRow b) {
      final (t, k) = statusInfo(billStatus(b), l);
      return StatusBadge(t, kind: k);
    }

    String mode(PayMode m) => switch (m) { PayMode.cash => l.payCash, PayMode.upi => l.payUpi, PayMode.card => l.payCard, PayMode.credit => l.payCredit };

    Future<void> openBill(BuildContext ctx, BillRow b) async {
      final d = await ref.read(appDataProvider).bills.detail(b.id);
      if (d == null || !ctx.mounted) return;
      final lines = linesAsCart([for (final x in d.lines) (productId: x.productId, name: x.name, unit: x.unit, qtyMilli: x.qtyMilli, ratePaise: x.ratePaise, discountBp: x.discountBp, gstBp: x.gstBp)]);
      final calc = calcBill(lines, inclusive: d.pricesIncludeGst);
      final cancelledNow = b.cancelled;
      final pay = payModeOf(b.payMode);
      unawaited(showDetail(ctx, title: b.number, subtitle: '${custName(b)}  ·  ${formatDateTime(b.at)}${b.oldBillNo == null ? '' : '  ·  ${l.oldBillNo}: ${b.oldBillNo}'}', body: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text('${lines[i].product.name}\n${formatQty(lines[i].qtyMilli)} ${lines[i].product.unit} × ${formatPaise(lines[i].rate)}', style: th.bodyMedium)),
              Text(formatPaise(calc.lines[i].total), style: th.titleSmall),
            ]),
          ),
        const Divider(),
        KeyValue(l.grandTotal, '₹ ${formatPaise(b.totalPaise)}', bold: true),
        KeyValue(l.colPayMode, mode(pay)),
        KeyValue(l.receivedLabel, '₹ ${formatPaise(cancelledNow ? 0 : b.paidPaise)}'),
        if (!cancelledNow) KeyValue(l.balanceDueLabel, '₹ ${formatPaise(b.balancePaise)}  ${b.balancePaise > 0 ? l.addedToCreditNote : ''}', bold: b.balancePaise > 0),
        KeyValue(l.colStatus, statusInfo(billStatus(b), l).$1),
        if (cancelledNow) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${l.cancelledNote}${d.cancelReason == null ? '' : '\n${l.fieldReason}: ${d.cancelReason}'}', style: th.bodySmall)),
      ], actions: [
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            ref.read(printDocProvider.notifier).set(PrintDoc(mode: DocMode.invoice, number: b.number, date: b.at, customer: custName(b), lines: lines, calc: calc, pay: pay, receivedPaise: d.received, changePaise: d.change, advanceKeptPaise: d.advanceKept));
            unawaited(context.push('/print'));
          },
          icon: const Icon(Icons.print_outlined),
          label: Text(l.printAgain),
        ),
        if (!cancelledNow)
          OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); context.go('/sales-returns'); }, icon: const Icon(Icons.assignment_return_outlined), label: Text(l.returnItems)),
        if (!cancelledNow)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: context.c.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final v = await showFormSheet(context, title: l.cancelBillTitle(b.number), saveLabel: l.continueLabel, note: l.cancelBillOwnerOnly, fields: [FieldSpec('reason', l.fieldReason, type: FieldType.multiline, required: true, autofocus: true)]);
              if (v == null || !context.mounted) return;
              final ok = await confirmDialog(context, title: l.cancelBillConfirmTitle, message: l.cancelBillConfirmText(b.number, formatPaise(b.totalPaise, symbol: true)), confirmLabel: l.cancelBill, danger: true);
              if (ok) {
                // stock goes back and the bill's credit is reversed in the same step (nothing extra happens for a bill that never added credit)
                await ref.read(billActionsProvider).cancel(b.id, reason: v['reason']!);
                if (context.mounted) toast(context, l.billCancelled(b.number));
              }
            },
            icon: const Icon(Icons.block),
            label: Text(l.cancelBill),
          ),
      ]));
    }

    return DataListScreen<BillRow>(
      title: l.navSalesRegister,
      subtitle: l.salesRegisterSubtitle(stats.billCount.toString()),
      source: source,
      refreshKey: stats.billCount,
      searchHint: l.searchBillHint,
      addLabel: l.navNewBill,
      onAdd: () => context.go('/bill'),
      stats: [
        StatCard(label: l.statTodaySales, value: '₹ ${formatPaise(todayTotal)}', icon: Icons.trending_up, tone: context.c.success),
        StatCard(label: l.statBillsToday, value: stats.today.bills.toString(), icon: Icons.receipt_long_outlined),
        StatCard(label: l.statToCollect, value: '₹ ${formatPaise(due)}', icon: Icons.south_west, tone: context.c.warning),
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
  }
}

class EstimationsScreen extends ConsumerWidget {
  const EstimationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(estimationsProvider);
    final products = ref.watch(productsProvider);
    final customers = ref.watch(customersProvider);
    final th = Theme.of(context).textTheme;
    Widget status(EstimationDoc e) => e.convertedTo != null ? StatusBadge(l.statusConverted, kind: BadgeKind.success, icon: Icons.check) : (e.editedOn != null ? StatusBadge(l.statusEdited, kind: BadgeKind.info, icon: Icons.edit_outlined) : StatusBadge(l.statusOpen, kind: BadgeKind.neutral));

    Future<List<CartLine>> cartLines(EstimationDoc e) async {
      final ls = await ref.read(appDataProvider).estimations.lines(e.number);
      final byId = {for (final p in products) p.id: p};
      return [
        for (final x in ls)
          CartLine(product: byId[x.productId] ?? Product(id: x.productId, name: x.name, category: '', unit: x.unit, pricePaise: x.ratePaise, costPaise: 0, stockMilli: 0, gstBp: 1800, barcode: ''), qtyMilli: x.qtyMilli, discountBp: x.discountBp, ratePaise: x.ratePaise),
      ];
    }

    return DataListScreen<EstimationDoc>(
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
      onTap: (ctx, e) {
        final converted = e.convertedTo != null;
        showDetail(ctx, title: e.number, subtitle: '${e.customer.isEmpty ? l.walkInCustomer : e.customer}  ·  ${formatDate(e.date)}', body: [
          KeyValue(l.colDate, formatDate(e.date)),
          if (e.editedOn != null) KeyValue(l.rcEditedOn, formatDate(e.editedOn!)),
          KeyValue(l.statItems, '${e.lines}'),
          KeyValue(l.grandTotal, '₹ ${formatPaise(e.totalPaise)}', bold: true),
          if (converted) Padding(padding: const EdgeInsets.only(top: 8), child: StatusBadge(l.convertedTo(e.convertedTo!), kind: BadgeKind.success, icon: Icons.check)),
          const SizedBox(height: 8),
          Text(l.estimateNoStock, style: th.bodySmall),
        ], actions: [
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final lines = await cartLines(e);
              final inclusive = ref.read(shopProvider).pricesIncludeGst;
              ref.read(printDocProvider.notifier).set(PrintDoc(mode: DocMode.estimation, number: e.number, date: e.date, editedOn: e.editedOn, customer: e.customer.isEmpty ? l.walkInCustomer : e.customer, lines: lines, calc: calcBill(lines, inclusive: inclusive), pay: PayMode.cash));
              if (context.mounted) unawaited(context.push('/print'));
            },
            icon: const Icon(Icons.print_outlined),
            label: Text(l.print),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(cartProvider(DocMode.estimation).notifier).loadForEdit(e, products, customers);
              if (context.mounted) context.go('/estimate');
            },
            icon: const Icon(Icons.edit_outlined),
            label: Text(l.edit),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final ls = await ref.read(appDataProvider).estimations.lines(e.number);
              final custId = await ref.read(appDataProvider).estimations.customerIdOf(e.number);
              await ref.read(estimationsProvider.notifier).save(lines: ls, totalPaise: e.totalPaise, customerName: e.customer, customerId: custId, at: ref.read(clockProvider));
              if (context.mounted) toast(context, l.duplicated);
            },
            icon: const Icon(Icons.copy_outlined),
            label: Text(l.duplicate),
          ),
          FilledButton.icon(
            onPressed: converted
                ? null
                : () async {
                    Navigator.pop(ctx);
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
                      fromEstimate: e.number,
                    ));
                    await ref.read(estimationsProvider.notifier).reload();
                    if (context.mounted) toast(context, l.convertedToast(e.number, bill.number));
                  },
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(l.convertToInvoice),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: context.c.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final v = await showFormSheet(context, title: l.deleteEstimateTitle(e.number), saveLabel: l.continueLabel, fields: [FieldSpec('reason', l.fieldReason, type: FieldType.multiline, required: true, autofocus: true)]);
              if (v == null || !context.mounted) return;
              final ok = await confirmDialog(context, title: l.deleteEstimateConfirmTitle, message: l.deleteEstimateConfirmText(e.number, formatPaise(e.totalPaise, symbol: true)), confirmLabel: l.delete, danger: true);
              if (ok) {
                await ref.read(estimationsProvider.notifier).remove(e.number, reason: v['reason']!);
                if (context.mounted) toast(context, l.deleted);
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: Text(l.delete),
          ),
        ]);
      },
    );
  }
}

BillLineInput _lineInput(EstimateLine x, List<Product> products) {
  final p = products.where((e) => e.id == x.productId).firstOrNull;
  return BillLineInput(productId: x.productId, name: x.name, unit: x.unit, qtyMilli: x.qtyMilli, ratePaise: x.ratePaise, gstBp: p?.gstBp ?? 1800, discountBp: x.discountBp, costPaise: p?.costPaise ?? 0);
}
