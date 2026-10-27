import 'features/system/problem_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/cloud/sync_controller.dart';
import 'core/date_fmt.dart';
import 'core/nav_history.dart';
import 'core/os.dart';
import 'core/lock/pin_lock.dart';
import 'core/responsive.dart';
import 'design/effects.dart';
import 'design/hotkeys.dart';
import 'design/motion.dart';
import 'design/text_zoom.dart';
import 'design/tokens.dart';
import 'design/widgets.dart';
import 'design/app_logo.dart';
import 'fake/store.dart';
import 'fake/shop_profile.dart';
import 'nav.dart';

/// True on a real phone or tablet (Android, iPhone). A computer window that is narrow, or shows big text, also gets the phone layout, but it is not a
/// touch device and keeps its pages exactly as they were. Tests switch it on to try the phone-only parts.
final touchDeviceProvider = Provider<bool>((ref) => onAndroid || onIos);

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
      const SingleActivator(LogicalKeyboardKey.f6): () => context.go('/customers'),
      const SingleActivator(LogicalKeyboardKey.f7): () => context.go('/credit'),
      const SingleActivator(LogicalKeyboardKey.f8): () => context.go('/reports'),
      const SingleActivator(LogicalKeyboardKey.keyQ, control: true): () => context.go('/bill'), // as in Invoiso
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => context.go('/bill'),
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => SearchFocus.focus(),
      const SingleActivator(LogicalKeyboardKey.f1): () => showShortcutsDialog(context),
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () => navHistory.back(GoRouter.of(context)),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true, shift: true): () => context.go('/products?add=1'),
    };

    if (size == ScreenSize.phone) {
      final billing = location == '/bill' || location == '/estimate';
      final touch = ref.watch(touchDeviceProvider);
      final idx = phoneTabs.indexOf(location);
      final hideBar = billing || (idx < 0 && location != '/more');
      return _BackGuard(
        location: location,
        child: CallbackShortcuts(
        bindings: shortcuts,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            leading: location == '/' || (idx >= 0 && !(billing && touch)) || location == '/more' ? null : IconButton(icon: const Icon(Icons.arrow_back_rounded), tooltip: l.back, onPressed: () => navHistory.back(GoRouter.of(context))),
            title: Text(location == '/more' ? l.navMore : (navFor(location)?.label(l) ?? l.appName), maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: const [NotificationBell(), SyncChip(compact: true), SizedBox(width: 8)],
          ),
          body: Column(children: [const ProblemBanner(), Expanded(child: child)]),
          bottomNavigationBar: hideBar
              ? null
              : NavigationBar(
                  labelBehavior: context.textFactor >= 1.4 ? NavigationDestinationLabelBehavior.onlyShowSelected : NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: idx >= 0 ? idx : 4,
                  onDestinationSelected: (i) => context.go(i < 4 ? phoneTabs[i] : '/more'),
                  destinations: [
                    NavigationDestination(icon: const Icon(Icons.space_dashboard_rounded), label: l.navDashboard),
                    NavigationDestination(icon: const Icon(Icons.point_of_sale_rounded), label: l.navBill),
                    NavigationDestination(icon: const Icon(Icons.inventory_2_rounded), label: l.navProducts),
                    NavigationDestination(icon: const Icon(Icons.people_outline_rounded), label: l.navCustomers),
                    NavigationDestination(icon: const Icon(Icons.apps_rounded), label: l.navMore),
                  ],
                ),
        ),
      ),
      );
    }

    final wide = ref.watch(navExpandedProvider) ?? size == ScreenSize.desktop;
    final desktop = CallbackShortcuts(
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
    // a computer has no Back button; an Android tablet or a phone turned sideways has one
    return onAndroid || onIos ? _BackGuard(location: location, child: desktop) : desktop;
  }
}

/// The Android Back button (and the back swipe). Screens are opened with `go`, which leaves nothing for the system to pop, so Back used to
/// close the whole program from any page. Now: on a page it returns to the page before (the dashboard when there is none); on the dashboard a
/// first press says "press again" and a second press within two seconds closes the program. Open dialogs and sheets are their own routes
/// and close first; the keyboard closes before any of this.
class _BackGuard extends StatefulWidget {
  const _BackGuard({required this.location, required this.child});
  final String location;
  final Widget child;
  @override
  State<_BackGuard> createState() => _BackGuardState();
}

