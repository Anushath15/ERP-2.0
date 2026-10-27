import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../data/repo/records_repo.dart';
import '../../design/widgets.dart';
import '../../fake/data_providers.dart';
import '../../fake/store.dart';
import '../../strings.dart';

/// What is in the Trash, newest first; read again after every restore.
final trashProvider = FutureProvider.autoDispose<List<TrashItem>>((ref) => ref.read(appDataProvider).trash.list());

String trashKindLabel(Strings l, String kind) => switch (kind) {
      'estimate' => l.trashKindEstimate,
      'expenses' => l.navExpenses,
      'staff' => l.navStaff,
      'brands' => l.navBrands,
      'units' => l.trashKindUnit,
      'warranty' => l.navWarranty,
      'delivery' => l.trashKindDelivery,
      'notifications' => l.navNotifications,
      'orders' => l.trashKindOrder,
      _ => kind,
    };

/// Trash: everything that was deleted, with Restore. Nothing is ever really removed, so a mistake can always be undone.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final items = ref.watch(trashProvider);
    Future<void> restore(TrashItem t) async {
      final ok = await ref.read(appDataProvider).trash.restore(t);
      if (t.kind == 'estimate') {
        await ref.read(estimationsProvider.notifier).reload();
      } else {
        await ref.read(recsProvider(t.kind).notifier).reload();
      }
      ref.invalidate(trashProvider);
      if (context.mounted) toast(context, ok ? l.trashRestored(t.title) : l.trashGone);
    }

    return PageFrame(
      title: l.navTrash,
      subtitle: l.trashSubtitle,
      child: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: l.trashGone),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.delete_outline_rounded, title: l.trashEmpty, text: l.trashEmptyHelp)
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final t = list[i];
                  return Card(
                    child: ListTile(
                      key: ValueKey('trash-${t.id}'),
                      leading: const Icon(Icons.delete_outline_rounded),
                      title: Text(t.title, style: th.titleSmall),
                      subtitle: Text([trashKindLabel(l, t.kind), if (t.detail.isNotEmpty) t.detail, if (t.amountPaise != 0) formatPaise(t.amountPaise, symbol: true), l.trashDeletedOn(formatDateTime(t.deletedAt))].join('  ·  ')),
                      trailing: OutlinedButton.icon(key: ValueKey('trash-restore-${t.id}'), onPressed: () => restore(t), icon: const Icon(Icons.restore_rounded), label: Text(l.trashRestore)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
