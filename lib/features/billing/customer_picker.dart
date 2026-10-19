import '../../data/ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../design/motion.dart';
import '../../design/widgets.dart';
import '../../fake/models.dart';
import '../../fake/credit_store.dart';
import '../../fake/store.dart';
import 'billing_screen.dart' show showQuickCustomer;

Future<Customer?> showCustomerPickerImpl(BuildContext context) {
  const body = _CustomerPicker();
  if (context.isPhone) {
    return showModalBottomSheet<Customer>(
      context: context,
      sheetAnimationStyle: dialogStyle(context), isScrollControlled: true, useSafeArea: true, builder: (_) => body);
  }
  return showDialog<Customer>(
    context: context,
    animationStyle: dialogStyle(context), builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680), child: body)));
}

class _CustomerPicker extends ConsumerStatefulWidget {
  const _CustomerPicker();
  @override
  ConsumerState<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<_CustomerPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final all = ref.watch(customersProvider);
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty ? all : all.where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q)).toList();
    final th = Theme.of(context).textTheme;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(children: [
          Expanded(child: Text(l.chooseCustomer, style: th.titleLarge)),
          IconButton(tooltip: l.close, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          Expanded(child: SearchField(hint: l.searchCustomerHint, autofocus: !context.isPhone, onChanged: (v) => setState(() => _q = v))),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final v = await showQuickCustomer(context);
              if (v == null) return;
              final c = Customer(id: newId(), name: v['name']!, phone: v['phone'] ?? '', city: v['city'] ?? '', gstin: v['gstin'] ?? '', balancePaise: 0);
              ref.read(customersProvider.notifier).add(c);
              if (context.mounted) Navigator.pop(context, c);
            },
            icon: const Icon(Icons.person_add_alt_rounded),
            label: Text(context.isPhone ? l.add : l.addCustomer),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: list.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(l.walkInCustomer, style: th.titleSmall),
                onTap: () => Navigator.pop(context, const Customer(id: '__walkin', name: '', phone: '', city: '', balancePaise: 0)),
              );
            }
            final c = list[i - 1];
            return ListTile(
              title: Text(c.name, style: th.titleSmall),
              subtitle: Text('${c.phone}  ·  ${c.city}'),
              trailing: (ref.watch(creditProvider)[c.id]?.balance ?? 0) > 0 ? StatusBadge(formatPaise(ref.watch(creditProvider)[c.id]!.balance, symbol: true), kind: BadgeKind.warning) : null,
              onTap: () => Navigator.pop(context, c),
            );
          },
        ),
      ),
    ]);
  }
}
