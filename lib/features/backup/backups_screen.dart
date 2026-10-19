import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/data_mode.dart';
import '../../core/date_fmt.dart';
import '../../data/backup/backup.dart';
import '../../data/importer/swap.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/backup_controller.dart';
import '../../fake/data_providers.dart';
import '../../fake/health.dart';
import '../../strings.dart';

/// Asks the person for a folder / a backup file. Replaced in tests so no real dialog is needed.
final folderPickerProvider = Provider<Future<String?> Function()>((ref) => () => getDirectoryPath());
final backupFilePickerProvider = Provider<Future<String?> Function()>((ref) => () async {
      final f = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'ASK ERP backup', extensions: ['sqlite'])]);
      return f?.path;
    });

String kindLabel(Strings l, BackupInfo b) => switch (b.kind) {
      BackupKind.auto => l.kindAuto,
      BackupKind.manual => l.kindManual,
      BackupKind.closing => l.kindClosing,
      BackupKind.safety => l.kindSafety,
      BackupKind.archive => l.kindArchive(b.fy),
    };

String sizeLabel(int bytes) => bytes >= 1024 * 1024 * 1024 ? '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB' : '${(bytes / (1024 * 1024)).ceil()} MB';

String agoLabel(Strings l, DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 2) return l.backupJustNow;
  if (d.inMinutes < 120) return l.backupAgoMinutes('${d.inMinutes}');
  if (d.inHours < 48) return l.backupAgoHours('${d.inHours}');
  return l.backupAgoDays('${d.inDays}');
}

/// One calm line on the Home page: when the last backup was made. Amber after 2 days, red after 7 (or if there never was one). Hidden where backups do not exist.
class BackupStatusLine extends ConsumerWidget {
  const BackupStatusLine({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.watch(backupControllerProvider.notifier);
    if (!ctrl.available) return const SizedBox.shrink();
    final s = ref.watch(backupControllerProvider);
    final l = tr(context);
    final now = DateTime.now();
    final f = freshnessOf(s.last, now);
    final c = context.c;
    final color = switch (f) { BackupFreshness.fresh => c.success, BackupFreshness.amber => c.warning, BackupFreshness.red => c.danger };
    final text = s.last == null ? l.backupNever : l.backupLastLine(agoLabel(l, s.last!, now));
    return InkWell(
      key: const ValueKey('backupStatusLine'),
      onTap: () => context.go('/backups'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(f == BackupFreshness.fresh ? Icons.cloud_done_rounded : Icons.warning_amber_rounded, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color))),
        ]),
      ),
    );
  }
}

