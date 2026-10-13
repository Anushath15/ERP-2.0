import 'package:flutter/material.dart';
import '../core/responsive.dart';
import 'widgets.dart';

/// Read-only detail view with optional actions (dialog on wide screens, bottom sheet on phones).
Future<T?> showDetail<T>(BuildContext context, {required String title, String? subtitle, required List<Widget> body, List<Widget> actions = const []}) {
  final content = _Detail(title: title, subtitle: subtitle, body: body, actions: actions);
  if (context.isPhone) {
    return showModalBottomSheet<T>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => content);
  }
  return showDialog<T>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720), child: content)));
}

class _Detail extends StatelessWidget {
  const _Detail({required this.title, this.subtitle, required this.body, required this.actions});
  final String title;
  final String? subtitle;
  final List<Widget> body, actions;
  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: th.titleLarge), if (subtitle != null) Text(subtitle!, style: th.bodySmall)])),
          IconButton(tooltip: l.close, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ]),
      ),
      Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body))),
      if (actions.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: actions)),
    ]);
  }
}
