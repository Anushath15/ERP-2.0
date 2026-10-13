import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../design/data_list.dart';
import '../../design/detail_sheet.dart';
import '../../design/form_sheet.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/models.dart';
import '../../fake/store.dart';

Future<void> _receivePayment(BuildContext context, String who, int due) async {
  final l = tr(context);
  final v = await showFormSheet(context, title: l.receivePayment, saveLabel: l.savePayment, note: l.paymentFrom(who), fields: [
    FieldSpec('amount', l.fieldAmount, type: FieldType.money, initial: (due / 100).toStringAsFixed(2), required: true, autofocus: true),
    FieldSpec('mode', l.fieldPayMode, type: FieldType.dropdown, initial: 'cash', options: [('cash', l.payCash), ('upi', l.payUpi), ('card', l.payCard)]),
    FieldSpec('note', l.fieldNote),
  ]);
  if (v != null && context.mounted) toast(context, l.paymentSaved(formatPaise(((double.tryParse(v['amount'] ?? '') ?? 0) * 100).round(), symbol: true)));
}

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(customersProvider);
    final th = Theme.of(context).textTheme;
    final owing = items.where((c) => c.balancePaise > 0).length;
    return DataListScreen<Customer>(
      title: l.navCustomers,
      subtitle: l.customersSubtitle(items.length.toString(), owing.toString()),
      items: items,
      searchText: (c) => '${c.name} ${c.phone} ${c.city}',
      searchHint: l.searchCustomerHint,
      addLabel: l.addCustomer,
      onAdd: () async {
        final v = await showFormSheet(context, title: l.addCustomer, saveLabel: l.save, fields: [
          FieldSpec('name', l.fieldName, required: true, autofocus: true),
          FieldSpec('phone', l.fieldPhone, type: FieldType.phone),
          FieldSpec('city', l.fieldCity),
          FieldSpec('limit', l.fieldCreditLimit, type: FieldType.money, initial: '50000'),
        ]);
        if (v != null) {
          ref.read(customersProvider.notifier).add(Customer(id: 'c-new-${items.length}', name: v['name']!, phone: v['phone'] ?? '', city: v['city'] ?? '', balancePaise: 0));
          if (context.mounted) toast(context, l.saved);
        }
      },
      filters: [FilterSpec(l.filterOwing, (c) => c.balancePaise > 0), FilterSpec(l.filterClear, (c) => c.balancePaise == 0)],
      sorts: [(l.sortOwedHigh, (a, b) => b.balancePaise.compareTo(a.balancePaise))],
      columns: [
        ColumnSpec(l.fieldName, (c, x) => Text(x.name, style: th.titleSmall), flex: 4),
        ColumnSpec(l.fieldPhone, (c, x) => Cell(x.phone, muted: true), width: 120),
        ColumnSpec(l.fieldCity, (c, x) => Cell(x.city, muted: true), flex: 2),
        ColumnSpec(l.colOwes, (c, x) => x.balancePaise > 0 ? StatusBadge(formatPaise(x.balancePaise, symbol: true), kind: BadgeKind.warning) : const Cell('-', muted: true), width: 140, numeric: true),
      ],
      phoneTitle: (c, x) => Text(x.name, style: th.titleSmall),
      phoneSubtitle: (x) => '${x.phone}  ·  ${x.city}',
      phoneTrailing: (c, x) => x.balancePaise > 0 ? StatusBadge(formatPaise(x.balancePaise, symbol: true), kind: BadgeKind.warning) : const SizedBox.shrink(),
      onTap: (ctx, x) => showDetail(ctx, title: x.name, subtitle: x.city, body: [
        KeyValue(l.fieldPhone, x.phone),
        KeyValue(l.fieldCreditLimit, formatPaise(x.creditLimitPaise, symbol: true)),
        KeyValue(l.colOwes, formatPaise(x.balancePaise, symbol: true), bold: true),
        const SizedBox(height: 8),
        Text(l.recentBills, style: th.titleSmall),
        for (var i = 0; i < 3; i++) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text('A-0199${80 - i * 7}', style: th.bodyMedium)), Text('₹ ${formatPaise(120000 + i * 87500)}', style: th.bodyMedium)])),
      ], actions: [
        if (x.balancePaise > 0) FilledButton.icon(onPressed: () { Navigator.pop(ctx); _receivePayment(context, x.name, x.balancePaise); }, icon: const Icon(Icons.payments_outlined), label: Text(l.receivePayment)),
      ]),
    );
  }
}

