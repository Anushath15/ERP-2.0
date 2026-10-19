import 'dart:async';
import '../purchases/purchase_screens.dart';
import '../../fake/actions.dart' show purchasesVersionProvider;
import '../../data/ids.dart';
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
import '../../fake/actions.dart' show returnsVersionProvider;
import '../../fake/data_providers.dart';
import '../../fake/models.dart';
import '../../fake/store.dart';

String _d(Rec r, String k) => formatDate(r.f[k] as DateTime);

/// The purchases with items (read from the database) and the older plain notes kept from before items were saved.
final purchaseListRecsProvider = FutureProvider.autoDispose<List<Rec>>((ref) async {
  final real = await ref.watch(purchaseListProvider.future);
  final older = ref.watch(recsProvider('purchases'));
  return [
    for (final r in real)
      Rec(r.id, {'no': r.number, 'date': r.at, 'dealer': r.dealerName, 'invoice': r.invoiceNo, 'amount': r.totalPaise, 'status': r.received ? 'received' : 'pending', 'real': 1, 'dealerId': r.dealerId}),
    ...older,
  ];
});

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final list = ref.watch(purchaseListRecsProvider);
    final items = list.asData?.value ?? const <Rec>[];
    final th = Theme.of(context).textTheme;
    Widget status(Rec r) => r.s('status') == 'received' ? StatusBadge(l.statusReceived, kind: BadgeKind.success) : StatusBadge(l.statusPending, kind: BadgeKind.warning);
    return DataListScreen<Rec>(
      title: l.navPurchases,
      subtitle: l.purchasesSubtitle,
      items: items,
      searchText: (r) => '${r.s('no')} ${r.s('dealer')} ${r.s('invoice')}',
      addLabel: l.addPurchase,
      onAdd: () => context.go('/purchases/new'),
      filters: [FilterSpec(l.statusReceived, (r) => r.s('status') == 'received'), FilterSpec(l.statusPending, (r) => r.s('status') == 'pending')],
      columns: [
        ColumnSpec(l.colNo, (c, r) => Cell(r.s('no'), bold: true), width: 110),
        ColumnSpec(l.colDate, (c, r) => Cell(_d(r, 'date'), muted: true), width: 100),
        ColumnSpec(l.navDealers, (c, r) => Cell(r.s('dealer')), flex: 4),
        ColumnSpec(l.fieldDealerInvoice, (c, r) => Cell(r.s('invoice'), muted: true), width: 110),
        ColumnSpec(l.colAmount, (c, r) => Cell(formatPaise(r.i('amount')), bold: true), width: 120, numeric: true),
        ColumnSpec(l.colStatus, (c, r) => status(r), width: 110),
      ],
      phoneTitle: (c, r) => TitleAmount(r.s('dealer'), '₹ ${formatPaise(r.i('amount'))}'),
      phoneSubtitle: (r) => '${r.s('no')} · ${_d(r, 'date')}',
      phoneTrailing: (c, r) => status(r),
      onTap: (ctx, r) async {
        if (r.i('real') == 1) {
          final row = (await ref.read(appDataProvider).purchases.list()).where((x) => x.id == r.id).firstOrNull;
          if (row != null && context.mounted) await showPurchasePopup(context, ref, row);
          return;
        }
        unawaited(showDetail(ctx, title: r.s('no'), subtitle: r.s('dealer'), body: [
          KeyValue(l.colDate, _d(r, 'date')),
          KeyValue(l.fieldDealerInvoice, r.s('invoice')),
          KeyValue(l.colAmount, '₹ ${formatPaise(r.i('amount'))}', bold: true),
          KeyValue(l.colStatus, r.s('status') == 'received' ? l.statusReceived : l.statusPending),
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.purOlderNote, style: th.bodySmall)),
        ], actions: [
          if (r.s('status') == 'pending')
            FilledButton.icon(
              onPressed: () {
                ref.read(recsProvider('purchases').notifier).replace(r.with_({'status': 'received'}));
                Navigator.of(ctx, rootNavigator: true).pop();
                toast(context, l.markedReceived);
              },
              icon: const Icon(Icons.inventory_outlined),
              label: Text(l.markReceived),
            ),
        ]));
      },
    );
  }
}

