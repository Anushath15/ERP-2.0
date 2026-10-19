import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data_mode.dart';
import '../../core/lan/lan_controller.dart';
import '../../data/sync/lan_link.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/data_providers.dart';

/// Settings > Counter link: two or more billing counters of the shop exchange their changes over the shop Wi-Fi, with no internet.
class LanCard extends ConsumerStatefulWidget {
  const LanCard({super.key});
  @override
  ConsumerState<LanCard> createState() => _LanCardState();
}

class _LanCardState extends ConsumerState<LanCard> {
  final _address = TextEditingController();
  final _key = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final s = ref.watch(lanProvider);
    final ctl = ref.read(lanProvider.notifier);
    if (ref.watch(appModeProvider) != DataMode.real) return const SizedBox.shrink();
    if (_key.text != s.key && !FocusScope.of(context).hasFocus) _key.text = s.key;

    Future<void> link() async {
      setState(() => _error = null);
      try {
        if (_key.text.trim().isNotEmpty && _key.text.trim() != s.key && !await ctl.setKey(_key.text)) {
          setState(() => _error = s.peers.isNotEmpty ? l.lanKeyLocked : l.lanErrKeyBad);
          return;
        }
        await ctl.addPeer(_address.text);
        _address.clear();
      } on LanLinkException catch (e) {
        setState(() => _error = switch (e.problem) {
              LanLinkProblem.badAddress => l.lanErrBad,
              LanLinkProblem.unreachable => l.lanErrUnreachable,
              LanLinkProblem.wrongKey => l.lanErrWrongKey,
              LanLinkProblem.thisComputer => l.lanErrSelf,
            });
      }
    }

    return SectionCard(
      title: l.lanTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.lanHelp, style: th.bodySmall),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const ValueKey('lanSwitch'),
          contentPadding: EdgeInsets.zero,
          title: Text(l.lanOn, style: th.titleSmall),
          value: s.on,
          onChanged: (v) => unawaited(v ? ctl.enable() : ctl.disable()),
        ),
        if (s.startFailed) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.lanStartFailed, key: const ValueKey('lanStartFailed'), style: th.bodyMedium?.copyWith(color: context.c.danger))),
        if (s.on) ...[
          Text(l.lanFirewall, style: th.bodySmall),
          const SizedBox(height: 8),
          Text('${l.lanAddress}: ${s.addresses.isEmpty ? '-' : s.addresses.join(', ')}', key: const ValueKey('lanAddress'), style: th.titleSmall),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(key: const ValueKey('lanKey'), controller: _key, readOnly: s.peers.isNotEmpty, decoration: InputDecoration(labelText: l.lanKeyLabel, helperText: l.lanKeyHelp, helperMaxLines: 3))),
            IconButton(tooltip: l.lanCopy, onPressed: () => Clipboard.setData(ClipboardData(text: s.key)), icon: const Icon(Icons.copy_rounded)),
          ]),
          const SizedBox(height: 8),
          Text(l.lanLinked, style: th.titleSmall),
          if (s.peers.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(l.lanNone, key: const ValueKey('lanNone'), style: th.bodyMedium)),
          for (final p in s.peers)
            ListTile(
              key: ValueKey('lanPeer-${p.chan}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon((s.status[p.chan] ?? '').isEmpty ? Icons.wifi_rounded : Icons.wifi_off_rounded, color: (s.status[p.chan] ?? '').isEmpty ? context.c.success : context.c.warning),
              title: Text(p.name.isEmpty ? p.deviceId : p.name),
              subtitle: Text('${p.host} - ${(s.status[p.chan] ?? '').isEmpty ? l.lanOk : l.lanPeerDown}'),
              trailing: TextButton(onPressed: () => unawaited(ctl.removePeer(p.chan)), child: Text(l.lanRemove)),
            ),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: TextField(key: const ValueKey('lanHost'), controller: _address, decoration: InputDecoration(labelText: l.lanOtherAddress), onSubmitted: (_) => unawaited(link()))),
            const SizedBox(width: 8),
            Padding(padding: const EdgeInsets.only(top: 6), child: FilledButton(key: const ValueKey('lanLinkBtn'), onPressed: s.busy ? null : () => unawaited(link()), child: Text(l.lanLink))),
          ]),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const ValueKey('lanError'), style: th.bodyMedium?.copyWith(color: context.c.danger))),
        ],
      ]),
    );
  }
}
