import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/motion_level.dart';
import '../../design/segments.dart';
import '../../design/text_zoom.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/store.dart';

class _Group extends StatelessWidget {
  const _Group({required this.title, this.help, required this.child});
  final String title;
  final String? help;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: th.titleSmall),
        if (help != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(help!, style: th.bodySmall)),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

/// A bill row as it looks in billing, so text-size changes can be judged on the real thing.
class SampleBillRow extends StatelessWidget {
  const SampleBillRow({super.key, required this.scale});
  final double scale;
  @override
  Widget build(BuildContext context) {
    return TextScaleBy(
      factor: scale,
      child: Builder(builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: ctx.c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: ctx.c.border.withValues(alpha: 0.6))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text('1 1/2" X 125MM WOOD SCREW BOX', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(width: 12),
            Text('₹ 207.50', style: t.titleMedium?.copyWith(color: ctx.c.primary)),
          ]),
        );
      }),
    );
  }
}

class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier).set;
    final th = Theme.of(context).textTheme;
    final c = context.c;
    final zoomPercent = TextZoom.label(s.textScale);

    return SectionCard(
      title: l.setAppearance,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Group(
          title: l.setTheme,
          child: SlideSegments<ThemeMode>(
            options: [(ThemeMode.dark, l.themeDark, Icons.dark_mode_rounded), (ThemeMode.light, l.themeLight, Icons.light_mode_rounded), (ThemeMode.system, l.themeSystem, Icons.brightness_auto_rounded)],
            selected: s.theme,
            onChanged: (v) => set((x) => x.copyWith(theme: v)),
          ),
        ),
        _Group(
          title: l.setAccent,
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (final a in Accent.values)
              Semantics(
                button: true,
                selected: s.accent == a,
                label: l.accentName(a.label),
                child: InkWell(
                  key: ValueKey('accent-${a.name}'),
                  customBorder: const CircleBorder(),
                  onTap: () => set((x) => x.copyWith(accent: a)),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).brightness == Brightness.dark ? a.dark : a.light,
                      border: Border.all(color: s.accent == a ? c.text : c.border, width: s.accent == a ? 3 : 1),
                    ),
                    child: s.accent == a ? Icon(Icons.check_rounded, color: contrastRatio(Colors.black, Theme.of(context).brightness == Brightness.dark ? a.dark : a.light) > 4.5 ? Colors.black : Colors.white) : null,
                  ),
                ),
              ),
          ]),
        ),
        _Group(
          title: l.setHighContrast,
          help: l.setHighContrastHelp,
          child: Align(alignment: Alignment.centerLeft, child: Switch(value: s.highContrast, onChanged: (v) => set((x) => x.copyWith(highContrast: v)))),
        ),
        const Divider(),
        const SizedBox(height: 14),
        _Group(
          title: '${l.setTextSize}: $zoomPercent',
          help: l.setTextSizeHelp,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(tooltip: l.textSmaller, onPressed: () => set((x) => x.copyWith(textScale: TextZoom.down(x.textScale))), icon: const Icon(Icons.text_decrease_rounded)),
              Expanded(
                child: Slider(
                  key: const ValueKey('textSlider'),
                  value: s.textScale.clamp(TextZoom.min, TextZoom.max),
                  min: TextZoom.min,
                  max: TextZoom.max,
                  divisions: 24,
                  label: zoomPercent,
                  onChanged: (v) => set((x) => x.copyWith(textScale: (v * 20).round() / 20)),
                ),
              ),
              IconButton(tooltip: l.textLarger, onPressed: () => set((x) => x.copyWith(textScale: TextZoom.up(x.textScale))), icon: const Icon(Icons.text_increase_rounded)),
            ]),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in [(l.sizeSmall, 0.9), (l.sizeNormal, 1.0), (l.sizeLarge, 1.25), (l.sizeExtraLarge, 1.5), (l.sizeHuge, 2.0)])
                ChoiceChip(label: Text('${p.$1} ${TextZoom.label(p.$2)}'), selected: (s.textScale - p.$2).abs() < 0.001, onSelected: (_) => set((x) => x.copyWith(textScale: p.$2))),
            ]),
            const SizedBox(height: 10),
            Text(l.textPreview, style: th.bodyLarge),
            const SizedBox(height: 8),
            const SampleBillRow(scale: 1.0),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => set((x) => x.copyWith(textScale: 1.0)), icon: const Icon(Icons.restart_alt_rounded), label: Text(l.resetNormal))),
          ]),
        ),
        _Group(
          title: '${l.setBillingText}: ${TextZoom.label(s.billingScale)}',
          help: l.setBillingTextHelp,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Slider(
              key: const ValueKey('billingSlider'),
              value: s.billingScale.clamp(0.8, 2.5),
              min: 0.8,
              max: 2.5,
              divisions: 34,
              label: TextZoom.label(s.billingScale),
              onChanged: (v) => set((x) => x.copyWith(billingScale: (v * 20).round() / 20)),
            ),
            SampleBillRow(scale: s.billingScale),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => set((x) => x.copyWith(billingScale: 1.0)), icon: const Icon(Icons.restart_alt_rounded), label: Text(l.resetNormal))),
          ]),
        ),
        _Group(
          title: l.setDensity,
          help: l.setDensityHelp,
          child: SlideSegments<DensityMode>(
            options: [(DensityMode.comfortable, l.densityComfortable, null), (DensityMode.normal, l.densityNormal, null), (DensityMode.compact, l.densityCompact, null)],
            selected: s.density,
            onChanged: (v) => set((x) => x.copyWith(density: v)),
          ),
        ),
        _Group(
          title: l.setFont,
          help: l.setFontHelp,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SlideSegments<FontChoice>(
              options: [(FontChoice.inter, l.fontInter, null), (FontChoice.atkinson, l.fontAtkinson, null)],
              selected: s.font,
              onChanged: (v) => set((x) => x.copyWith(font: v)),
            ),
            const SizedBox(height: 8),
            Text(l.fontPreview, style: th.bodyLarge),
          ]),
        ),
        Text(l.deviceOnlyNote, style: th.bodySmall),
      ]),
    );
  }
}