/// The sales returns made from saved bills (read from the database) and any older notes kept from before returns were counted.
final salesReturnListProvider = FutureProvider.autoDispose<List<Rec>>((ref) async {
  ref.watch(returnsVersionProvider);
  final d = ref.read(appDataProvider);
  final real = await d.returns.list();
  final older = ref.watch(recsProvider('salesReturns'));
  return [
    for (final r in real)
      Rec(r.id, {
        'no': r.number,
        'date': r.at,
        'customer': r.customerName,
        'bill': r.billNo,
        'reason': r.reason,
        'amount': r.totalPaise,
        'debt': r.dueReducedPaise,
        'credit': r.creditKeptPaise,
        'cash': r.refundedPaise,
        'real': 1,
      }),
    ...older,
  ];
});

class SalesReturnsScreen extends ConsumerWidget {
  const SalesReturnsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final list = ref.watch(salesReturnListProvider);
    final items = list.asData?.value ?? const <Rec>[];
    String settled(Rec r) {
      if (r.i('real') != 1) return l.retOldNote;
      final parts = [
        if (r.i('debt') > 0) '${l.retSettledDebt}: ${formatPaise(r.i('debt'), symbol: true)}',
        if (r.i('credit') > 0) '${l.retSettledCredit}: ${formatPaise(r.i('credit'), symbol: true)}',
        if (r.i('cash') > 0) '${l.retSettledCash}: ${formatPaise(r.i('cash'), symbol: true)}',
      ];
      return parts.join(' · ');
    }

    String who(Rec r) => r.s('customer').isEmpty ? l.walkInCustomer : r.s('customer');
    return DataListScreen<Rec>(
      title: l.navSalesReturns,
      subtitle: l.salesReturnsSubtitle,
      items: items,
      searchText: (r) => '${r.s('no')} ${r.s('customer')} ${r.s('bill')}',
      addLabel: l.addReturn,
      onAdd: () async {
        final v = await showFormSheet(context, title: l.addReturn, saveLabel: l.continueLabel, note: l.retAskBill, fields: [
          FieldSpec('bill', l.colBillNo, required: true, autofocus: true, hint: 'A-000001'),
        ]);
        if (v == null || !context.mounted) return;
        final id = await ref.read(appDataProvider).returns.billIdByNumber(v['bill']!);
        if (!context.mounted) return;
        if (id == null) {
          toast(context, l.retNoBill);
          return;
        }
        context.go('/sales-returns/bill/$id');
      },
      columns: [
        ColumnSpec(l.colNo, (c, r) => Cell(r.s('no'), bold: true), width: 100),
        ColumnSpec(l.colDate, (c, r) => Cell(_d(r, 'date'), muted: true), width: 100),
        ColumnSpec(l.colCustomer, (c, r) => Cell(who(r)), flex: 3),
        ColumnSpec(l.colBillNo, (c, r) => Cell(r.s('bill'), muted: true), width: 110),
        ColumnSpec(l.fieldReason, (c, r) => Cell(r.s('reason'), muted: true), flex: 3),
        ColumnSpec(l.retHowDone, (c, r) => Cell(settled(r), muted: true), flex: 3),
        ColumnSpec(l.colAmount, (c, r) => Cell(formatPaise(r.i('amount')), bold: true), width: 110, numeric: true),
      ],
      phoneTitle: (c, r) => TitleAmount(who(r), '₹ ${formatPaise(r.i('amount'))}'),
      phoneSubtitle: (r) => '${r.s('no')} · ${r.s('bill')} · ${r.s('reason')}',
    );
  }
}

