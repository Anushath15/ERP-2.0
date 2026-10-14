import 'features/system/problem_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/date_fmt.dart';
import 'core/responsive.dart';
import 'design/effects.dart';
import 'design/motion.dart';
import 'design/text_zoom.dart';
import 'design/tokens.dart';
import 'design/widgets.dart';
import 'design/app_logo.dart';
import 'fake/store.dart';
import 'fake/shop_profile.dart';
import 'nav.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = context.screen;
    final l = tr(context);
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.f2): () => context.go('/bill'),
      const SingleActivator(LogicalKeyboardKey.f3): () => context.go('/estimate'),
      const SingleActivator(LogicalKeyboardKey.f4): () => context.go('/sales'),
      const SingleActivator(LogicalKeyboardKey.f5): () => context.go('/products'),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true, shift: true): () => context.go('/products?add=1'),
    };

    if (size == ScreenSize.phone) {
      final billing = location == '/bill' || location == '/estimate';
      final idx = phoneTabs.indexOf(location);
      final hideBar = billing || (idx < 0 && location != '/more');
      return CallbackShortcuts(
        bindings: shortcuts,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            leading: location == '/' || idx >= 0 || location == '/more' ? null : IconButton(icon: const Icon(Icons.arrow_back), tooltip: l.back, onPressed: () => context.canPop() ? context.pop() : context.go('/')),
            title: Text(location == '/more' ? l.navMore : (navFor(location)?.label(l) ?? l.appName), maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: const [SyncChip(compact: true), SizedBox(width: 8)],
          ),
          body: Column(children: [const ProblemBanner(), Expanded(child: child)]),
          bottomNavigationBar: hideBar
              ? null
              : NavigationBar(
                  labelBehavior: context.textFactor >= 1.4 ? NavigationDestinationLabelBehavior.onlyShowSelected : NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: idx >= 0 ? idx : 4,
                  onDestinationSelected: (i) => context.go(i < 4 ? phoneTabs[i] : '/more'),
                  destinations: [
                    NavigationDestination(icon: const Icon(Icons.space_dashboard_outlined), label: l.navDashboard),
                    NavigationDestination(icon: const Icon(Icons.point_of_sale), label: l.navBill),
                    NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), label: l.navProducts),
                    NavigationDestination(icon: const Icon(Icons.people_outline), label: l.navCustomers),
                    NavigationDestination(icon: const Icon(Icons.apps), label: l.navMore),
                  ],
                ),
        ),
      );
    }

    final wide = ref.watch(navExpandedProvider) ?? size == ScreenSize.desktop;
    return CallbackShortcuts(
      bindings: shortcuts,
      child: Scaffold(
        body: Row(children: [
          SideNav(location: location, wide: wide),
          VerticalDivider(width: 1, color: context.c.border.withValues(alpha: 0.6)),
          Expanded(
            child: Column(children: [
              TopBar(location: location),
              Divider(height: 1, color: context.c.border.withValues(alpha: 0.6)),
              const ProblemBanner(),
              Expanded(child: child),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The owner can fold the left menu away (null = decide by window size).
class NavExpanded extends Notifier<bool?> {
  @override
  bool? build() => null;
  void toggle(bool current) => state = !current;
}

final navExpandedProvider = NotifierProvider<NavExpanded, bool?>(NavExpanded.new);

class SideNav extends StatelessWidget {
  const SideNav({super.key, required this.location, required this.wide});
  final String location;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    final th = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: context.motion.t(200),
      curve: Motion.out,
      width: wide ? Sizes.navRailWidth : Sizes.navRailCollapsed,
      color: c.surface,
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(builder: (ctx, bc) {
        // labels appear only once there is room for them, so a half-open menu never overflows
        final wide = bc.maxWidth > 150;
        return Column(children: [
        SizedBox(
          height: 56,
          child: Row(mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
            if (wide) const SizedBox(width: 16),
            const AppLogo(size: 34),
            if (wide) ...[
              const SizedBox(width: 10),
              Expanded(child: Text(l.appName, style: th.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ]),
        ),
        Divider(height: 1, color: c.border.withValues(alpha: 0.6)),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
            for (final g in navGroups) ...[
              if (wide) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(g.label(l).toUpperCase(), style: th.labelSmall)) else const SizedBox(height: 8),
              for (final i in g.items) _NavTile(item: i, selected: i.path == location || (i.path != '/' && location.startsWith('${i.path}/')), wide: wide),
            ],
          ]),
        ),
      ]);
      }),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected, required this.wide});
  final NavItem item;
  final bool selected, wide;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final l = tr(context);
    final label = item.label(l);
    final content = Container(
      height: context.metrics.navTile,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(color: selected ? c.rowSelected : null, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
        if (wide) const SizedBox(width: 12),
        Icon(item.icon, size: 22, color: selected ? c.primary : c.textMuted),
        if (wide) ...[
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? c.text : c.textMuted, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ]),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: wide ? '' : label,
        child: InkWell(borderRadius: BorderRadius.circular(8), onTap: () => context.go(item.path), child: content),
      ),
    );
  }
}

class TopBar extends ConsumerWidget {
  const TopBar({super.key, required this.location});
  final String location;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 56,
      color: context.c.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        IconButton(
          tooltip: l.toggleMenu,
          onPressed: () => ref.read(navExpandedProvider.notifier).toggle(ref.read(navExpandedProvider) ?? context.isDesktop),
          icon: const Icon(Icons.menu),
        ),
        Expanded(child: Text(ref.watch(shopProvider).name, style: th.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const Flexible(child: SyncChip()),
        const SizedBox(width: 8),
        IconButton(tooltip: l.textSmaller, onPressed: () => ref.read(settingsProvider.notifier).set((x) => x.copyWith(textScale: TextZoom.down(x.textScale))), icon: const Icon(Icons.text_decrease)),
        IconButton(tooltip: l.textLarger, onPressed: () => ref.read(settingsProvider.notifier).set((x) => x.copyWith(textScale: TextZoom.up(x.textScale))), icon: const Icon(Icons.text_increase)),
        IconButton(
          tooltip: dark ? l.themeLight : l.themeDark,
          onPressed: () => ref.read(settingsProvider.notifier).set((x) => x.copyWith(theme: dark ? ThemeMode.light : ThemeMode.dark)),
          icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        ),
        PopupMenuButton<String>(
          tooltip: l.account,
          icon: const Icon(Icons.account_circle_outlined),
          onSelected: (v) {
            if (v == 'out') context.go('/signin');
            if (v == 'settings') context.go('/settings');
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'settings', child: Text(l.navSettings)),
            PopupMenuItem(value: 'out', child: Text(l.signOut)),
          ],
        ),
      ]),
    );
  }
}

