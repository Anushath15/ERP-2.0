import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data_mode.dart';
import '../../core/date_fmt.dart';
import '../../data/importer/swap.dart';
import '../../design/effects.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/data_providers.dart';
import '../../fake/health.dart';
import '../../import/erp1/checksum.dart';
import '../../import/erp1/outcome.dart';
import '../../import/erp1/preview.dart';
import '../../import/erp1/report.dart' show qty, rupees;
import '../../strings.dart';
import 'import_providers.dart';

enum _Step { choose, checking, preview, creating, created, switching }

/// "Import from ERP 1": choose the backup copy, read what was found in plain words, create the new data (nothing live is touched), see the checks,
/// and only then, on a second confirmation, switch to it. The old data is put aside for 30 days.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});
  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _Step _step = _Step.choose;
  ImportPreview? _preview;
  ImportOutcome? _outcome;
  String? _text, _name, _message;
  String _stage = '';

  Future<void> _choose() async {
    final pick = await ref.read(backupPickerProvider)();
    if (pick == null || !mounted) return;
    if (pick.bytes > maxBackupBytes) {
      setState(() {
        _preview = ImportPreview.failed('This file is larger than 1.5 GB, so it is not an ERP 1 backup. Nothing was changed.', pick.name);
        _step = _Step.preview;
      });
      return;
    }
    setState(() {
      _step = _Step.checking;
      _message = null;
    });
    String text;
    try {
      text = await pick.read();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preview = ImportPreview.failed('The file could not be read as text, so it is not an ERP 1 backup. Nothing was changed.', pick.name);
        _step = _Step.preview;
      });
      return;
    }
    final p = await ref.read(importRunnerProvider).preview(text, pick.name);
    if (!mounted) return;
    setState(() {
      _text = p.ok ? text : null;
      _name = pick.name;
      _preview = p;
      _step = _Step.preview;
    });
  }

  String _stageText(Strings l, String s) => switch (s) { 'writing' => l.importStageWriting, 'checking' => l.importStageChecking, _ => l.importStageReading };

  Future<void> _create() async {
    final dir = ref.read(dataDirProvider);
    if (dir == null || _text == null) return;
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final out = '$dir/import/erp1-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}.sqlite';
    setState(() {
      _step = _Step.creating;
      _stage = 'reading';
    });
    final o = await ref.read(importRunnerProvider).create(_text!, _name ?? '', out, (s) {
      if (mounted) setState(() => _stage = s);
    });
    if (!mounted) return;
    setState(() {
      _outcome = o;
      _step = _Step.created;
    });
  }

  Future<void> _switch() async {
    final dir = ref.read(dataDirProvider);
    final o = _outcome;
    if (dir == null || o == null) return;
    setState(() => _step = _Step.switching);
    try {
      await requestImportSwap(dataDir: dir, newFile: o.newFile, expected: o.counts, source: _name ?? '');
      await ref.read(modeSwitcherProvider)(DataMode.real); // closes the current data, then the start-up does the switch and opens the new data
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = tr(context).importSwitchFailed('$e');
        _step = _Step.created;
      });
    }
  }

  void _reset() => setState(() {
        _step = _Step.choose;
        _preview = null;
        _outcome = null;
        _text = null;
        _message = null;
      });

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final dir = ref.watch(dataDirProvider);
    final supported = dir != null && ref.watch(importRunnerProvider).supported;
    Widget body;
    if (!supported) {
      body = SectionCard(child: Text(l.importNotSupported));
    } else {
      body = switch (_step) {
        _Step.choose => _chooseCard(l),
        _Step.checking => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionCard(title: l.importChecking, child: const SizedBox.shrink()),
            const SizedBox(height: 200, child: DelayedLoader(loading: true, skeleton: SkeletonBlocks(rows: 3), child: SizedBox.shrink())),
          ]),
        _Step.preview => _previewBody(l),
        _Step.creating => SectionCard(title: _stageText(l, _stage), child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator())),
        _Step.created => _createdBody(l),
        _Step.switching => SectionCard(title: l.importSwitching, child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator())),
      };
    }
    return PageFrame(
      title: l.navImport,
      subtitle: l.importSubtitle,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: body),
      ),
    );
  }

  Widget _chooseCard(Strings l) {
    final th = Theme.of(context).textTheme;
    return SectionCard(
      title: l.chooseBackupFile,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.importHelp, style: th.bodyMedium),
        const SizedBox(height: 14),
        FilledButton.icon(key: const ValueKey('chooseBackup'), onPressed: _choose, icon: const Icon(Icons.folder_open), label: Text(l.chooseBackupFile)),
        const SizedBox(height: 8),
        Text(l.importSafe, style: th.bodySmall),
      ]),
    );
  }

  Widget _previewBody(Strings l) {
    final p = _preview!;
    final th = Theme.of(context).textTheme;
    final c = context.c;
    if (!p.ok) {
      return SectionCard(
        title: l.importCannotUse,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusBadge(p.error, kind: BadgeKind.danger, icon: Icons.error_outline),
          const SizedBox(height: 8),
          Text(l.importNothingChanged, style: th.bodySmall),
          const SizedBox(height: 12),
          OutlinedButton.icon(key: const ValueKey('chooseAnother'), onPressed: _reset, icon: const Icon(Icons.folder_open), label: Text(l.importChooseAnother)),
        ]),
      );
    }
    Widget line(String t, {IconData icon = Icons.check, Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: color ?? c.success), const SizedBox(width: 8), Expanded(child: Text(t))]));
    final n = p.counts;
    final checksum = p.checksum == ChecksumResult.ok.name ? l.importChecksumOk : (p.checksumBad ? l.importChecksumBad : l.importChecksumNone);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionCard(
        title: l.importWhatWeFound,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.importFileName(p.fileName), style: th.bodySmall),
          line(checksum, icon: p.checksumBad ? Icons.error_outline : Icons.verified_outlined, color: p.checksumBad ? c.danger : c.success),
          line(l.importCountsLine('${n['products'] ?? 0}', '${n['customers'] ?? 0}', '${n['dealers'] ?? 0}', '${n['bills'] ?? 0}', '${n['estimates'] ?? 0}')),
          line(l.importSalesLine(rupees(p.salesPaise), '${p.bills}', p.thisMonth.isEmpty ? '-' : p.thisMonth, rupees(p.thisMonthSalesPaise))),
          line(l.importOwedLine('${p.customersOwing}', rupees(p.customersOwedPaise))),
          line(l.importStockQtyLine(qty(p.stockQtyMilli))),
        ]),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: l.importValueTitle,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          line(l.importValueAvg(rupees(p.valueAverage))),
          line(l.importValueBuy(rupees(p.valueBuying))),
          line(l.importValueSell(rupees(p.valueSelling))),
          if (p.unpricedProducts > 0) line(l.importNoCostLine('${p.unpricedProducts}'), icon: Icons.warning_amber_rounded, color: c.warning),
          if (p.negatives.isNotEmpty) line(l.importNegativeLine('${p.negatives.length}'), icon: Icons.warning_amber_rounded, color: c.warning),
        ]),
      ),
      if (p.rejected > 0 || p.repaired > 0 || p.corrections.isNotEmpty || p.decisions.isNotEmpty) ...[
        const SizedBox(height: 12),
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.rejected > 0) line(l.importRejectedLine('${p.rejected}'), icon: Icons.error_outline, color: c.danger),
            if (p.repaired > 0) line(l.importRepairedLine('${p.repaired}'), icon: Icons.build_outlined, color: c.warning),
            if (p.corrections.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.importCorrectionsTitle, style: th.titleSmall)),
              for (final t in p.corrections) line(t),
            ],
            if (p.decisions.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.importDecisionsTitle, style: th.titleSmall)),
              for (final t in p.decisions) line(t, icon: Icons.help_outline, color: c.warning),
            ],
          ]),
        ),
      ],
      const SizedBox(height: 12),
      ExpansionTile(
        key: const ValueKey('fullReport'),
        title: Text(l.importFullReport),
        children: [
          SelectableText(p.reportText, style: th.bodySmall?.copyWith(fontFamily: 'monospace')),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: p.reportText));
                if (mounted) toast(context, l.importReportCopied);
              },
              icon: const Icon(Icons.copy),
              label: Text(l.importCopyReport),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(l.importCreateHelp, style: th.bodySmall),
      Text(l.importNothingChanged, style: th.bodySmall),
      const SizedBox(height: 10),
      Row(children: [
        OutlinedButton(onPressed: _reset, child: Text(l.cancel)),
        const SizedBox(width: 10),
        Expanded(child: FilledButton.icon(key: const ValueKey('createNewData'), onPressed: p.canImport ? _create : null, icon: const Icon(Icons.download_done), label: Text(l.importCreate))),
      ]),
    ]);
  }

  Widget _createdBody(Strings l) {
    final o = _outcome!;
    final th = Theme.of(context).textTheme;
    final c = context.c;
    Widget line(bool ok, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(ok ? Icons.check : Icons.error_outline, size: 18, color: ok ? c.success : c.danger), const SizedBox(width: 8), Expanded(child: Text(t))]));
    if (!o.ok) {
      return SectionCard(
        title: l.importCannotUse,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusBadge(o.error, kind: BadgeKind.danger, icon: Icons.error_outline),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _reset, child: Text(l.importDifferentFile)),
        ]),
      );
    }
    final n = o.counts;
    return SectionCard(
      title: o.allChecksPassed ? l.importCreated : l.importChecksTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.importNewHolds('${n['products'] ?? 0}', '${n['customers'] ?? 0}', '${n['bills'] ?? 0}'), style: th.titleSmall),
        const SizedBox(height: 6),
        line(o.verified && o.mismatches.isEmpty, l.importCheckWritten),
        line(o.integrity == 'ok', l.importCheckIntegrity),
        line(o.selfCheckProblems.isEmpty, l.importCheckSelf),
        for (final m in [...o.mismatches, ...o.selfCheckProblems]) line(false, l.importCheckFailed(m)),
        const SizedBox(height: 12),
        if (_message != null) StatusBadge(_message!, kind: BadgeKind.danger, icon: Icons.error_outline),
        if (o.allChecksPassed) ...[
          Text(l.importSwitchTitle, style: th.titleMedium),
          Text(l.importSwitchHelp, style: th.bodyMedium),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(key: const ValueKey('switchNow'), onPressed: _switch, icon: const Icon(Icons.swap_horiz), label: Text(l.importSwitchNow)),
            OutlinedButton(onPressed: _reset, child: Text(l.importNotNow)),
          ]),
        ] else
          OutlinedButton(onPressed: _reset, child: Text(l.importDifferentFile)),
      ]),
    );
  }
}

/// Shown on the Health page after a data switch, and from Settings: the earlier data that can still be gone back to.
class GoBackCard extends ConsumerWidget {
  const GoBackCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final prev = ref.watch(previousDataProvider).value ?? const <PreviousData>[];
    if (prev.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: l.goBackTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.goBackHelp, style: th.bodySmall),
        for (final x in prev.take(3)) ...[
          const SizedBox(height: 8),
          Text(l.goBackItem(formatDate(x.at), '${x.products ?? '-'}', '${x.customers ?? '-'}', '${x.bills ?? '-'}', formatDate(x.offeredUntil))),
          const SizedBox(height: 4),
          OutlinedButton(
            key: ValueKey('goBack-${x.stamp}'),
            onPressed: () async {
              final ok = await confirmDialog(context, title: l.goBackTitle, message: l.goBackConfirm, confirmLabel: l.goBackNow);
              if (!ok) return;
              final dir = ref.read(dataDirProvider);
              if (dir == null) return;
              await requestGoBack(dataDir: dir, stamp: x.stamp);
              await ref.read(modeSwitcherProvider)(DataMode.real);
            },
            child: Text(l.goBackNow),
          ),
        ],
      ]),
    );
  }
}