/// The returns given back to dealers (read from the database) and the older plain notes kept from before items were saved.
final purchaseReturnListProvider = FutureProvider.autoDispose<List<Rec>>((ref) async {
  ref.watch(purchasesVersionProvider);
  final real = await ref.read(appDataProvider).purchaseReturns.list();
  final older = ref.watch(recsProvider('purchaseReturns'));
  return [
    for (final r in real)
      Rec(r.id, {'no': r.number, 'date': r.at, 'dealer': r.dealerName, 'purchase': r.purchaseNo, 'reason': r.reason, 'amount': r.totalPaise, 'debt': r.dueReducedPaise, 'credit': r.creditKeptPaise, 'cash': r.refundedPaise, 'real': 1}),
    ...older,
  ];
});

class PurchaseReturnsScreen extends ConsumerWidget {
  const PurchaseReturnsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final list = ref.watch(purchaseReturnListProvider);
    final items = list.asData?.value ?? const <Rec>[];
    String settled(Rec r) {
      if (r.i('real') != 1) return l.retOldNote;
      final parts = [
        if (r.i('debt') > 0) '${l.pretSettledDebt}: ${formatPaise(r.i('debt'), symbol: true)}',
        if (r.i('credit') > 0) '${l.pretCreditKept}: ${formatPaise(r.i('credit'), symbol: true)}',
        if (r.i('cash') > 0) '${l.pretSettledCash}: ${formatPaise(r.i('cash'), symbol: true)}',
      ];
      return parts.join(' · ');
    }

    return DataListScreen<Rec>(
      title: l.navPurchaseReturns,
      subtitle: l.purchaseReturnsSubtitle,
      items: items,
      searchText: (r) => '${r.s('no')} ${r.s('dealer')} ${r.s('purchase')}',
      addLabel: l.addReturn,
      onAdd: () async {
        final v = await showFormSheet(context, title: l.addReturn, saveLabel: l.continueLabel, note: l.pretAskNumber, fields: [
          FieldSpec('purchase', l.pretPurchaseNo, required: true, autofocus: true, hint: 'PUR-00001'),
        ]);
        if (v == null || !context.mounted) return;
        final id = await ref.read(appDataProvider).purchaseReturns.purchaseIdByNumber(v['purchase']!);
        if (!context.mounted) return;
        if (id == null) {
          toast(context, l.pretNoPurchase);
          return;
        }
        context.go('/purchase-returns/purchase/$id');
      },
      columns: [
        ColumnSpec(l.colNo, (c, r) => Cell(r.s('no'), bold: true), width: 100),
        ColumnSpec(l.colDate, (c, r) => Cell(_d(r, 'date'), muted: true), width: 100),
        ColumnSpec(l.navDealers, (c, r) => Cell(r.s('dealer')), flex: 3),
        ColumnSpec(l.pretPurchaseNo, (c, r) => Cell(r.s('purchase'), muted: true), width: 110),
        ColumnSpec(l.fieldReason, (c, r) => Cell(r.s('reason'), muted: true), flex: 3),
        ColumnSpec(l.pretHowDone, (c, r) => Cell(settled(r), muted: true), flex: 3),
        ColumnSpec(l.colAmount, (c, r) => Cell(formatPaise(r.i('amount')), bold: true), width: 110, numeric: true),
      ],
      phoneTitle: (c, r) => TitleAmount(r.s('dealer'), '₹ ${formatPaise(r.i('amount'))}'),
      phoneSubtitle: (r) => '${r.s('no')} · ${r.s('purchase')} · ${r.s('reason')}',
    );
  }
}

class DeliveryScreen extends ConsumerWidget {
  const DeliveryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(recsProvider('delivery'));
    final th = Theme.of(context).textTheme;
    (String, BadgeKind) st(String s) => switch (s) { 'pending' => (l.deliveryPending, BadgeKind.warning), 'out' => (l.deliveryOut, BadgeKind.info), _ => (l.statusDelivered, BadgeKind.success) };
    Widget badge(Rec r) {
      final (t, k) = st(r.s('status'));
      return StatusBadge(t, kind: k);
    }

