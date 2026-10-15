import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data_mode.dart';
import '../../data/platform/disk_space.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
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
    final c = context.c;
    final items = <(String, Color, VoidCallback?)>[
      if (error != null) (error, c.danger, () => ref.read(writeErrorProvider.notifier).set(null)),
      if (demo) (l.demoBanner, c.info, () => unawaited(ref.read(modeSwitcherProvider)(DataMode.real))),
      if (selfCheck.isNotEmpty) (l.selfCheckBanner(selfCheck.length.toString()), c.warning, () => ref.read(selfCheckProblemsProvider.notifier).set(const [])),
      if (disk == DiskLevel.low) (l.diskLowBanner, c.warning, null),
      if (disk == DiskLevel.full) (l.diskFullBanner, c.danger, null),
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
            if (i.$3 != null) TextButton(onPressed: i.$3, child: Text(i.$1 == l.demoBanner ? l.demoLeave : l.dismiss)),
          ]),
        ),
    ]);
  }
}
