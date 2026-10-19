import 'package:flutter/material.dart';
import '../../core/validators.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/segments.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain/credit/dues.dart';
import '../../domain/credit/reminder.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart' show CreditLimitMode, clockProvider;

/// Shop profile > Messages to customers: the WhatsApp message (two ready tones, editable), shop phone, UPI ID, the 24-hour guard, country code.
class RemindersCard extends ConsumerStatefulWidget {
  const RemindersCard({super.key});
  @override
  ConsumerState<RemindersCard> createState() => _RemindersCardState();
}

class _RemindersCardState extends ConsumerState<RemindersCard> {
  final _template = TextEditingController();
  ReminderTone? _loaded;

  @override
  void dispose() {
    _template.dispose();
    super.dispose();
  }

  void _load(ShopProfile s) {
    if (_loaded == s.reminderTone) return;
    _loaded = s.reminderTone;
    _template.text = s.reminderTone == ReminderTone.friendly ? s.templateFriendly : s.templateFirm;
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final s = ref.watch(shopProvider);
    final set = ref.read(shopProvider.notifier).set;
    _load(s);
    final today = ref.watch(clockProvider);
    final sample = ReminderInput(
      customerName: 'Murugan Electricals',
      shopName: s.name,
      shopPhone: s.phone,
      upiId: s.upiId,
      today: today,
      lastPaymentDate: today.subtract(const Duration(days: 40)),
      bills: [
        BillDue(billNo: 'A-019804', date: today.subtract(const Duration(days: 64)), totalPaise: 250000, paidPaise: 100000),
        BillDue(billNo: 'A-019851', date: today.subtract(const Duration(days: 33)), totalPaise: 120000, paidPaise: 0),
      ],
    );
    final preview = buildReminderMessage(_template.text, sample);

    void insert(String ph) {
      final sel = _template.selection;
      final t = _template.text;
      final at = sel.isValid ? sel.start : t.length;
      final end = sel.isValid ? sel.end : t.length;
      _template.value = TextEditingValue(text: t.replaceRange(at, end, ph), selection: TextSelection.collapsed(offset: at + ph.length));
      _save(s);
    }

    return SectionCard(
      title: l.setReminders,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.setRemNote, style: th.bodySmall),
        const SizedBox(height: 12),
        Text(l.setRemTone, style: th.titleSmall),
        const SizedBox(height: 6),
        SlideSegments<ReminderTone>(
          options: [(ReminderTone.friendly, l.toneFriendly, null), (ReminderTone.firm, l.toneFirm, null)],
          selected: s.reminderTone,
          onChanged: (v) => set((x) => x.copyWith(reminderTone: v)),
        ),
        const SizedBox(height: 12),
        Text(l.setRemTemplate, style: th.titleSmall),
        const SizedBox(height: 6),
        TextField(key: const ValueKey('templateField'), controller: _template, inputFormatters: [safeInput(TextKind.message)], minLines: 6, maxLines: 12, onChanged: (_) => _save(s), decoration: const InputDecoration(alignLabelWithHint: true)),
        const SizedBox(height: 8),
        Text(l.setRemUse, style: th.bodySmall),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final p in reminderPlaceholders) ActionChip(label: Text(p), onPressed: () => insert(p))]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              final std = s.reminderTone == ReminderTone.friendly ? defaultFriendlyTemplate : defaultFirmTemplate;
              _template.text = std;
              _save(s);
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(l.setRemReset),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: context.c.border.withValues(alpha: 0.5))),
          child: Text(preview, style: th.bodyMedium),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (ctx, bc) {
          final two = bc.maxWidth > 560;
          Widget field(String label, String value, ValueChanged<String> on, {TextInputType? type, List<TextInputFormatter>? fmt, Key? key}) =>
              TextFormField(key: key, initialValue: value, keyboardType: type, inputFormatters: fmt, onChanged: on, decoration: InputDecoration(labelText: label));
          final f = [
            field(l.setGuard, '${s.guardHours}', (v) => set((x) => x.copyWith(guardHours: (int.tryParse(v) ?? 24).clamp(0, 720))), type: TextInputType.number, fmt: [FilteringTextInputFormatter.digitsOnly], key: const ValueKey('guardHours')),
            field(l.setCountry, s.countryCode, (v) => set((x) => x.copyWith(countryCode: v.isEmpty ? '91' : v)), type: TextInputType.number, fmt: [FilteringTextInputFormatter.digitsOnly]),
          ];
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final w in f) SizedBox(width: two ? (bc.maxWidth - 12) / 2 : bc.maxWidth, child: w)]);
        }),
      ]),
    );
  }

  void _save(ShopProfile s) {
    final set = ref.read(shopProvider.notifier).set;
    if (s.reminderTone == ReminderTone.friendly) {
      set((x) => x.copyWith(templateFriendly: _template.text));
    } else {
      set((x) => x.copyWith(templateFirm: _template.text));
    }
    setState(() {});
  }
}

/// Shop profile > Credit: what happens when a bill takes a customer over their limit.
class CreditSettingsCard extends ConsumerWidget {
  const CreditSettingsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final s = ref.watch(shopProvider);
    return SectionCard(
      title: l.setCreditTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.setLimitMode, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SlideSegments<CreditLimitMode>(
          options: [(CreditLimitMode.off, l.limitOff, null), (CreditLimitMode.warn, l.limitWarn, null), (CreditLimitMode.block, l.limitBlock, null)],
          selected: s.creditLimitMode,
          onChanged: (v) => ref.read(shopProvider.notifier).set((x) => x.copyWith(creditLimitMode: v)),
        ),
      ]),
    );
  }
}