class AnimationsCard extends ConsumerWidget {
  const AnimationsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier).set;
    final th = Theme.of(context).textTheme;
    final systemReduces = MediaQuery.disableAnimationsOf(context);
    return SectionCard(
      title: l.setAnimations,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.setAnimationsHelp, style: th.bodySmall),
        const SizedBox(height: 10),
        SlideSegments<MotionLevel>(
          options: [(MotionLevel.full, l.animFull, null), (MotionLevel.gentle, l.animGentle, null), (MotionLevel.off, l.animOff, null)],
          selected: s.motion,
          onChanged: (v) => set((x) => x.copyWith(motion: v, motionAutoReduced: false)),
        ),
        const SizedBox(height: 6),
        Text(switch (s.motion) { MotionLevel.full => l.animFullHelp, MotionLevel.gentle => l.animGentleHelp, MotionLevel.off => l.animOffHelp }, style: th.bodySmall),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.animFollowSystem),
          subtitle: Text(systemReduces ? l.animSystemReducing : l.animFollowSystemHelp),
          value: s.followSystemMotion,
          onChanged: (v) => set((x) => x.copyWith(followSystemMotion: v)),
        ),
        if (s.motionAutoReduced)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.c.badgeBgInfo, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: context.c.info.withValues(alpha: 0.5))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.speed_rounded, color: context.c.info), const SizedBox(width: 8), Expanded(child: Text(l.animAutoNote, style: th.bodyMedium?.copyWith(color: context.c.info)))]),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => set((x) => x.copyWith(motion: MotionLevel.gentle, motionAutoReduced: false)), child: Text(l.animTurnBackOn)),
            ]),
          ),
      ]),
    );
  }
}

class SoundsCard extends ConsumerWidget {
  const SoundsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier).set;
    final th = Theme.of(context).textTheme;
    return SectionCard(
      title: l.setSounds,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.soundScan), subtitle: Text(l.soundScanHelp), value: s.soundScan, onChanged: (v) => set((x) => x.copyWith(soundScan: v))),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.soundSave), subtitle: Text(l.soundSaveHelp), value: s.soundSave, onChanged: (v) => set((x) => x.copyWith(soundSave: v))),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.soundError), subtitle: Text(l.soundErrorHelp), value: s.soundError, onChanged: (v) => set((x) => x.copyWith(soundError: v))),
        const SizedBox(height: 4),
        Text('${l.soundVolume}: ${(s.soundVolume * 100).round()}%', style: th.titleSmall),
        Slider(value: s.soundVolume, min: 0, max: 1, divisions: 10, label: '${(s.soundVolume * 100).round()}%', onChanged: (v) => set((x) => x.copyWith(soundVolume: v))),
        Text(l.soundNote, style: th.bodySmall),
      ]),
    );
  }
}
