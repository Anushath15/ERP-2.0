import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/cloud/sync_controller.dart';
import '../../core/data_mode.dart';
import '../../core/update_check.dart';
import '../../data/platform/disk_space.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../data/backup/backup_types.dart';
import '../../fake/backup_controller.dart';
import '../../fake/data_providers.dart';
import '../../fake/health.dart';

/// A calm strip at the top of every page, only when something needs attention: a save that failed, a disk that is getting full.
/// With nothing wrong it takes no room at all.
class ProblemBanner extends ConsumerWidget {
  const ProblemBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final error = ref.watch(writeErrorProvider);
    final disk = ref.watch(diskLevelProvider);
    final demo = ref.watch(appModeProvider) == DataMode.demo;
    final selfCheck = ref.watch(selfCheckProblemsProvider);
    final sync = ref.watch(syncProvider);
    final c = context.c;
    final bk = ref.watch(backupControllerProvider);
    final update = ref.watch(updateProvider);
    final now = DateTime.now();
    final prevFy = previousFinancialYear(now);
    final yearlyDue = ref.read(backupControllerProvider.notifier).available && now.month >= 4 && now.month <= 6 && !ref.watch(backupListProvider).any((b) => b.kind == BackupKind.archive && b.fy == prevFy) && (ref.watch(backupListProvider).isNotEmpty);
    final items = <(String, Color, VoidCallback?, String?)>[
      if (error != null) (error, c.danger, () => ref.read(writeErrorProvider.notifier).set(null), null),
      if (demo) (l.demoBanner, c.info, () => unawaited(ref.read(modeSwitcherProvider)(DataMode.real)), l.demoLeave),
      if (sync.newFromCloud) (l.syncNewData, c.info, () => unawaited(ref.read(modeSwitcherProvider)(DataMode.real)), l.syncReload),
      if (selfCheck.isNotEmpty) (l.selfCheckBanner(selfCheck.length.toString()), c.warning, () => ref.read(selfCheckProblemsProvider.notifier).set(const []), null),
      if (disk == DiskLevel.low) (l.diskLowBanner, c.warning, null, null),
      if (disk == DiskLevel.full) (l.diskFullBanner, c.danger, null, null),
      if (bk.lastError != null) (l.backupFailed(bk.lastError!), c.danger, () => ref.read(backupControllerProvider.notifier).dismissError(), null),
      if (yearlyDue) (l.backupYearlyReminder(prevFy), c.info, () => context.go('/backups'), l.backupYearlyGo),
      if (update != null) (l.updateReady(update.version), c.info, () => context.go('/about'), l.updateSee),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (final i in items)
        Container(
          key: ValueKey('banner-${i.$1.hashCode}'),
          width: double.infinity,
          color: i.$2.withValues(alpha: 0.14),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: i.$2),
            const SizedBox(width: 10),
            Expanded(child: Text(i.$1, style: Theme.of(context).textTheme.bodyMedium)),
            if (i.$3 != null) TextButton(onPressed: i.$3, child: Text(i.$4 ?? l.dismiss)),
          ]),
        ),
    ]);
  }
}