class BackupsScreen extends ConsumerStatefulWidget {
  const BackupsScreen({super.key});
  @override
  ConsumerState<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends ConsumerState<BackupsScreen> {
  String? _message;
  bool _copying = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(backupControllerProvider.notifier).load());
  }

  Future<void> _now() async {
    final ok = await ref.read(backupControllerProvider.notifier).run(BackupKind.manual);
    if (mounted && ok) toast(context, tr(context).backupDone);
  }

  Future<void> _pickFolder() async {
    final path = await ref.read(folderPickerProvider)();
    if (path == null) return;
    final err = await ref.read(backupControllerProvider.notifier).setFolder(path);
    if (!mounted) return;
    setState(() => _message = err);
    if (err == null) toast(context, tr(context).backupFolderSaved);
  }

  Future<void> _copy() async {
    final dest = await ref.read(folderPickerProvider)();
    if (dest == null) return;
    setState(() {
      _copying = true;
      _message = null;
    });
    try {
      final to = await ref.read(backupControllerProvider.notifier).copyNewestTo(dest);
      if (mounted) toast(context, tr(context).backupCopyDone(to));
    } on BackupException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final c = context.c;
    final ctrl = ref.watch(backupControllerProvider.notifier);
    final s = ref.watch(backupControllerProvider);
    final list = ref.watch(backupListProvider);
    final now = DateTime.now();
    final fy = previousFinancialYear(now);
    final hasArchive = list.any((b) => b.kind == BackupKind.archive && b.fy == fy);
    Widget body;
    if (!ctrl.available) {
      body = SectionCard(child: Text(l.importNotSupported));
    } else {
      final f = freshnessOf(s.last, now);
      final color = switch (f) { BackupFreshness.fresh => c.success, BackupFreshness.amber => c.warning, BackupFreshness.red => c.danger };
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(f == BackupFreshness.fresh ? Icons.cloud_done_rounded : Icons.warning_amber_rounded, color: color, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(s.last == null ? l.backupNever : l.backupLastLine('${formatDateTime(s.last!)} (${agoLabel(l, s.last!, now)})'), style: th.titleMedium?.copyWith(color: color))),
            ]),
            if (s.lastError != null) ...[
              const SizedBox(height: 8),
              StatusBadge(l.backupFailed(s.lastError!), kind: BadgeKind.danger, icon: Icons.error_outline_rounded),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, children: [
              FilledButton.icon(key: const ValueKey('backupNow'), onPressed: s.running ? null : _now, icon: s.running ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.backup_rounded), label: Text(s.running ? l.backupRunning : l.backupNow)),
              OutlinedButton.icon(key: const ValueKey('restoreLink'), onPressed: () => context.go('/restore'), icon: const Icon(Icons.restore_rounded), label: Text(l.backupRestoreLink)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l.backupFolderTitle,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SelectableText(s.folder ?? '-', style: th.bodyMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 8, children: [
              OutlinedButton(key: const ValueKey('changeFolder'), onPressed: _pickFolder, child: Text(l.backupChangeFolder)),
              TextButton(onPressed: () => ref.read(backupControllerProvider.notifier).useDefaultFolder(), child: Text(l.backupUseDefault)),
            ]),
            if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: StatusBadge(_message!, kind: BadgeKind.danger, icon: Icons.error_outline_rounded)),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l.backupCopyTitle,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.backupCopyHelp, style: th.bodySmall),
            const SizedBox(height: 8),
            OutlinedButton.icon(key: const ValueKey('copyBackup'), onPressed: _copying ? null : _copy, icon: const Icon(Icons.usb_rounded), label: Text(l.backupCopyButton)),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l.backupYearlyTitle,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.backupYearlyHelp, style: th.bodySmall),
            const SizedBox(height: 8),
            if (hasArchive) Row(children: [Icon(Icons.check_circle_outline_rounded, color: c.success), const SizedBox(width: 8), Expanded(child: Text(l.backupYearlyHave(fy)))]) else FilledButton(key: const ValueKey('makeYearly'), onPressed: s.running ? null : () => ref.read(backupControllerProvider.notifier).run(BackupKind.archive, fy: fy), child: Text(l.backupYearlyMake(fy))),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l.backupListTitle,
          child: list.isEmpty
              ? Text(l.backupNone)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final b in list.take(15)) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(l.backupItem(formatDateTime(b.at), kindLabel(l, b), sizeLabel(b.bytes)))),
                ]),
        ),
      ]);
    }
    return PageFrame(title: l.navBackups, subtitle: l.backupsSubtitle, child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: body)));
  }
}

