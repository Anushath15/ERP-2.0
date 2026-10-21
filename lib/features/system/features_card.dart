import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/widgets.dart';
import '../../fake/store.dart';

/// Settings > Features: switch a part of the program off on this computer (it is only hidden; nothing is deleted).
class FeaturesCard extends ConsumerWidget {
  const FeaturesCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier).set;
    String label(AppFeature f) => switch (f) { AppFeature.counterLink => l.featCounterLink, AppFeature.excelFill => l.featExcel, AppFeature.brandSwitch => l.featBrandSwitch };
    return SectionCard(
      title: l.featTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.featHelp, style: Theme.of(context).textTheme.bodySmall),
        for (final f in AppFeature.values)
          SwitchListTile(
            key: ValueKey('feature-${f.name}'),
            contentPadding: EdgeInsets.zero,
            title: Text(label(f)),
            value: s.featureOn(f),
            onChanged: (on) => set((x) => x.copyWith(featuresOff: on ? ({...x.featuresOff}..remove(f.name)) : {...x.featuresOff, f.name})),
          ),
      ]),
    );
  }
}
