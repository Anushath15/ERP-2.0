import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/responsive.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../design/app_logo.dart';
import '../../fake/store.dart';
import '../../nav.dart';
import 'appearance_cards.dart';
import 'security_card.dart';
import '../../data/db/integrity.dart';
import '../../data/repo/rebuild.dart';
import '../../data/repo/self_check.dart';
import '../../fake/health.dart';
import '../../fake/stats.dart';
import '../../strings.dart';
import '../../core/data_mode.dart';
import '../../fake/data_providers.dart';

// ------------------------------------------------------------------ settings
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pin = false;
  bool _autoBackup = true;

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier).set;
    final th = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider);

    Widget row(String title, String? help, Widget trailing) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: th.titleSmall), if (help != null) Text(help, style: th.bodySmall)])),
            const SizedBox(width: 12),
            Flexible(child: Align(alignment: Alignment.centerRight, child: trailing)),
          ]),
        );

    final printing = SectionCard(title: l.setPrinting, child: Column(children: [
      row(l.setPaper, l.setPaperHelp, SegmentedButton<PaperSize>(showSelectedIcon: false, segments: [ButtonSegment(value: PaperSize.a4, label: Text(l.paperA4)), ButtonSegment(value: PaperSize.a5, label: Text(l.paperA5)), ButtonSegment(value: PaperSize.mm80, label: Text(l.paper80)), ButtonSegment(value: PaperSize.mm58, label: Text(l.paper58))], selected: {s.paper}, onSelectionChanged: (v) => set((x) => x.copyWith(paper: v.first)))),
      row(l.setPrintSize, l.setPrintSizeHelp, SegmentedButton<PrintTextSize>(key: const ValueKey('printSize'), showSelectedIcon: false, segments: [ButtonSegment(value: PrintTextSize.smaller, label: Text(l.printSmaller)), ButtonSegment(value: PrintTextSize.small, label: Text(l.printSmall)), ButtonSegment(value: PrintTextSize.normal, label: Text(l.printNormal))], selected: {s.printSize}, onSelectionChanged: (v) => set((x) => x.copyWith(printSize: v.first)))),
      row(l.setPrinter, l.setPrinterHelp, const SizedBox.shrink()),
    ]));

    const look = AppearanceCard();
    const anim = AnimationsCard();
    const sounds = SoundsCard();

    final backup = SectionCard(title: l.setBackup, child: Column(children: [
      row(l.lastBackup, l.lastBackupValue(formatDateTime(now.subtract(const Duration(hours: 5)))), FilledButton.icon(onPressed: () => toast(context, l.backupDone), icon: const Icon(Icons.save_alt), label: Text(l.backupNow))),
      row(l.autoBackup, l.autoBackupHelp, Switch(value: _autoBackup, onChanged: (v) => setState(() => _autoBackup = v))),
      row(l.restore, l.restoreHelp, OutlinedButton.icon(onPressed: () async {
        final ok = await confirmDialog(context, title: l.restoreConfirmTitle, message: l.restoreConfirmText, confirmLabel: l.restore, danger: true);
        if (ok && context.mounted) toast(context, l.demoOnly);
      }, icon: const Icon(Icons.restore), label: Text(l.chooseFile))),
    ]));

    final sync = SectionCard(title: l.setSync, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      row(l.syncStatusNow, l.lastSyncedAt(formatTime(now.subtract(const Duration(minutes: 4)))), Wrap(spacing: 8, children: [
        const SyncChipInline(),
        FilledButton.icon(onPressed: s.sync == SyncState.offline || s.sync == SyncState.paused ? null : () async {
          set((x) => x.copyWith(sync: SyncState.syncing));
          await Future<void>.delayed(const Duration(milliseconds: 600));
          if (mounted) set((x) => x.copyWith(sync: SyncState.synced));
        }, icon: const Icon(Icons.sync), label: Text(l.syncNow)),
      ])),
      if (s.sync == SyncState.paused) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.syncPausedHelp, style: th.bodyMedium)),
      row(l.quotaTitle, l.quotaHelp, Text(l.quotaValue('3'), style: th.titleSmall)),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: 0.03, minHeight: 8, color: context.c.success, backgroundColor: context.c.surfaceAlt)),
      const Divider(height: 24),
      Text(l.demoControls, style: th.labelSmall),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in [(SyncState.synced, l.syncSynced), (SyncState.syncing, l.syncSyncing), (SyncState.offline, l.syncOffline), (SyncState.attention, l.syncAttention('1')), (SyncState.paused, l.syncPaused)])
          ChoiceChip(label: Text(e.$2), selected: s.sync == e.$1, onSelected: (_) => set((x) => x.copyWith(sync: e.$1))),
      ]),
    ]));

    final security = SectionCard(title: l.setSecurity, child: Column(children: [
      row(l.setPin, l.setPinHelp, Switch(value: _pin, onChanged: (v) => setState(() => _pin = v))),
      row(l.signOutEverywhere, l.signOutEverywhereHelp, OutlinedButton(onPressed: () => toast(context, l.demoOnly), child: Text(l.changePassword))),
    ]));

    const people = SecurityCard();
    final demoOn = ref.watch(appModeProvider) == DataMode.demo;
    final demo = SectionCard(title: l.setDemo, child: row(l.setDemoOn, l.setDemoHelp, Switch(key: const ValueKey('demoSwitch'), value: demoOn, onChanged: (v) async {
      final ok = await confirmDialog(context, title: v ? l.setDemoSwitchTitle : l.setDemoLeaveTitle, message: v ? l.setDemoSwitchText : l.setDemoLeaveText, confirmLabel: v ? l.setDemoOn : l.setDemoLeaveTitle.replaceAll('?', ''));
      if (ok) await ref.read(modeSwitcherProvider)(v ? DataMode.demo : DataMode.real);
    })));
    final cards = [look, anim, printing, sounds, backup, sync, security, people, demo];
    return PageFrame(
      title: l.navSettings,
      child: context.isDesktop
          ? SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [for (final c in [printing, security, people, backup, demo]) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)])),
                const SizedBox(width: 12),
                Expanded(child: Column(children: [for (final c in [look, anim, sounds, sync]) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)])),
              ]),
            )
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)]),
    );
  }
}