    return DataListScreen<Rec>(
      title: l.navDelivery,
      subtitle: l.deliverySubtitle,
      items: items,
      searchText: (r) => '${r.s('bill')} ${r.s('customer')} ${r.s('address')}',
      filters: [FilterSpec(l.deliveryPending, (r) => r.s('status') == 'pending'), FilterSpec(l.deliveryOut, (r) => r.s('status') == 'out'), FilterSpec(l.statusDelivered, (r) => r.s('status') == 'delivered')],
      columns: [
        ColumnSpec(l.colBillNo, (c, r) => Cell(r.s('bill'), bold: true), width: 110),
        ColumnSpec(l.colDate, (c, r) => Cell(_d(r, 'date'), muted: true), width: 100),
        ColumnSpec(l.colCustomer, (c, r) => Cell(r.s('customer')), flex: 3),
        ColumnSpec(l.fieldAddress, (c, r) => Cell(r.s('address'), muted: true), flex: 4),
        ColumnSpec(l.colStatus, (c, r) => badge(r), width: 130),
      ],
      phoneTitle: (c, r) => Text(r.s('customer'), style: th.titleSmall),
      phoneSubtitle: (r) => '${r.s('bill')}\n${r.s('address')}',
      phoneTrailing: (c, r) => badge(r),
      onTap: (ctx, r) => showDetail(ctx, title: r.s('bill'), subtitle: r.s('customer'), body: [KeyValue(l.fieldAddress, r.s('address')), KeyValue(l.colStatus, st(r.s('status')).$1, bold: true)], actions: [
        if (r.s('status') == 'pending') FilledButton.icon(onPressed: () { ref.read(recsProvider('delivery').notifier).replace(r.with_({'status': 'out'})); Navigator.of(ctx, rootNavigator: true).pop(); toast(context, l.saved); }, icon: const Icon(Icons.local_shipping_outlined), label: Text(l.markOut)),
        if (r.s('status') == 'out') FilledButton.icon(onPressed: () { ref.read(recsProvider('delivery').notifier).replace(r.with_({'status': 'delivered'})); Navigator.of(ctx, rootNavigator: true).pop(); toast(context, l.saved); }, icon: const Icon(Icons.check), label: Text(l.markDelivered)),
      ]),
    );
  }
}

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(recsProvider('expenses'));
    final now = ref.watch(clockProvider);
    final month = items.where((r) => (r.f['date'] as DateTime).month == now.month && (r.f['date'] as DateTime).year == now.year).fold<int>(0, (s, r) => s + r.i('amount'));
    final today = items.where((r) => formatDate(r.f['date'] as DateTime) == formatDate(now)).fold<int>(0, (s, r) => s + r.i('amount'));
    return DataListScreen<Rec>(
      title: l.navExpenses,
      subtitle: l.expensesSubtitle,
      items: items,
      searchText: (r) => '${r.s('category')} ${r.s('note')}',
      addLabel: l.addExpense,
      onAdd: () async {
        final v = await showFormSheet(context, title: l.addExpense, saveLabel: l.save, fields: [
          FieldSpec('category', l.fieldCategory, type: FieldType.dropdown, initial: 'Shop rent', options: [for (final c in ['Shop rent', 'Electricity', 'Staff salary', 'Transport', 'Tea and snacks', 'Repairs', 'Phone and internet', 'Packing material']) (c, c)]),
          FieldSpec('amount', l.fieldAmount, type: FieldType.money, required: true, autofocus: true),
          FieldSpec('note', l.fieldNote),
        ]);
        if (v == null) return;
        ref.read(recsProvider('expenses').notifier).add(Rec(newId(), {'date': now, 'category': v['category']!, 'note': v['note'] ?? '', 'amount': ((double.tryParse(v['amount']!) ?? 0) * 100).round()}));
        if (context.mounted) toast(context, l.saved);
      },
      stats: [StatCard(label: l.statExpToday, value: '₹ ${formatPaise(today)}', icon: Icons.today_outlined), StatCard(label: l.statExpMonth, value: '₹ ${formatPaise(month)}', icon: Icons.calendar_month_outlined, tone: context.c.warning)],
      columns: [
        ColumnSpec(l.colDate, (c, r) => Cell(_d(r, 'date'), muted: true), width: 100),
        ColumnSpec(l.fieldCategory, (c, r) => Cell(r.s('category'), bold: true), flex: 2),
        ColumnSpec(l.fieldNote, (c, r) => Cell(r.s('note'), muted: true), flex: 3),
        ColumnSpec(l.colAmount, (c, r) => Cell(formatPaise(r.i('amount')), bold: true), width: 120, numeric: true),
      ],
      phoneTitle: (c, r) => TitleAmount(r.s('category'), '₹ ${formatPaise(r.i('amount'))}'),
      phoneSubtitle: (r) => '${_d(r, 'date')} · ${r.s('note')}',
    );
  }
}

