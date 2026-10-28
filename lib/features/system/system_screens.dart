import '../../core/touch_device.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_info.dart';
import '../../core/cloud/cloud_config.dart';
import '../../core/link_launcher.dart';
import '../../core/update_check.dart';
import '../../core/cloud/sync_controller.dart';
import '../../core/date_fmt.dart';
import '../../core/printer_service.dart';
import '../lock/lock_screen.dart';
import '../print/print_action.dart';
import '../print/test_page_pdf.dart';
import '../../core/responsive.dart';
import '../../design/tokens.dart';
import '../../design/hotkeys.dart';
import '../../design/widgets.dart';
import '../../design/app_logo.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart';
import '../../nav.dart';
import 'appearance_cards.dart';
import 'diagnostics_card.dart';
import 'features_card.dart';
import 'sync_details.dart';
import 'lan_card.dart';
import 'thermal_card.dart';
import 'security_card.dart';
import '../../data/db/integrity.dart';
import '../../data/repo/rebuild.dart';
import '../../data/repo/self_check.dart';
import '../../fake/health.dart';
import '../../fake/stock_value_provider.dart';
import '../stock/stock_value_sheet.dart';
import '../../fake/backup_controller.dart';
import '../import/import_erp1_screen.dart';
import '../import/import_providers.dart';
import '../../data/importer/swap.dart';
import '../../data/backup/backup_types.dart' show freshnessOf, BackupFreshness;
import '../../core/money.dart';
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
  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier).set;
    final th = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider);
    final cloud = ref.watch(syncProvider);

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
      row(l.setPrinter, l.setPrinterHelp, const PrinterPicker()),
      row(l.setPrintViaWindow, l.setPrintViaWindowHelp, Switch(key: const ValueKey('printViaDialog'), value: s.printViaDialog, onChanged: (v) => set((x) => x.copyWith(printViaDialog: v)))),
      row(l.setPrintAsPicture, l.setPrintAsPictureHelp, Switch(key: const ValueKey('printAsPicture'), value: s.printAsPicture, onChanged: (v) => set((x) => x.copyWith(printAsPicture: v)))),
      row(l.setPrintAfterSave, l.setPrintAfterSaveHelp, Switch(key: const ValueKey('printAfterSave'), value: s.printAfterSave, onChanged: (v) => set((x) => x.copyWith(printAfterSave: v)))),
      row(l.setLabelPrinter, l.setLabelPrinterHelp, const PrinterPicker(labels: true)),
    ]));

    const look = AppearanceCard();
    const anim = AnimationsCard();
    const sounds = SoundsCard();

    final lastBk = ref.watch(backupControllerProvider).last;
    final backup = SectionCard(title: l.setBackup, child: Column(children: [
      row(l.lastBackup, lastBk == null ? l.noBackupYet : l.lastBackupValue(formatDateTime(lastBk)), FilledButton.icon(key: const ValueKey('openBackups'), onPressed: () => context.go('/backups'), icon: const Icon(Icons.save_alt_rounded), label: Text(l.navBackups))),
      row(l.restore, l.restoreHelp, OutlinedButton.icon(key: const ValueKey('openRestore'), onPressed: () => context.go('/restore'), icon: const Icon(Icons.restore_rounded), label: Text(l.restoreTitle))),
    ]));

    final sync = SectionCard(title: l.setSync, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      row(l.syncStatusNow, cloud.active ? (cloud.last == null ? l.syncNever : l.lastSyncedAt(formatTime(cloud.last!))) : l.lastSyncedAt(formatTime(now.subtract(const Duration(minutes: 4)))), Wrap(spacing: 8, children: [
        const SyncChipInline(),
        if (cloud.active) FilledButton.icon(key: const ValueKey('syncNow'), onPressed: cloud.phase == SyncPhase.syncing ? null : () => unawaited(ref.read(syncProvider.notifier).syncNow()), icon: const Icon(Icons.sync_rounded), label: Text(l.syncNow))
        else FilledButton.icon(onPressed: s.sync == SyncState.offline || s.sync == SyncState.paused ? null : () async {
          set((x) => x.copyWith(sync: SyncState.syncing));
          await Future<void>.delayed(const Duration(milliseconds: 600));
          if (mounted) set((x) => x.copyWith(sync: SyncState.synced));
        }, icon: const Icon(Icons.sync_rounded), label: Text(l.syncNow)),
      ])),
      if (cloud.active) ...[
        const SyncDetails(),
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(cloud.pending == 0 ? l.syncNothingWaiting : l.syncWaiting('${cloud.pending}'), key: const ValueKey('syncWaiting'), style: th.bodyMedium)),
        if (cloud.problem.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.syncProblemLine(cloud.problem), style: th.bodySmall)),
        Text(l.syncOnHelp, style: th.bodySmall),
      ] else if (ref.watch(cloudConfigProvider).configured)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.syncCloudOff, style: th.bodyMedium)),
      if (!cloud.active && s.sync == SyncState.paused) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.syncPausedHelp, style: th.bodyMedium)),
      if (!cloud.active) ...[
      row(l.quotaTitle, l.quotaHelp, Text(l.quotaValue('3'), style: th.titleSmall)),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: 0.03, minHeight: 8, color: context.c.success, backgroundColor: context.c.surfaceAlt)),
      ],
      if (!cloud.active) ...[
      const Divider(height: 24),
      Text(l.demoControls, style: th.labelSmall),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in [(SyncState.synced, l.syncSynced), (SyncState.syncing, l.syncSyncing), (SyncState.offline, l.syncOffline), (SyncState.attention, l.syncAttention('1')), (SyncState.paused, l.syncPaused)])
          ChoiceChip(label: Text(e.$2), selected: s.sync == e.$1, onSelected: (_) => set((x) => x.copyWith(sync: e.$1))),
      ]),
      ],
    ]));

    final security = SectionCard(title: l.setSecurity, child: Column(children: [
      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppLockCard()),
      row(l.signOutEverywhere, l.signOutEverywhereHelp, OutlinedButton(onPressed: () => toast(context, l.demoOnly), child: Text(l.changePassword))),
    ]));

    const people = SecurityCard();
    final demoOn = ref.watch(appModeProvider) == DataMode.demo;
    final demo = SectionCard(title: l.setDemo, child: row(l.setDemoOn, l.setDemoHelp, Switch(key: const ValueKey('demoSwitch'), value: demoOn, onChanged: (v) async {
      final ok = await confirmDialog(context, title: v ? l.setDemoSwitchTitle : l.setDemoLeaveTitle, message: v ? l.setDemoSwitchText : l.setDemoLeaveText, confirmLabel: v ? l.setDemoOn : l.setDemoLeaveTitle.replaceAll('?', ''));
      if (ok) await ref.read(modeSwitcherProvider)(v ? DataMode.demo : DataMode.real);
    })));
    const lan = LanCard();
    const thermal = ThermalCard();
    const diag = DiagnosticsCard();
    const features = FeaturesCard();
    final cards = [look, anim, printing, thermal, sounds, backup, sync, if (s.featureOn(AppFeature.counterLink)) lan, security, people, features, diag, demo];
    return PageFrame(
      title: l.navSettings,
      actions: [if (context.canPop()) TextButton.icon(key: const ValueKey('settings-back'), onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded), label: Text(l.back))],
      child: context.isDesktop
          ? SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [for (final c in [printing, thermal, security, people, backup, diag, demo]) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)])),
                const SizedBox(width: 12),
                Expanded(child: Column(children: [for (final c in [look, anim, sounds, sync, if (s.featureOn(AppFeature.counterLink)) lan, features]) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)])),
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
    final st = effectiveSyncState(ref);
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
    final bk = ref.watch(backupControllerProvider).last;
    final sv = ref.watch(stockValuationProvider).value;
    final counts = ref.watch(shopCountsProvider).value;
    final swapRes = ref.watch(swapResultProvider).value;
    final fixCount = sv == null ? 0 : sv.negatives.length + sv.unpricedProducts;
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
      item(damaged ? Icons.error_outline_rounded : Icons.verified_rounded, damaged ? c.danger : c.success, l.healthIntegrity, damaged ? l.healthDamaged : (problems.isEmpty ? l.healthOk : l.healthProblemsFound(problems.length.toString())),
          help: last == null ? l.healthNeverChecked : l.healthIntegrityHelp(formatDateTime(last)),
          action: OutlinedButton.icon(key: const ValueKey('checkNow'), onPressed: _checking ? null : () => _checkNow(l), icon: _checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search_rounded), label: Text(l.checkNow))),
      item(Icons.save_alt_rounded, backupColor(ref, c), l.lastBackup, bk == null ? l.noBackupYet : formatDateTime(bk), help: l.backupsSubtitle, action: OutlinedButton(key: const ValueKey('healthBackups'), onPressed: () => context.go('/backups'), child: Text(l.healthBackupLink))),
      item(Icons.storage_rounded, info?.freeBytes != null && info!.freeBytes! < 500 * 1024 * 1024 ? c.warning : c.primary, l.freeDisk, info?.freeBytes == null ? l.healthUnknown : _size(info!.freeBytes!), help: l.freeDiskHelp),
      item(Icons.cloud_upload_rounded, (info?.pendingUploads ?? 0) > 0 ? c.warning : c.success, l.syncBacklog, l.syncBacklogValue('${info?.pendingUploads ?? 0}'), help: l.syncBacklogHelp),
      item(Icons.inventory_rounded, problems.isEmpty ? c.success : c.warning, l.healthTotals, problems.isEmpty ? l.healthTotalsOk : l.healthProblemsFound(problems.length.toString()), help: l.healthTotalsHelp, action: OutlinedButton(key: const ValueKey('rebuildTotals'), onPressed: () => _rebuild(l), child: Text(l.rebuildTotals))),
      item(Icons.fact_check_rounded, c.primary, l.healthCountsTitle, counts == null ? l.healthUnknown : l.healthCountsLine('${counts.products}', '${counts.customers}', '${counts.dealers}', '${counts.bills}'),
          help: [if (counts?.lastBill != null) l.healthLastBill(formatDate(counts!.lastBill!)), if (counts?.importedFromErp1 != null) l.healthImportedFrom(formatDate(counts!.importedFromErp1!))].join('. ')),
      item(Icons.account_balance_rounded, (sv?.negatives.isNotEmpty ?? false) ? c.warning : c.primary, l.healthStockValue, sv == null ? l.healthUnknown : '₹ ${formatPaise(sv.shownTotal)}', help: sv == null ? null : '${ruleCaption(l, sv)}. ${l.healthStockValueHelp(sv.negatives.length.toString(), sv.unpricedProducts.toString())}', action: Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton(key: const ValueKey('stockValueDetails'), onPressed: () => showStockValueSheet(context, ref), child: Text(l.stockValueTitle)), if (fixCount > 0) FilledButton(key: const ValueKey('fixThese'), onPressed: () => context.go('/fix'), child: Text(l.fixLink('$fixCount')))])),
      item(Icons.memory_rounded, c.primary, l.databaseSize, info?.fileBytes == null ? l.healthUnknown : _size(info!.fileBytes!), help: l.databaseSizeHelp('1,000,000')),
    ];
    final attention = SectionCard(
      title: l.needsAttention,
      child: problems.isEmpty && (info?.needAttention ?? 0) == 0 && !damaged
          ? Row(children: [Icon(Icons.check_circle_outline_rounded, color: c.success), const SizedBox(width: 8), Expanded(child: Text(l.nothingNeedsAttention))])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final p in problems.take(8)) Padding(padding: const EdgeInsets.only(bottom: 6), child: StatusBadge(p, kind: BadgeKind.danger, icon: Icons.error_outline_rounded)),
              if ((info?.needAttention ?? 0) > 0) StatusBadge(l.syncAttention('${info!.needAttention}'), kind: BadgeKind.danger, icon: Icons.error_outline_rounded),
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
          if (swapRes != null) ...[
            SectionCard(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(swapRes.ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, color: swapRes.ok ? c.success : c.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(swapRes.ok
                      ? (swapRes.kind == 'goback' ? l.swapWentBack(formatDate(swapRes.at)) : swapRes.kind == 'restore' ? l.swapRestored(formatDate(swapRes.at), '${swapRes.counts['products'] ?? '-'}', '${swapRes.counts['customers'] ?? '-'}', '${swapRes.counts['bills'] ?? '-'}') : l.swapImported(formatDate(swapRes.at), '${swapRes.counts['products'] ?? '-'}', '${swapRes.counts['customers'] ?? '-'}', '${swapRes.counts['bills'] ?? '-'}'))
                      : l.swapFailed(swapRes.message)),
                ),
                TextButton(
                  key: const ValueKey('swapGotIt'),
                  onPressed: () async {
                    final dir = ref.read(dataDirProvider);
                    if (dir != null) await clearSwapResult(dir);
                    ref.invalidate(swapResultProvider);
                  },
                  child: Text(l.swapGotIt),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(spacing: 12, runSpacing: 12, children: [for (final k in cards) SizedBox(width: w, child: k)]),
          const SizedBox(height: 12),
          attention,
          const SizedBox(height: 12),
          const GoBackCard(),
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
        if (!isTouchDevice(context)) ...[
        const SizedBox(height: 12),
        SectionCard(title: l.helpShortcuts, child: Column(children: [
          for (final k in keys) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 130, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: context.c.surfaceAlt, borderRadius: BorderRadius.circular(6), border: Border.all(color: context.c.border)), child: Text(k.$1, style: th.labelMedium))), const SizedBox(width: 12), Expanded(child: Text(k.$2))])),
        ])),
        ],
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

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});
  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  bool _checking = false;
  bool _checked = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    await ref.read(updateProvider.notifier).check();
    if (mounted) {
      setState(() {
        _checking = false;
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final update = ref.watch(updateProvider);
    return PageFrame(
      title: l.navAbout,
      child: SingleChildScrollView(child: Align(alignment: Alignment.topLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Column(children: [
        SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const AppLogo(size: 64),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.appName, style: th.headlineSmall), Text(l.aboutVersion(appVersionLabel), key: const ValueKey('about-version'), style: th.bodySmall)])),
          ]),
          const SizedBox(height: 12),
          Text(l.aboutText, style: th.bodyLarge),
        ])),
        const SizedBox(height: 12),
        SectionCard(
          key: const ValueKey('about-update'),
          title: l.updateTitle,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (update != null) ...[
              Text(l.updateReady(update.version), style: th.titleMedium),
              if (update.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(update.notes, style: th.bodySmall)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  key: const ValueKey('update-download'),
                  onPressed: () => ref.read(linkLauncherProvider).open(update.downloadUrl.isNotEmpty ? update.downloadUrl : update.pageUrl),
                  icon: const Icon(Icons.file_download_rounded),
                  label: Text(l.updateDownload),
                ),
                OutlinedButton(onPressed: () => ref.read(linkLauncherProvider).open(update.pageUrl), child: Text(l.updateWhatsNew)),
              ]),
              const SizedBox(height: 6),
              Text(l.updateHow, style: th.bodySmall),
            ] else ...[
              Text(_checked ? l.updateNone(appVersionLabel) : l.updateHelp, style: th.bodyMedium),
              const SizedBox(height: 10),
              OutlinedButton.icon(key: const ValueKey('update-check'), onPressed: _checking ? null : _check, icon: _checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded), label: Text(l.updateCheck)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(title: l.aboutPrivacy, child: Text(l.aboutPrivacyText, style: th.bodyMedium)),
        const SizedBox(height: 12),
        if (!isTouchDevice(context)) OutlinedButton.icon(key: const ValueKey('shortcuts-open'), onPressed: () => showShortcutsDialog(context), icon: const Icon(Icons.keyboard_rounded), label: const Text('Keyboard shortcuts (F1)')),
        if (!isTouchDevice(context)) const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => showLicensePage(context: context, applicationName: l.appName, applicationVersion: appVersionLabel), icon: const Icon(Icons.description_rounded), label: Text(l.aboutLicenses)),
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
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.go(g.items[i].path),
            ),
          ],
        ])),
      ],
    ]);
  }
}