class _BackGuardState extends State<_BackGuard> {
  DateTime? _lastBack;

  void _back() {
    if (widget.location != '/') {
      final router = GoRouter.of(context);
      if (navHistory.canGoBack || router.canPop()) {
        navHistory.back(router);
      } else {
        router.go('/');
      }
      return;
    }
    final now = DateTime.now();
    final last = _lastBack;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    toast(context, tr(context).backPressAgain);
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: widget.child,
      );
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
              for (final i in g.items) _NavTile(item: i, selected: i.path == navHome(location) || (i.path != '/' && navHome(location).startsWith('${i.path}/')), wide: wide),
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
        if (location != '/')
          ListenableBuilder(
            listenable: navHistory,
            builder: (context, _) => IconButton(
              key: const ValueKey('topbar-back'),
              tooltip: l.back,
              onPressed: () => navHistory.back(GoRouter.of(context)),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        IconButton(
          tooltip: l.toggleMenu,
          onPressed: () => ref.read(navExpandedProvider.notifier).toggle(ref.read(navExpandedProvider) ?? context.isDesktop),
          icon: const Icon(Icons.menu_rounded),
        ),
        Expanded(child: Text(ref.watch(shopProvider).name.isEmpty ? l.appName : ref.watch(shopProvider).name, style: th.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
        SyncChip(compact: context.isPhone),
        const SizedBox(width: 8),
        IconButton(tooltip: l.textSmaller, onPressed: () => ref.read(settingsProvider.notifier).set((x) => x.copyWith(textScale: TextZoom.down(x.textScale))), icon: const Icon(Icons.text_decrease_rounded)),
        IconButton(tooltip: l.textLarger, onPressed: () => ref.read(settingsProvider.notifier).set((x) => x.copyWith(textScale: TextZoom.up(x.textScale))), icon: const Icon(Icons.text_increase_rounded)),
        IconButton(
          tooltip: dark ? l.themeLight : l.themeDark,
          onPressed: () => ref.read(settingsProvider.notifier).set((x) => x.copyWith(theme: dark ? ThemeMode.light : ThemeMode.dark)),
          icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
        ),
        const NotificationBell(),
        if (ref.watch(pinLockProvider.select((x) => x.enabled)))
          IconButton(key: const ValueKey('topbar-lock'), tooltip: l.lockNow, onPressed: ref.read(pinLockProvider.notifier).lock, icon: Icon(Icons.lock_outline_rounded, color: context.c.text)),
        IconButton(
          key: const ValueKey('topbar-profile'),
          tooltip: l.navShop,
          onPressed: () => context.go('/shop'),
          icon: const Icon(Icons.account_circle_rounded),
        ),

      ]),
    );
  }
}

/// The bell on the top bar (notifications are not in the side menu): the number of unread ones on it, a tap opens the list.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final unread = ref.watch(recsProvider('notifications')).where((r) => r.i('read') == 0).length;
    return IconButton(
      key: const ValueKey('topbar-notifications'),
      tooltip: unread == 0 ? l.navNotifications : '${l.navNotifications}: $unread',
      onPressed: () => context.go('/notifications'),
      icon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: Icon(unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded)),
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
    final st = effectiveSyncState(ref);
    final now = ref.watch(clockProvider);
    final cloud = ref.watch(syncProvider);
    final (label, kind, icon) = switch (st) {
      SyncState.synced => (l.syncSynced, BadgeKind.success, Icons.cloud_done_rounded),
      SyncState.syncing => (l.syncSyncing, BadgeKind.info, Icons.sync_rounded),
      SyncState.offline => (l.syncOffline, BadgeKind.warning, Icons.cloud_off_rounded),
      SyncState.attention => (cloud.phase == SyncPhase.signedOut ? l.syncSignedOut : l.syncAttention(cloud.active ? '${cloud.attention == 0 ? 1 : cloud.attention}' : '1'), BadgeKind.danger, Icons.error_outline_rounded),
      SyncState.paused => (l.syncPaused, BadgeKind.warning, Icons.pause_circle_outline_rounded),
    };
    final tip = cloud.active ? (cloud.last == null ? l.syncNever : l.lastSyncedAt(formatTime(cloud.last!))) : l.lastSyncedAt(formatTime(now.subtract(const Duration(minutes: 4))));
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
