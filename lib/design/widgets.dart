import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/responsive.dart';
import '../core/touch_device.dart';
import '../strings.dart';
import 'effects.dart';
import 'motion.dart';
import 'tokens.dart';

/// The words of the program: the phone version on a real phone or tablet (no "computer", no Windows, no keyboard keys), the normal one elsewhere.
Strings tr(BuildContext context) => isTouchDevice(context) ? const PhoneStrings() : const Strings();

enum BadgeKind { success, warning, danger, info, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.kind = BadgeKind.neutral, this.icon});
  final String label;
  final BadgeKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (kind) {
      BadgeKind.success => (c.badgeBgSuccess, c.success),
      BadgeKind.warning => (c.badgeBgWarning, c.warning),
      BadgeKind.danger => (c.badgeBgDanger, c.danger),
      BadgeKind.info => (c.badgeBgInfo, c.info),
      BadgeKind.neutral => (c.surfaceAlt, c.text),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: fg.withValues(alpha: 0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
        Flexible(child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700, height: 1.2))),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.text, this.action});
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: FadeSlideIn(
          dy: 10,
          ms: 250,
          child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 56, color: context.c.textMuted),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              if (text != null) ...[const SizedBox(height: 6), Text(text!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.c.textMuted), textAlign: TextAlign.center)],
              if (action != null) ...[const SizedBox(height: 16), action!],
            ]),
          ),
        )),
      );
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(16)});
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) ...[
              Row(children: [Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium)), ?trailing]),
              const SizedBox(height: 12),
            ],
            child,
          ]),
        ),
      );
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.icon, this.hint, this.tone});
  final String label, value;
  final String? hint;
  final IconData icon;
  final Color? tone;
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).textTheme;
    if (context.dependOnInheritedWidgetOfExactType<_CompactStats>() != null) {
      // two to a row on a phone: the small icon sits beside the label, the figure gets the whole width
      final tc = tone ?? context.c.primary;
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(icon, size: 16, color: tc),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: th.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: th.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            if (hint != null) Text(hint!, style: th.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
    }
    return HoverLift(child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: (tone ?? context.c.primary).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: tone ?? context.c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: th.bodySmall),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: th.headlineSmall)),
              if (hint != null) Text(hint!, style: th.bodySmall),
            ]),
          ),
        ]),
      ),
    ));
  }
}

class _CompactStats extends InheritedWidget {
  const _CompactStats({required super.child});
  @override
  bool updateShouldNotify(_CompactStats oldWidget) => false;
}

/// A row of summary cards. On a computer, or in a narrow window, the number of columns is what it always was (4 / 2 / 1 by width). On a real phone or
/// tablet, where one card per line pushed the list to the bottom half of the screen, two compact cards sit side by side.
class StatGrid extends ConsumerWidget {
  const StatGrid({super.key, required this.cards, this.wideColumns = 4, this.twoColumnsAbove = 520});
  final List<Widget> cards;
  final int wideColumns;
  final double twoColumnsAbove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final touch = ref.watch(touchDeviceProvider);
    return LayoutBuilder(builder: (ctx, bc) {
      final scaled = bc.maxWidth / ctx.textFactor;
      var cols = scaled > 900 ? wideColumns : (scaled > twoColumnsAbove ? 2 : 1);
      var compact = false;
      if (touch && cols == 1 && scaled > 300) {
        cols = 2;
        compact = true;
      }
      final w = ((bc.maxWidth - (cols - 1) * 12) / cols).floorToDouble();
      final box = [for (final k in cards) SizedBox(width: w, child: k)];
      final grid = Wrap(spacing: 12, runSpacing: compact ? 8 : 12, children: box);
      return compact ? _CompactStats(child: grid) : grid;
    });
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged, this.controller, this.focusNode, this.onSubmitted, this.autofocus = false});
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: hint),
      );
}

/// Simple page frame used by most screens: title row, optional actions, padded body.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.title, this.subtitle, this.actions = const [], required this.child, this.padding});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final th = Theme.of(context).textTheme;
    return Padding(
      padding: padding ?? EdgeInsets.fromLTRB(phone ? 12 : 24, phone ? 12 : 20, phone ? 12 : 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (phone)
          ...[
            Text(title, style: th.titleLarge),
            if (subtitle != null) Text(subtitle!, style: th.bodySmall),
            if (actions.isNotEmpty) ...[const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: actions)],
          ]
        else
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: th.headlineSmall),
                if (subtitle != null) Text(subtitle!, style: th.bodySmall),
              ]),
            ),
            Wrap(spacing: 8, children: actions),
          ]),
        SizedBox(height: phone ? 8 : 14),
        Expanded(child: child),
      ]),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, required String confirmLabel, bool danger = false}) async {
  final l = tr(context);
  final r = await showDialog<bool>(
    context: context,
    animationStyle: dialogStyle(context),
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: ctx.c.danger, foregroundColor: ctx.c.onDanger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.clearSnackBars(); // the newest message replaces the shown one AND any still waiting (an old "Sending..." must never come after "Sent")
  m.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
}

/// Labelled value row used in detail sheets.
class KeyValue extends StatelessWidget {
  const KeyValue(this.k, this.v, {super.key, this.bold = false});
  final String k, v;
  final bool bold;
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(k, style: th.bodySmall)),
        Expanded(child: Text(v, style: bold ? th.titleSmall : th.bodyMedium)),
      ]),
    );
  }
}

/// A card title with an amount at its right edge. A long name or a very big text size never overflows: the name gives way, and the
/// amount may wrap onto a second line if it must.
class TitleAmount extends StatelessWidget {
  const TitleAmount(this.title, this.amount, {super.key});
  final String title, amount;
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(title, style: style)),
      const SizedBox(width: 8),
      Flexible(child: Text(amount, style: style, textAlign: TextAlign.right)),
    ]);
  }
}