class WarrantyScreen extends ConsumerWidget {
  const WarrantyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(recsProvider('warranty'));
    final now = ref.watch(clockProvider);
    final th = Theme.of(context).textTheme;
    bool active(Rec r) => (r.f['till'] as DateTime).isAfter(now);
    Widget badge(Rec r) => active(r) ? StatusBadge(l.warrantyActive, kind: BadgeKind.success) : StatusBadge(l.warrantyEnded, kind: BadgeKind.neutral);
    return DataListScreen<Rec>(
      title: l.navWarranty,
      subtitle: l.warrantySubtitle,
      items: items,
      searchText: (r) => '${r.s('customer')} ${r.s('item')} ${r.s('serial')}',
      searchHint: l.searchWarrantyHint,
      filters: [FilterSpec(l.warrantyActive, active), FilterSpec(l.warrantyEnded, (r) => !active(r))],
      columns: [
        ColumnSpec(l.colCustomer, (c, r) => Cell(r.s('customer'), bold: true), flex: 3),
        ColumnSpec(l.colProduct, (c, r) => Cell(r.s('item')), flex: 4),
        ColumnSpec(l.fieldSerial, (c, r) => Cell(r.s('serial'), muted: true), width: 110),
        ColumnSpec(l.colWarrantyTill, (c, r) => Cell(_d(r, 'till'), muted: true), width: 110),
        ColumnSpec(l.colStatus, (c, r) => badge(r), width: 110),
      ],
      phoneTitle: (c, r) => Text(r.s('item'), style: th.titleSmall),
      phoneSubtitle: (r) => '${r.s('customer')}\n${l.colWarrantyTill}: ${_d(r, 'till')}',
      phoneTrailing: (c, r) => badge(r),
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(recsProvider('notifications'));
    final th = Theme.of(context).textTheme;
    IconData icon(String k) => switch (k) { 'stock' => Icons.inventory_2_outlined, 'money' => Icons.account_balance_wallet_outlined, 'backup' => Icons.save_alt, 'sync' => Icons.cloud_done_outlined, 'warranty' => Icons.verified_user_outlined, _ => Icons.request_quote_outlined };
    return PageFrame(
      title: l.navNotifications,
      subtitle: l.notificationsSubtitle,
      actions: [OutlinedButton.icon(onPressed: () { for (final r in items) { ref.read(recsProvider('notifications').notifier).replace(r.with_({'read': 1})); } }, icon: const Icon(Icons.done_all), label: Text(l.markAllRead))],
      child: items.isEmpty
          ? EmptyState(icon: Icons.notifications_none, title: l.noNotifications, text: l.noNotificationsHelp)
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final r = items[i];
                final unread = r.i('read') == 0;
                return Card(
                  child: ListTile(
                    leading: Icon(icon(r.s('kind')), color: unread ? context.c.primary : context.c.textMuted),
                    title: Text(r.s('text'), style: unread ? th.titleSmall : th.bodyMedium),
                    subtitle: Text(formatDateTime(r.f['time'] as DateTime)),
                    trailing: unread ? StatusBadge(l.newLabel, kind: BadgeKind.info) : null,
                  ),
                );
              },
            ),
    );
  }
}