Color backupColor(WidgetRef ref, AppColors c) {
  final f = freshnessOf(ref.read(backupControllerProvider).last, DateTime.now());
  return switch (f) { BackupFreshness.fresh => c.success, BackupFreshness.amber => c.warning, BackupFreshness.red => c.danger };
}


/// Choose the printer once: the computer's default printer, or one of the printers Windows lists; plus a test page.
class PrinterPicker extends ConsumerStatefulWidget {
  const PrinterPicker({super.key, this.labels = false});

  /// The picker for the barcode sticker printer (empty = the bill printer).
  final bool labels;
  @override
  ConsumerState<PrinterPicker> createState() => _PrinterPickerState();
}

class _PrinterPickerState extends ConsumerState<PrinterPicker> {
  late Future<List<PrinterInfo>> _list = ref.read(printerServiceProvider).printers();

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    // a phone has no printer list: it prints through its own print window
    if (isPhone) return Text(l.printPhoneWindow, key: const ValueKey('printPhoneWindow'), style: Theme.of(context).textTheme.bodySmall);
    final st = ref.watch(settingsProvider);
    final name = widget.labels ? st.labelPrinterName : st.printerName;
    return FutureBuilder<List<PrinterInfo>>(
      future: _list,
      builder: (context, snap) {
        final all = snap.data ?? const <PrinterInfo>[];
        final known = all.any((p) => p.name == name);
        return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          if (snap.connectionState == ConnectionState.done && all.isEmpty)
            Text(l.printersNone, key: const ValueKey('printersNone'), style: Theme.of(context).textTheme.bodySmall)
          else
            DropdownButton<String>(
              key: ValueKey(widget.labels ? 'labelPrinterPicker' : 'printerPicker'),
              isExpanded: true,
              value: known ? name : '',
              items: [
                DropdownMenuItem(value: '', child: Text(widget.labels ? l.labelPrinterSame : l.printDefault, overflow: TextOverflow.ellipsis)),
                for (final p in all) DropdownMenuItem(value: p.name, child: Text(p.isPaper ? p.name : '${p.name}  (${l.printerNoPaper})', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => ref.read(settingsProvider.notifier).set((x) => widget.labels ? x.copyWith(labelPrinterName: v ?? '') : x.copyWith(printerName: v ?? '')),
            ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.end, children: [
            if (!widget.labels) TextButton.icon(key: const ValueKey('printersRefresh'), onPressed: () => setState(() => _list = ref.read(printerServiceProvider).printers()), icon: const Icon(Icons.refresh_rounded), label: Text(l.printersRefresh)),
            if (!widget.labels) OutlinedButton.icon(
              key: const ValueKey('printTest'),
              onPressed: () async {
                final bytes = await buildTestPagePdf(shopName: ref.read(shopProvider).name, now: ref.read(clockProvider), printerName: name, l: l);
                if (context.mounted) await printPdfNow(context, ref, bytes, l.printTestTitle);
              },
              icon: const Icon(Icons.print_rounded),
              label: Text(l.printTest),
            ),
          ]),
        ]);
      },
    );
  }
}