class CreditScreen extends ConsumerWidget {
  const CreditScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final all = ref.watch(customersProvider);
    final owing = [for (final c in all) if (c.balancePaise > 0) c]..sort((a, b) => b.balancePaise.compareTo(a.balancePaise));
    final total = owing.fold<int>(0, (s, c) => s + c.balancePaise);
    final dealers = ref.watch(recsProvider('dealers'));
    final weOwe = dealers.fold<int>(0, (s, d) => s + d.i('balance'));
    final th = Theme.of(context).textTheme;
    return DataListScreen<Customer>(
      title: l.navCredit,
      subtitle: l.creditSubtitle,
      items: owing,
      searchText: (c) => '${c.name} ${c.phone}',
      stats: [
        StatCard(label: l.statToCollect, value: '₹ ${formatPaise(total)}', icon: Icons.south_west, tone: context.c.warning),
        StatCard(label: l.statCustomersOwing, value: owing.length.toString(), icon: Icons.people_outline),
        StatCard(label: l.statWeOwe, value: '₹ ${formatPaise(weOwe)}', icon: Icons.north_east, tone: context.c.danger, hint: l.toDealers),
      ],
      columns: [
        ColumnSpec(l.fieldName, (c, x) => Text(x.name, style: th.titleSmall), flex: 4),
        ColumnSpec(l.fieldPhone, (c, x) => Cell(x.phone, muted: true), width: 120),
        ColumnSpec(l.colOwes, (c, x) => Cell(formatPaise(x.balancePaise, symbol: true), bold: true, color: c.c.warning), width: 140, numeric: true),
        ColumnSpec('', (c, x) => FilledButton.tonal(onPressed: () => _receivePayment(c, x.name, x.balancePaise), child: Text(l.receivePayment)), width: 170, numeric: true),
      ],
      phoneTitle: (c, x) => Text(x.name, style: th.titleSmall),
      phoneSubtitle: (x) => x.phone,
      phoneTrailing: (c, x) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(formatPaise(x.balancePaise, symbol: true), style: th.titleSmall?.copyWith(color: c.c.warning)), TextButton(onPressed: () => _receivePayment(c, x.name, x.balancePaise), child: Text(l.receivePayment))]),
      emptyTitle: l.nobodyOwes,
      emptyIcon: Icons.celebration_outlined,
    );
  }
}

