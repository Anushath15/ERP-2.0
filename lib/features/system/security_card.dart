import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/link_launcher.dart';
import '../../design/widgets.dart';
import '../../fake/security_store.dart';

/// Security: who can do what, the devices (approve / stop) and the last sign-ins, plus a reminder to turn on
/// two-step verification (the program cannot check that, it says so).
class SecurityCard extends ConsumerWidget {
  const SecurityCard({super.key});

  static const twoStepUrl = 'https://myaccount.google.com/signinoptions/twosv';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final devices = ref.watch(devicesProvider);
    final notifier = ref.read(devicesProvider.notifier);

    String roleName(Role r) => switch (r) { Role.owner => l.secRoleOwner, Role.manager => l.secRoleManager, Role.cashier => l.secRoleCashier };
    String roleHelp(Role r) => switch (r) { Role.owner => l.secRoleOwnerHelp, Role.manager => l.secRoleManagerHelp, Role.cashier => l.secRoleCashierHelp };

    Widget heading(String t) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text(t, style: th.titleSmall));

    Future<void> revoke(SampleDevice d) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l.secRevokeTitle),
          content: Text(l.secRevokeText(d.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
            FilledButton(key: const ValueKey('confirm-revoke'), onPressed: () => Navigator.pop(c, true), child: Text(l.secRevokeConfirm)),
          ],
        ),
      );
      if (ok == true) notifier.setState(d.id, DeviceState.revoked);
    }

    return SectionCard(
      key: const ValueKey('securityCard'),
      title: l.secTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading(l.secPeople),
        for (final p in samplePeople)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.email, style: th.bodyMedium), Text(roleHelp(p.role), style: th.bodySmall)])),
              const SizedBox(width: 8),
              StatusBadge(roleName(p.role), kind: p.role == Role.owner ? BadgeKind.info : BadgeKind.neutral),
            ]),
          ),
        heading(l.secDevices),
        for (final d in devices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              ConstrainedBox(constraints: const BoxConstraints(minWidth: 160, maxWidth: 320), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d.name, style: th.bodyMedium), Text('${d.email}  -  ${d.lastSeen}', style: th.bodySmall)])),
              StatusBadge(
                switch (d.state) { DeviceState.pending => l.secDeviceWaiting, DeviceState.approved => l.secDeviceApproved, DeviceState.revoked => l.secDeviceStopped },
                kind: switch (d.state) { DeviceState.pending => BadgeKind.warning, DeviceState.approved => BadgeKind.success, DeviceState.revoked => BadgeKind.danger },
              ),
              if (canApprove(d)) FilledButton(key: ValueKey('approve-${d.id}'), onPressed: () => notifier.setState(d.id, DeviceState.approved), child: Text(l.secApprove)),
              if (d.state == DeviceState.approved) OutlinedButton(key: ValueKey('revoke-${d.id}'), onPressed: () => revoke(d), child: Text(l.secRevoke)),
            ]),
          ),
        heading(l.secSignIns),
        for (final s in sampleSignIns) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('${s.when}  -  ${s.email}  -  ${s.device}', style: th.bodySmall)),
        heading(l.secTwoStep),
        Text(l.secTwoStepHelp, style: th.bodySmall),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('open2sv'),
          child: Text(l.secTwoStepOpen),
          onPressed: () async {
            final ok = await ref.read(linkLauncherProvider).open(twoStepUrl);
            if (!ok && context.mounted) toast(context, l.secTwoStepFail);
          },
        ),
      ]),
    );
  }
}