/// Sync status, always visible: Synced / Syncing / Offline - saved on this PC / Needs attention.
class SyncChip extends ConsumerWidget {
  const SyncChip({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final st = ref.watch(settingsProvider).sync;
    final now = ref.watch(clockProvider);
    final (label, kind, icon) = switch (st) {
      SyncState.synced => (l.syncSynced, BadgeKind.success, Icons.cloud_done_outlined),
      SyncState.syncing => (l.syncSyncing, BadgeKind.info, Icons.sync),
      SyncState.offline => (l.syncOffline, BadgeKind.warning, Icons.cloud_off_outlined),
      SyncState.attention => (l.syncAttention('1'), BadgeKind.danger, Icons.error_outline),
      SyncState.paused => (l.syncPaused, BadgeKind.warning, Icons.pause_circle_outline),
    };
    final tip = l.lastSyncedAt(formatTime(now.subtract(const Duration(minutes: 4))));
    return Semantics(
      label: '$label. $tip',
      button: true,
      child: Tooltip(
        message: tip,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go('/settings'),
          child: compact
              ? Padding(padding: const EdgeInsets.all(6), child: Pulse(active: st == SyncState.syncing, child: Icon(icon, color: switch (kind) { BadgeKind.success => context.c.success, BadgeKind.warning => context.c.warning, BadgeKind.danger => context.c.danger, _ => context.c.info })))
              : Padding(padding: const EdgeInsets.all(4), child: Pulse(active: st == SyncState.syncing, child: StatusBadge(label, kind: kind, icon: icon))),
        ),
      ),
    );
  }
}