class DealersScreen extends ConsumerWidget {
  const DealersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(recsProvider('dealers'));
    final th = Theme.of(context).textTheme;
    return DataListScreen<Rec>(
      title: l.navDealers,
      subtitle: l.dealersSubtitle,
      items: items,
      searchText: (r) => '${r.s('name')} ${r.s('phone')} ${r.s('city')}',
      addLabel: l.addDealer,
      onAdd: () async {
        final v = await showFormSheet(context, title: l.addDealer, saveLabel: l.save, fields: [FieldSpec('name', l.fieldName, required: true, autofocus: true), FieldSpec('phone', l.fieldPhone, type: FieldType.phone), FieldSpec('city', l.fieldCity)]);
        if (v != null) ref.read(recsProvider('dealers').notifier).add(Rec('d-new-${items.length}', {'name': v['name']!, 'phone': v['phone'] ?? '', 'city': v['city'] ?? '', 'balance': 0}));
      },
      filters: [FilterSpec(l.filterWeOwe, (r) => r.i('balance') > 0)],
      columns: [
        ColumnSpec(l.fieldName, (c, r) => Text(r.s('name'), style: th.titleSmall), flex: 4),
        ColumnSpec(l.fieldPhone, (c, r) => Cell(r.s('phone'), muted: true), width: 120),
        ColumnSpec(l.fieldCity, (c, r) => Cell(r.s('city'), muted: true), flex: 2),
        ColumnSpec(l.colWeOwe, (c, r) => r.i('balance') > 0 ? StatusBadge(formatPaise(r.i('balance'), symbol: true), kind: BadgeKind.danger) : const Cell('-', muted: true), width: 140, numeric: true),
      ],
      phoneTitle: (c, r) => Text(r.s('name'), style: th.titleSmall),
      phoneSubtitle: (r) => '${r.s('phone')}  ·  ${r.s('city')}',
      phoneTrailing: (c, r) => r.i('balance') > 0 ? StatusBadge(formatPaise(r.i('balance'), symbol: true), kind: BadgeKind.danger) : const SizedBox.shrink(),
      onTap: (ctx, r) => showDetail(ctx, title: r.s('name'), subtitle: r.s('city'), body: [KeyValue(l.fieldPhone, r.s('phone')), KeyValue(l.colWeOwe, formatPaise(r.i('balance'), symbol: true), bold: true)], actions: [
        if (r.i('balance') > 0) FilledButton.icon(onPressed: () { Navigator.pop(ctx); toast(context, l.paymentSaved(formatPaise(r.i('balance'), symbol: true))); }, icon: const Icon(Icons.payments_outlined), label: Text(l.payDealer)),
      ]),
    );
  }
}

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(recsProvider('staff'));
    final th = Theme.of(context).textTheme;
    String role(String r) => switch (r) { 'owner' => l.roleOwner, 'manager' => l.roleManager, _ => l.roleCashier };
    String roleHelp(String r) => switch (r) { 'owner' => l.roleOwnerHelp, 'manager' => l.roleManagerHelp, _ => l.roleCashierHelp };
    return DataListScreen<Rec>(
      title: l.navStaff,
      subtitle: l.staffSubtitle,
      items: items,
      searchText: (r) => '${r.s('name')} ${r.s('email')}',
      addLabel: l.addStaff,
      onAdd: () async {
        final v = await showFormSheet(context, title: l.addStaff, saveLabel: l.save, note: l.addStaffNote, fields: [
          FieldSpec('email', l.fieldEmail, type: FieldType.email, required: true, autofocus: true),
          FieldSpec('name', l.fieldName, required: true),
          FieldSpec('role', l.fieldRole, type: FieldType.dropdown, initial: 'cashier', options: [('manager', l.roleManager), ('cashier', l.roleCashier)]),
        ]);
        if (v != null) ref.read(recsProvider('staff').notifier).add(Rec('s-new-${items.length}', {'name': v['name']!, 'email': v['email']!, 'role': v['role']!}));
      },
      columns: [
        ColumnSpec(l.fieldName, (c, r) => Text(r.s('name'), style: th.titleSmall), flex: 3),
        ColumnSpec(l.fieldEmail, (c, r) => Cell(r.s('email'), muted: true), flex: 3),
        ColumnSpec(l.fieldRole, (c, r) => StatusBadge(role(r.s('role')), kind: r.s('role') == 'owner' ? BadgeKind.info : BadgeKind.neutral), width: 120),
        ColumnSpec(l.canDo, (c, r) => Cell(roleHelp(r.s('role')), muted: true), flex: 4),
      ],
      phoneTitle: (c, r) => Text(r.s('name'), style: th.titleSmall),
      phoneSubtitle: (r) => '${r.s('email')}\n${roleHelp(r.s('role'))}',
      phoneTrailing: (c, r) => StatusBadge(role(r.s('role')), kind: r.s('role') == 'owner' ? BadgeKind.info : BadgeKind.neutral),
      onTap: (ctx, r) => showDetail(ctx, title: r.s('name'), subtitle: r.s('email'), body: [KeyValue(l.fieldRole, role(r.s('role')), bold: true), KeyValue(l.canDo, roleHelp(r.s('role'))), const SizedBox(height: 8), Text(l.removeAccessHelp, style: th.bodySmall)], actions: [
        if (r.s('role') != 'owner') OutlinedButton.icon(onPressed: () async { Navigator.pop(ctx); final ok = await confirmDialog(context, title: l.removeAccess, message: l.removeAccessConfirm(r.s('name')), confirmLabel: l.removeAccess, danger: true); if (ok) ref.read(recsProvider('staff').notifier).remove(r.id); }, icon: const Icon(Icons.person_remove_outlined), label: Text(l.removeAccess)),
      ]),
    );
  }
}
