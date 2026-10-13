import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/money.dart';
import '../../design/data_list.dart';
import '../../design/detail_sheet.dart';
import '../../design/form_sheet.dart';
import '../../design/widgets.dart';
import '../../fake/models.dart';
import '../../fake/credit_store.dart';
import '../../fake/store.dart';
import '../billing/billing_screen.dart' show showQuickCustomer;

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(customersProvider);
    final credit = ref.watch(creditProvider);
    int bal(Customer c) => credit[c.id]?.balance ?? 0;
    final th = Theme.of(context).textTheme;
    final owing = items.where((c) => bal(c) > 0).length;
    Widget badge(Customer x) {
      final b = bal(x);
      if (b > 0) return StatusBadge(formatPaise(b, symbol: true), kind: BadgeKind.warning);
      if (b < 0) return StatusBadge(l.advanceAmount(formatPaise(-b, symbol: true)), kind: BadgeKind.success);
      return const SizedBox.shrink();
    }

    return DataListScreen<Customer>(
      title: l.navCustomers,
      subtitle: l.customersSubtitle(items.length.toString(), owing.toString()),
      items: items,
      searchText: (c) => '${c.name} ${c.phone} ${c.city}',
      searchHint: l.searchCustomerHint,
      addLabel: l.addCustomer,
      onAdd: () async {
        final v = await showQuickCustomer(context);
        if (v != null) {
          ref.read(customersProvider.notifier).add(Customer(id: 'c-new-${items.length}', name: v['name']!, phone: v['phone'] ?? '', city: v['city'] ?? '', balancePaise: 0));
          if (context.mounted) toast(context, l.saved);
        }
      },
      filters: [FilterSpec(l.filterOwing, (c) => bal(c) > 0), FilterSpec(l.filterAdvance, (c) => bal(c) < 0), FilterSpec(l.filterClear, (c) => bal(c) == 0)],
      sorts: [(l.sortOwedHigh, (a, b) => bal(b).compareTo(bal(a)))],
      columns: [
        ColumnSpec(l.fieldName, (c, x) => Text(x.name, style: th.titleSmall), flex: 4),
        ColumnSpec(l.fieldPhone, (c, x) => Cell(x.phone.isEmpty ? l.custNoNumber : x.phone, muted: true), width: 120),
        ColumnSpec(l.fieldCity, (c, x) => Cell(x.city, muted: true), flex: 2),
        ColumnSpec(l.colOwes, (c, x) => bal(x) == 0 ? const Cell('-', muted: true) : badge(x), width: 150, numeric: true),
      ],
      phoneTitle: (c, x) => Text(x.name, style: th.titleSmall),
      phoneSubtitle: (x) => '${x.phone.isEmpty ? l.custNoNumber : x.phone}  ·  ${x.city}',
      phoneTrailing: (c, x) => badge(x),
      onTap: (ctx, x) => ctx.go('/customers/${x.id}'),
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
