import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/cloud/sync_controller.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/data_providers.dart';

/// Under Settings > Sync: how many documents went to the cloud today, and (when there are any) which ones the cloud refused and why, with a button to try them again.
class SyncDetails extends ConsumerWidget {
  const SyncDetails({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final c = context.c;
    ref.watch(syncProvider); // read again after every round
    final repo = ref.read(appDataProvider).outbox;
    return FutureBuilder<(int, List<({String coll, String docId, String error, int attempts})>)>(
      future: Future.wait<Object>([repo.sentToday(), repo.refused(limit: 6)]).then((r) => (r[0] as int, r[1] as List<({String coll, String docId, String error, int attempts})>)),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return const SizedBox.shrink();
        final (sent, refused) = data;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l.syncSentToday('$sent'), key: const ValueKey('syncSentToday'), style: th.bodyMedium)),
          if (refused.isNotEmpty) ...[
            Text(l.syncRefused, style: th.titleSmall?.copyWith(color: c.danger)),
            for (final r in refused) Padding(padding: const EdgeInsets.only(top: 3), child: Text(l.syncRefusedLine(r.coll.replaceAll('_', ' '), r.error.isEmpty ? '-' : r.error), style: th.bodySmall)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              key: const ValueKey('syncRetry'),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l.syncRetry),
              onPressed: () async {
                await repo.retryRefused();
                await ref.read(syncProvider.notifier).syncNow();
              },
            ),
          ],
          const SizedBox(height: 6),
        ]);
      },
    );
  }
}
