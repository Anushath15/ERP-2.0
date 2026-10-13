import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../design/data_list.dart';
import '../../design/detail_sheet.dart';
import '../../design/form_sheet.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain_lite/bill_calc.dart';
import '../../fake/models.dart';
import '../../fake/store.dart';
import '../../strings.dart';
import '../billing/cart.dart';

/// Deterministic fake lines for a saved document (the prototype stores only summaries).
List<CartLine> demoLines(String key, int count, List<Product> products) {
  var h = key.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7FFFFFFF);
  int next(int n) {
    h = (h * 1103515245 + 12345) & 0x7FFFFFFF;
    return (h >> 8) % n;
  }

  return [for (var i = 0; i < count; i++) CartLine(product: products[next(products.length)], qtyMilli: 1000 * (1 + next(5)))];
}

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


class CancelledBills extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};
  void add(String n) => state = {...state, n};
}

final cancelledBillsProvider = NotifierProvider<CancelledBills, Set<String>>(CancelledBills.new);

class SalesRegisterScreen extends ConsumerWidget {
  const SalesRegisterScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final bills = ref.watch(billsProvider);
    final cancelled = ref.watch(cancelledBillsProvider);
    final products = ref.watch(productsProvider);
    final th = Theme.of(context).textTheme;
    DocStatus st(BillSummary b) => cancelled.contains(b.number) ? DocStatus.cancelled : b.status;
    final today = ref.watch(clockProvider);
    // bills are newest first, so today's bills are the first ones: stop at the first older bill
    final todays = bills.takeWhile((b) => b.date.year == today.year && b.date.month == today.month && b.date.day == today.day).where((b) => st(b) != DocStatus.cancelled).toList();
    final todayTotal = todays.fold<int>(0, (s, b) => s + b.totalPaise);
    final due = ref.watch(customersProvider).fold<int>(0, (s, c) => s + c.balancePaise);
    Widget badge(BillSummary b) {
      final (t, k) = statusInfo(st(b), l);
      return StatusBadge(t, kind: k);
    }

    String mode(PayMode m) => switch (m) { PayMode.cash => l.payCash, PayMode.upi => l.payUpi, PayMode.card => l.payCard, PayMode.credit => l.payCredit };