class SyncChipInline extends ConsumerWidget {
  const SyncChipInline({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final st = ref.watch(settingsProvider).sync;
    final (label, kind) = switch (st) { SyncState.synced => (l.syncSynced, BadgeKind.success), SyncState.syncing => (l.syncSyncing, BadgeKind.info), SyncState.offline => (l.syncOffline, BadgeKind.warning), SyncState.attention => (l.syncAttention('1'), BadgeKind.danger), SyncState.paused => (l.syncPaused, BadgeKind.warning) };
    return StatusBadge(label, kind: kind);
  }
}

// ------------------------------------------------------------------ database health
class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});
  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  bool _checking = false;
  List<String>? _found; // what the check just run found (null = not run on this visit)

  String _size(int bytes) => bytes >= 1024 * 1024 * 1024 ? '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB' : '${(bytes / (1024 * 1024)).round()} MB';

  Future<void> _checkNow(Strings l) async {
    setState(() => _checking = true);
    final loc = ref.read(dbFilePathProvider);
    final d = ref.read(appDataProvider);
    final found = <String>[];
    if (loc != null) found.addAll(await checkDatabaseFile(loc));
    found.addAll([for (final p in await selfCheck(d.db)) '$p']);
    await d.settings.put('selfcheck.last', '${d.cx.nowMs()}');
    ref.read(selfCheckProblemsProvider.notifier).set(found);
    ref.invalidate(healthInfoProvider);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _found = found;
    });
    toast(context, found.isEmpty ? l.healthChecked : l.healthProblemsFound(found.length.toString()));
  }

  Future<void> _rebuild(Strings l) async {
    final ok = await confirmDialog(context, title: l.rebuildTitle, message: l.rebuildText, confirmLabel: l.rebuildTotals);
    if (!ok || !mounted) return;
    final d = ref.read(appDataProvider);
    await ref.read(writeQueueProvider).run(() => rebuildSummaries(d.db));
    await ref.read(productsProvider.notifier).reload([for (final p in ref.read(productsProvider)) p.id]);
    await ref.read(statsProvider.notifier).refresh();
    ref.read(selfCheckProblemsProvider.notifier).set(const []);
    ref.invalidate(healthInfoProvider);
    if (mounted) {
      setState(() => _found = const []);
      toast(context, l.rebuildDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final c = context.c;
    final info = ref.watch(healthInfoProvider).value;
    final health = ref.watch(fileHealthProvider);
    final List<String> problems = _found ?? ref.watch(selfCheckProblemsProvider);
    Widget item(IconData icon, Color color, String title, String value, {String? help, Widget? action}) => SectionCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: th.bodySmall), Text(value, style: th.titleMedium), if (help != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(help, style: th.bodySmall)), if (action != null) Padding(padding: const EdgeInsets.only(top: 8), child: action)])),
          ]),
        );
    final damaged = health == FileHealth.damaged;
    final last = info?.lastFullCheck ?? info?.lastSelfCheck;
    final cards = [
      item(damaged ? Icons.error_outline : Icons.verified_outlined, damaged ? c.danger : c.success, l.healthIntegrity, damaged ? l.healthDamaged : (problems.isEmpty ? l.healthOk : l.healthProblemsFound(problems.length.toString())),
          help: last == null ? l.healthNeverChecked : l.healthIntegrityHelp(formatDateTime(last)),
          action: OutlinedButton.icon(key: const ValueKey('checkNow'), onPressed: _checking ? null : () => _checkNow(l), icon: _checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search), label: Text(l.checkNow))),
      item(Icons.save_alt, info?.lastBackup == null ? c.warning : c.success, l.lastBackup, info?.lastBackup == null ? l.noBackupYet : formatDateTime(info!.lastBackup!), help: l.backupsKept('30')),
      item(Icons.storage_outlined, info?.freeBytes != null && info!.freeBytes! < 500 * 1024 * 1024 ? c.warning : c.primary, l.freeDisk, info?.freeBytes == null ? l.healthUnknown : _size(info!.freeBytes!), help: l.freeDiskHelp),
      item(Icons.cloud_upload_outlined, (info?.pendingUploads ?? 0) > 0 ? c.warning : c.success, l.syncBacklog, l.syncBacklogValue('${info?.pendingUploads ?? 0}'), help: l.syncBacklogHelp),
      item(Icons.inventory_outlined, problems.isEmpty ? c.success : c.warning, l.healthTotals, problems.isEmpty ? l.healthTotalsOk : l.healthProblemsFound(problems.length.toString()), help: l.healthTotalsHelp, action: OutlinedButton(key: const ValueKey('rebuildTotals'), onPressed: () => _rebuild(l), child: Text(l.rebuildTotals))),
      item(Icons.memory, c.primary, l.databaseSize, info?.fileBytes == null ? l.healthUnknown : _size(info!.fileBytes!), help: l.databaseSizeHelp('1,000,000')),
    ];
    final attention = SectionCard(
      title: l.needsAttention,
      child: problems.isEmpty && (info?.needAttention ?? 0) == 0 && !damaged
          ? Row(children: [Icon(Icons.check_circle_outline, color: c.success), const SizedBox(width: 8), Expanded(child: Text(l.nothingNeedsAttention))])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final p in problems.take(8)) Padding(padding: const EdgeInsets.only(bottom: 6), child: StatusBadge(p, kind: BadgeKind.danger, icon: Icons.error_outline)),
              if ((info?.needAttention ?? 0) > 0) StatusBadge(l.syncAttention('${info!.needAttention}'), kind: BadgeKind.danger, icon: Icons.error_outline),
              const SizedBox(height: 8),
              Text(l.attentionHelp2, style: th.bodyMedium),
            ]),
    );
    return PageFrame(
      title: l.navHealth,
      subtitle: l.healthSubtitle,
      child: LayoutBuilder(builder: (ctx, bc) {
        final cols = (bc.maxWidth / ctx.textFactor) > 980 ? 3 : ((bc.maxWidth / ctx.textFactor) > 620 ? 2 : 1);
        final w = ((bc.maxWidth - (cols - 1) * 12) / cols).floorToDouble();
        return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 12, runSpacing: 12, children: [for (final k in cards) SizedBox(width: w, child: k)]),
          const SizedBox(height: 12),
          attention,
        ]));
      }),
    );
  }
}