class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});
  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  String? _path, _name, _message;
  BackupInspection? _inspection;
  bool _checking = false, _working = false;
  String _stage = '';

  Future<void> _inspect(String path, String name) async {
    setState(() {
      _checking = true;
      _path = path;
      _name = name;
      _inspection = null;
      _message = null;
    });
    final id = await ref.read(appDataProvider).settings.get('shop.id') ?? '';
    final r = await inspectBackup(path, expectedShopId: id);
    if (!mounted) return;
    setState(() {
      _inspection = r;
      _checking = false;
    });
  }

  Future<void> _choose() async {
    final path = await ref.read(backupFilePickerProvider)();
    if (path == null) return;
    await _inspect(path, path.split(RegExp(r'[\\/]')).last);
  }

  String _problemText(Strings l, RestoreProblem p) => switch (p) {
        RestoreProblem.notDatabase => l.restoreRefusedNotDb,
        RestoreProblem.corrupt => l.restoreRefusedCorrupt,
        RestoreProblem.tooNew => l.restoreRefusedNewer,
        RestoreProblem.otherShop => l.restoreRefusedOther,
        RestoreProblem.unknownShop => l.restoreRefusedUnknown,
        RestoreProblem.none => '',
      };

  Future<void> _restore() async {
    final l = tr(context);
    final dir = ref.read(dataDirProvider);
    if (dir == null || _path == null) return;
    final ok = await confirmDialog(context, title: l.restoreTitle, message: l.restoreConfirm, confirmLabel: l.restoreNow);
    if (!ok || !mounted) return;
    setState(() {
      _working = true;
      _stage = l.restoreSafetyMaking;
      _message = null;
    });
    final good = await ref.read(backupControllerProvider.notifier).run(BackupKind.safety);
    if (!mounted) return;
    if (!good) {
      setState(() {
        _working = false;
        _message = l.restoreFailedSafety(ref.read(backupControllerProvider).lastError ?? '');
      });
      return;
    }
    setState(() => _stage = l.restoreWorking);
    try {
      await requestRestore(dataDir: dir, backupFile: _path!, source: _name ?? '');
      await ref.read(modeSwitcherProvider)(DataMode.real);
    } catch (e) {
      if (mounted) {
        setState(() {
          _working = false;
          _message = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final c = context.c;
    final ctrl = ref.watch(backupControllerProvider.notifier);
    final list = ref.watch(backupListProvider);
    final restorable = [for (final b in list) if (b.kind != BackupKind.archive) b];
    final archives = [for (final b in list) if (b.kind == BackupKind.archive) b];
    Widget item(BackupInfo b) => ListTile(
          key: ValueKey('pick-${b.name}'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l.backupItem(formatDateTime(b.at), kindLabel(l, b), sizeLabel(b.bytes))),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _working ? null : () => _inspect(b.path, b.name),
        );
    Widget body;
    if (!ctrl.available) {
      body = SectionCard(child: Text(l.importNotSupported));
    } else if (_working) {
      body = SectionCard(title: _stage, child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()));
    } else {
      final r = _inspection;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionCard(child: Text(l.restoreScreenHelp, style: th.bodyMedium)),
        const SizedBox(height: 12),
        if (_checking) SectionCard(title: l.restoreChecking, child: const LinearProgressIndicator()),
        if (r != null) ...[
          SectionCard(
            title: _name,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!r.ok) StatusBadge(_problemText(l, r.problem), kind: BadgeKind.danger, icon: Icons.error_outline_rounded),
              if (r.contents != null && r.problem != RestoreProblem.notDatabase && r.problem != RestoreProblem.corrupt)
                Text(l.restoreContents('${r.contents!.products}', '${r.contents!.customers}', '${r.contents!.bills}', r.contents!.lastBill == null ? '-' : formatDate(r.contents!.lastBill!), r.contents!.madeAt == null ? '-' : formatDateTime(r.contents!.madeAt!)), style: th.bodyMedium),
              if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: StatusBadge(_message!, kind: BadgeKind.danger, icon: Icons.error_outline_rounded)),
              if (r.ok) Padding(padding: const EdgeInsets.only(top: 10), child: FilledButton.icon(key: const ValueKey('restoreNow'), onPressed: _restore, icon: const Icon(Icons.restore_rounded), label: Text(l.restoreNow))),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        if (_message != null && r == null) ...[StatusBadge(_message!, kind: BadgeKind.danger, icon: Icons.error_outline_rounded), const SizedBox(height: 12)],
        SectionCard(
          title: l.restoreFromList,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (restorable.isEmpty) Text(l.backupNone) else for (final b in restorable.take(20)) item(b),
            const SizedBox(height: 8),
            OutlinedButton.icon(key: const ValueKey('chooseBackupFile'), onPressed: _choose, icon: const Icon(Icons.folder_open_rounded), label: Text(l.restoreChooseFile)),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l.restoreOldYear,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.restoreOldYearHelp, style: th.bodySmall),
            const SizedBox(height: 6),
            if (archives.isEmpty) Text(l.backupNone, style: TextStyle(color: c.textMuted)) else for (final b in archives) item(b),
          ]),
        ),
      ]);
    }
    return PageFrame(title: l.restoreTitle, subtitle: l.restoreSubtitle, child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: body)));
  }
}
