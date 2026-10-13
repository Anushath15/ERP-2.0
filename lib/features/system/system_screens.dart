import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/responsive.dart';
import '../../design/form_sheet.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/store.dart';
import '../../nav.dart';
import 'appearance_cards.dart';
import 'reminder_settings.dart';

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

    final shop = SectionCard(title: l.setShop, child: Column(children: [
      row(l.setShopName, s.shopName, OutlinedButton(onPressed: () async {
        final v = await showFormSheet(context, title: l.setShop, saveLabel: l.save, fields: [FieldSpec('name', l.setShopName, initial: s.shopName, required: true, autofocus: true), FieldSpec('gstin', 'GSTIN', initial: s.gstin), FieldSpec('addr', l.fieldAddress, type: FieldType.multiline, initial: '12 Market Street, Coimbatore - 641001'), FieldSpec('phone', l.fieldPhone, type: FieldType.phone, initial: '98765 43210')]);
        if (v != null) set((x) => x.copyWith(shopName: v['name'], gstin: v['gstin']));
      }, child: Text(l.edit))),
      row('GSTIN', s.gstin, const SizedBox.shrink()),
      row(l.setLogo, l.setLogoHelp, OutlinedButton.icon(onPressed: () => toast(context, l.demoOnly), icon: const Icon(Icons.image_outlined), label: Text(l.chooseFile))),
    ]));

    final tax = SectionCard(title: l.setTax, child: Column(children: [
      row(l.setPricesIncludeGst, l.setPricesIncludeGstHelp, Switch(value: s.pricesIncludeGst, onChanged: (v) => set((x) => x.copyWith(pricesIncludeGst: v)))),
      row(l.setRoundOff, l.setRoundOffHelp, Switch(value: true, onChanged: (_) => toast(context, l.demoOnly))),
    ]));

    final printing = SectionCard(title: l.setPrinting, child: Column(children: [
      row(l.setPaper, l.setPaperHelp, SegmentedButton<PaperSize>(showSelectedIcon: false, segments: [ButtonSegment(value: PaperSize.a4, label: Text(l.paperA4)), ButtonSegment(value: PaperSize.mm80, label: Text(l.paper80)), ButtonSegment(value: PaperSize.mm58, label: Text(l.paper58))], selected: {s.paper}, onSelectionChanged: (v) => set((x) => x.copyWith(paper: v.first)))),
      row(l.setPrinter, l.setPrinterHelp, OutlinedButton(onPressed: () => context.push('/print'), child: Text(l.printPreview))),
    ]));

    const look = AppearanceCard();
    const anim = AnimationsCard();
    const sounds = SoundsCard();
    const reminders = RemindersCard();
    const creditCard = CreditSettingsCard();

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
        FilledButton.icon(onPressed: s.sync == SyncState.offline ? null : () async {
          set((x) => x.copyWith(sync: SyncState.syncing));
          await Future<void>.delayed(const Duration(milliseconds: 600));
          if (mounted) set((x) => x.copyWith(sync: SyncState.synced));
        }, icon: const Icon(Icons.sync), label: Text(l.syncNow)),
      ])),
      row(l.quotaTitle, l.quotaHelp, Text(l.quotaValue('3'), style: th.titleSmall)),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: 0.03, minHeight: 8, color: context.c.success, backgroundColor: context.c.surfaceAlt)),
      const Divider(height: 24),
      Text(l.demoControls, style: th.labelSmall),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in [(SyncState.synced, l.syncSynced), (SyncState.syncing, l.syncSyncing), (SyncState.offline, l.syncOffline), (SyncState.attention, l.syncAttention('1'))])
          ChoiceChip(label: Text(e.$2), selected: s.sync == e.$1, onSelected: (_) => set((x) => x.copyWith(sync: e.$1))),
      ]),
    ]));

    final security = SectionCard(title: l.setSecurity, child: Column(children: [
      row(l.setPin, l.setPinHelp, Switch(value: _pin, onChanged: (v) => setState(() => _pin = v))),
      row(l.signOutEverywhere, l.signOutEverywhereHelp, OutlinedButton(onPressed: () => toast(context, l.demoOnly), child: Text(l.changePassword))),
    ]));

    final cards = [look, anim, shop, tax, printing, creditCard, reminders, sounds, backup, sync, security];
    return PageFrame(
      title: l.navSettings,
      child: context.isDesktop
          ? SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [for (final c in [shop, tax, printing, creditCard, reminders, security]) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)])),
                const SizedBox(width: 12),
                Expanded(child: Column(children: [for (final c in [look, anim, sounds, backup, sync]) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)])),
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
    final (label, kind) = switch (st) { SyncState.synced => (l.syncSynced, BadgeKind.success), SyncState.syncing => (l.syncSyncing, BadgeKind.info), SyncState.offline => (l.syncOffline, BadgeKind.warning), SyncState.attention => (l.syncAttention('1'), BadgeKind.danger) };
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
  bool _fixed = false;

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final now = ref.watch(clockProvider);
    final th = Theme.of(context).textTheme;
    final c = context.c;
    Widget item(IconData icon, Color color, String title, String value, {String? help, Widget? action}) => SectionCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: th.bodySmall), Text(value, style: th.titleMedium), if (help != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(help, style: th.bodySmall)), if (action != null) Padding(padding: const EdgeInsets.only(top: 8), child: action)])),
          ]),
        );
    final cards = [
      item(Icons.verified_outlined, c.success, l.healthIntegrity, l.healthOk, help: l.healthIntegrityHelp(formatDateTime(now.subtract(const Duration(hours: 2)))), action: OutlinedButton.icon(onPressed: _checking ? null : () async { setState(() => _checking = true); await Future<void>.delayed(const Duration(milliseconds: 700)); if (context.mounted) { setState(() => _checking = false); toast(context, l.healthChecked); } }, icon: _checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search), label: Text(l.checkNow))),
      item(Icons.save_alt, c.success, l.lastBackup, formatDateTime(now.subtract(const Duration(hours: 5))), help: l.backupsKept('30'), action: FilledButton.icon(onPressed: () => toast(context, l.backupDone), icon: const Icon(Icons.save_alt), label: Text(l.backupNow))),
      item(Icons.storage_outlined, c.primary, l.freeDisk, '212 GB', help: l.freeDiskHelp),
      item(Icons.cloud_upload_outlined, c.warning, l.syncBacklog, l.syncBacklogValue('0'), help: l.syncBacklogHelp),
      item(Icons.inventory_outlined, c.success, l.healthTotals, l.healthTotalsOk, help: l.healthTotalsHelp, action: OutlinedButton(onPressed: () => toast(context, l.healthChecked), child: Text(l.rebuildTotals))),
      item(Icons.memory, c.primary, l.databaseSize, '116 MB', help: l.databaseSizeHelp('50,000')),
    ];
    final attention = SectionCard(
      title: l.needsAttention,
      child: _fixed
          ? Row(children: [Icon(Icons.check_circle_outline, color: c.success), const SizedBox(width: 8), Expanded(child: Text(l.nothingNeedsAttention))])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              StatusBadge(l.attentionItem, kind: BadgeKind.danger, icon: Icons.error_outline),
              const SizedBox(height: 8),
              Text(l.attentionHelp, style: th.bodyMedium),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton(onPressed: () => setState(() => _fixed = true), child: Text(l.tryAgain)),
                OutlinedButton(onPressed: () => toast(context, l.demoOnly), child: Text(l.sendLog)),
              ]),
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
    final keys = <(String, String)>[('F2', l.keyNewBill), ('F3', l.keyNewEstimate), ('F4', l.navSalesRegister), ('F5', l.navProducts), ('F8', l.preview), ('F9', l.saveAndPrint), ('Ctrl+S', l.keySave), ('Ctrl+Shift+N', l.keyNewProduct), ('Ctrl+Shift+L', l.keyFill100), ('Esc', l.keyCancel), ('↑ ↓ Enter', l.keyPick)];
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
            Container(width: 56, height: 56, decoration: BoxDecoration(color: context.c.primary, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.storefront, color: context.c.onPrimary, size: 32)),
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
