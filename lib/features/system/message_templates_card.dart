import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date_fmt.dart';
import '../../core/validators.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain/message_templates.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart' show clockProvider;

/// Shop profile > WhatsApp messages: the words of the bill, estimate, statement and order messages, each editable, with the details put in by a tap,
/// a "back to the standard text" button and a preview. The payment reminder has its own card (it has two tones).
class MessageTemplatesCard extends ConsumerStatefulWidget {
  const MessageTemplatesCard({super.key});
  @override
  ConsumerState<MessageTemplatesCard> createState() => _MessageTemplatesCardState();
}

class _MessageTemplatesCardState extends ConsumerState<MessageTemplatesCard> {
  final _text = TextEditingController();
  MessageKind _kind = MessageKind.bill;
  MessageKind? _loaded;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _load(ShopProfile s) {
    if (_loaded == _kind) return;
    _loaded = _kind;
    _text.text = messageTemplateOf(s.messageTemplates, _kind);
  }

  /// Keeps the shop's own text; the standard text (or nothing at all) is not kept, so the message follows the standard text.
  void _save(String text) {
    ref.read(shopProvider.notifier).set((x) {
      final m = {...x.messageTemplates};
      if (text.trim().isEmpty || text == defaultMessage(_kind)) {
        m.remove(_kind.name);
      } else {
        m[_kind.name] = text;
      }
      return x.copyWith(messageTemplates: m);
    });
    setState(() {});
  }

  void _insert(String ph) {
    final sel = _text.selection;
    final t = _text.text;
    final at = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    _text.value = TextEditingValue(text: t.replaceRange(at, end, ph), selection: TextSelection.collapsed(offset: at + ph.length));
    _save(_text.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final s = ref.watch(shopProvider);
    _load(s);
    String label(MessageKind k) => switch (k) { MessageKind.bill => l.msgTplBill, MessageKind.estimate => l.msgTplEstimate, MessageKind.statement => l.msgTplStatement, MessageKind.order => l.msgTplOrder };
    final preview = fillMessage(messageTemplateOf(s.messageTemplates, _kind), sampleMessageValues(_kind, shopName: s.name, shopPhone: s.phone, upiId: s.upiId, today: formatDate(ref.watch(clockProvider))));
    return SectionCard(
      title: l.msgTplTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.msgTplHelp, style: th.bodySmall),
        const SizedBox(height: 12),
        Text(l.msgTplWhich, style: th.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in messageKindOrder)
            ChoiceChip(
              key: ValueKey('msg-kind-${k.name}'),
              label: Text(label(k)),
              selected: _kind == k,
              onSelected: (_) => setState(() => _kind = k),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('msgTplField'),
          controller: _text,
          inputFormatters: [safeInput(TextKind.message)],
          minLines: 6,
          maxLines: 14,
          onChanged: _save,
          decoration: InputDecoration(labelText: label(_kind), alignLabelWithHint: true),
        ),
        const SizedBox(height: 8),
        Text(l.setRemUse, style: th.bodySmall),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final p in messagePlaceholders(_kind)) ActionChip(key: ValueKey('msg-ph-$p'), label: Text(p), onPressed: () => _insert(p))]),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('msgTplReset'),
          onPressed: () {
            _text.text = defaultMessage(_kind);
            _save(_text.text);
          },
          icon: const Icon(Icons.restart_alt_rounded),
          label: Text(l.msgTplReset),
        ),
        const SizedBox(height: 14),
        Text(l.msgTplPreview, style: th.titleSmall),
        const SizedBox(height: 6),
        Container(
          key: const ValueKey('msgTplPreview'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: context.c.border.withValues(alpha: 0.5))),
          child: Text(preview, style: th.bodyMedium),
        ),
      ]),
    );
  }
}