    return DataListScreen<BillSummary>(
      title: l.navSalesRegister,
      subtitle: l.salesRegisterSubtitle(bills.length.toString()),
      items: bills,
      searchText: (b) => '${b.number} ${b.customer}',
      searchHint: l.searchBillHint,
      addLabel: l.navNewBill,
      onAdd: () => context.go('/bill'),
      stats: [
        StatCard(label: l.statTodaySales, value: '₹ ${formatPaise(todayTotal)}', icon: Icons.trending_up, tone: context.c.success),
        StatCard(label: l.statBillsToday, value: todays.length.toString(), icon: Icons.receipt_long_outlined),
        StatCard(label: l.statToCollect, value: '₹ ${formatPaise(due)}', icon: Icons.south_west, tone: context.c.warning),
      ],
      filters: [
        FilterSpec(l.statusPaid, (b) => st(b) == DocStatus.paid),
        FilterSpec(l.statusDue, (b) => st(b) == DocStatus.due || st(b) == DocStatus.partly),
        FilterSpec(l.statusCancelled, (b) => st(b) == DocStatus.cancelled),
      ],
      sorts: [(l.sortAmountHigh, (a, b) => b.totalPaise.compareTo(a.totalPaise))],
      columns: [
        ColumnSpec(l.colBillNo, (c, b) => Cell(b.number, bold: true), width: 110),
        ColumnSpec(l.colDate, (c, b) => Cell(formatDateTime(b.date), muted: true), width: 170),
        ColumnSpec(l.colCustomer, (c, b) => Cell(b.customer), flex: 4),
        ColumnSpec(l.statItems, (c, b) => Cell('${b.items}', muted: true), width: 60, numeric: true),
        ColumnSpec(l.colPayMode, (c, b) => Cell(mode(b.mode), muted: true), width: 90),
        ColumnSpec(l.colAmount, (c, b) => Cell(formatPaise(b.totalPaise), bold: true), width: 110, numeric: true),
        ColumnSpec(l.colStatus, (c, b) => badge(b), width: 110),
      ],
      phoneTitle: (c, b) => Row(children: [Expanded(child: Text(b.customer, style: th.titleSmall)), Text('₹ ${formatPaise(b.totalPaise)}', style: th.titleSmall)]),
      phoneSubtitle: (b) => '${b.number}  ·  ${formatDateTime(b.date)}',
      phoneTrailing: (c, b) => badge(b),
      onTap: (ctx, b) {
        final lines = demoLines(b.number, b.items, products);
        final calc = calcBill(lines);
        final cancelledNow = st(b) == DocStatus.cancelled;
        showDetail(ctx, title: b.number, subtitle: '${b.customer}  ·  ${formatDateTime(b.date)}', body: [
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
          KeyValue(l.colPayMode, mode(b.mode)),
          KeyValue(l.colStatus, statusInfo(st(b), l).$1),
          if (cancelledNow) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.cancelledNote, style: th.bodySmall)),
        ], actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(printDocProvider.notifier).set(PrintDoc(mode: DocMode.invoice, number: b.number, date: b.date, customer: b.customer, lines: lines, calc: calc, pay: b.mode));
              context.push('/print');
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
                  ref.read(cancelledBillsProvider.notifier).add(b.number);
                  if (context.mounted) toast(context, l.billCancelled(b.number));
                }
              },
              icon: const Icon(Icons.block),
              label: Text(l.cancelBill),
            ),
        ]);
      },
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
        ColumnSpec(l.colCustomer, (c, e) => Cell(e.customer), flex: 4),
        ColumnSpec(l.statItems, (c, e) => Cell('${e.lines}', muted: true), width: 60, numeric: true),
        ColumnSpec(l.colAmount, (c, e) => Cell(formatPaise(e.totalPaise), bold: true), width: 110, numeric: true),
        ColumnSpec(l.colStatus, (c, e) => status(e), width: 130),
      ],
      phoneTitle: (c, e) => Row(children: [Expanded(child: Text(e.customer, style: th.titleSmall)), Text('₹ ${formatPaise(e.totalPaise)}', style: th.titleSmall)]),
      phoneSubtitle: (e) => '${e.number}  ·  ${formatDate(e.date)}',
      phoneTrailing: (c, e) => status(e),
      onTap: (ctx, e) {
        final lines = demoLines(e.number, e.lines.clamp(1, 12), products);
        final calc = calcBill(lines);
        PrintDoc docOf() => PrintDoc(mode: DocMode.estimation, number: e.number, date: e.date, editedOn: e.editedOn, customer: e.customer, lines: lines, calc: calc, pay: PayMode.cash);
        final converted = e.convertedTo != null;
        showDetail(ctx, title: e.number, subtitle: '${e.customer}  ·  ${formatDate(e.date)}', body: [
          KeyValue(l.colDate, formatDate(e.date)),
          if (e.editedOn != null) KeyValue(l.rcEditedOn, formatDate(e.editedOn!)),
          KeyValue(l.statItems, '${e.lines}'),
          KeyValue(l.grandTotal, '₹ ${formatPaise(e.totalPaise)}', bold: true),
          if (converted) Padding(padding: const EdgeInsets.only(top: 8), child: StatusBadge(l.convertedTo(e.convertedTo!), kind: BadgeKind.success, icon: Icons.check)),
          const SizedBox(height: 8),
          Text(l.estimateNoStock, style: th.bodySmall),
        ], actions: [
          OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); ref.read(printDocProvider.notifier).set(docOf()); context.push('/print'); }, icon: const Icon(Icons.visibility_outlined), label: Text(l.view)),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(cartProvider(DocMode.estimation).notifier).loadForEdit(e, products, customers);
              context.go('/estimate');
            },
            icon: const Icon(Icons.edit_outlined),
            label: Text(l.edit),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              final n = ref.read(estimateCounterProvider);
              ref.read(estimateCounterProvider.notifier).bump();
              ref.read(estimationsProvider.notifier).add(EstimationDoc(number: 'EST-${n.toString().padLeft(5, '0')}', date: ref.read(clockProvider), customer: e.customer, lines: e.lines, totalPaise: e.totalPaise));
              toast(context, l.duplicated);
            },
            icon: const Icon(Icons.copy_outlined),
            label: Text(l.duplicate),
          ),
          FilledButton.icon(
            onPressed: converted
                ? null
                : () async {
                    Navigator.pop(ctx);
                    final no = 'A-${ref.read(invoiceCounterProvider).toString().padLeft(6, '0')}';
                    final ok = await confirmDialog(context, title: l.convertTitle, message: l.convertText(e.number, no), confirmLabel: l.convertToInvoice);
                    if (!ok) return;
                    ref.read(invoiceCounterProvider.notifier).bump();
                    ref.read(estimationsProvider.notifier).replace(EstimationDoc(number: e.number, date: e.date, customer: e.customer, lines: e.lines, totalPaise: e.totalPaise, editedOn: e.editedOn, convertedTo: no));
                    if (context.mounted) toast(context, l.convertedToast(e.number, no));
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
                ref.read(estimationsProvider.notifier).remove(e.number);
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