// ------------------------------------------------------------------ help, about, more
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final keys = <(String, String)>[('F2', l.keyNewBill), ('F3', l.keyNewEstimate), ('F4', l.navSalesRegister), ('F5', l.navProducts), ('F9', l.saveAndPrint), ('Ctrl+S', l.keySave), ('Ctrl+Shift+N', l.keyNewProduct), ('Ctrl+Shift+L', l.keyFill100), ('Esc', l.keyCancel), ('↑ ↓ Enter', l.keyPick)];
    final faq = <(String, String)>[(l.faq1q, l.faq1a), (l.faq2q, l.faq2a), (l.faq3q, l.faq3a), (l.faq4q, l.faq4a), (l.faq5q, l.faq5a)];
    final steps = [l.helpStep1, l.helpStep2, l.helpStep3, l.helpStep4];
    return PageFrame(
      title: l.navHelp,
      subtitle: l.helpSubtitle,
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        SectionCard(title: l.helpQuickStart, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < steps.length; i++) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(radius: 13, backgroundColor: context.c.primary, child: Text('${i + 1}', style: TextStyle(color: context.c.onPrimary, fontWeight: FontWeight.w700))), const SizedBox(width: 10), Expanded(child: Text(steps[i], style: th.bodyLarge))])),
        ])),
        const SizedBox(height: 12),
        SectionCard(title: l.helpShortcuts, child: Column(children: [
          for (final k in keys) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 130, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: context.c.surfaceAlt, borderRadius: BorderRadius.circular(6), border: Border.all(color: context.c.border)), child: Text(k.$1, style: th.labelMedium))), const SizedBox(width: 12), Expanded(child: Text(k.$2))])),
        ])),
        const SizedBox(height: 12),
        SectionCard(title: l.helpFaq, padding: const EdgeInsets.all(6), child: Column(children: [
          for (final f in faq) ExpansionTile(title: Text(f.$1, style: th.titleSmall), childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12), shape: const Border(), collapsedShape: const Border(), children: [Align(alignment: Alignment.centerLeft, child: Text(f.$2, style: th.bodyMedium))]),
        ])),
        const SizedBox(height: 12),
        SectionCard(title: l.helpWrong, child: Text(l.helpWrongText, style: th.bodyLarge)),
      ]),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    return PageFrame(
      title: l.navAbout,
      child: SingleChildScrollView(child: Align(alignment: Alignment.topLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Column(children: [
        SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const AppLogo(size: 64),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.appName, style: th.headlineSmall), Text(l.aboutVersion('2.0.0-preview.1'), style: th.bodySmall)])),
          ]),
          const SizedBox(height: 12),
          Text(l.aboutText, style: th.bodyLarge),
          const SizedBox(height: 12),
          StatusBadge(l.aboutPrototype, kind: BadgeKind.warning, icon: Icons.science_outlined),
        ])),
        const SizedBox(height: 12),
        SectionCard(title: l.aboutPrivacy, child: Text(l.aboutPrivacyText, style: th.bodyMedium)),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => showLicensePage(context: context, applicationName: l.appName, applicationVersion: '2.0.0-preview.1'), icon: const Icon(Icons.description_outlined), label: Text(l.aboutLicenses)),
      ])))),
    );
  }
}

/// Phone "More" tab: every screen as a tappable list, grouped.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
      for (final g in navGroups) ...[
        Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 6), child: Text(g.label(l).toUpperCase(), style: th.labelSmall)),
        Card(child: Column(children: [
          for (var i = 0; i < g.items.length; i++) ...[
            if (i > 0) const Divider(),
            ListTile(
              minTileHeight: 52,
              leading: Icon(g.items[i].icon, color: context.c.primary),
              title: Text(g.items[i].label(l), style: th.titleSmall),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(g.items[i].path),
            ),
          ],
        ])),
      ],
    ]);
  }
}
