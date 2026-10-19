import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/cloud/telegram_api.dart';
import '../../core/date_fmt.dart';
import '../../data/backup/backup_crypto.dart';
import '../../core/validators.dart' show TextKind;
import '../../design/form_sheet.dart';
import '../../design/widgets.dart';
import '../../fake/telegram_backup.dart';
import '../../strings.dart';

String telegramMessage(Strings l, TelegramProblem p) => switch (p) {
      TelegramProblem.badToken => l.tgBadToken,
      TelegramProblem.badChannel => l.tgBadChannel,
      TelegramProblem.notAdmin => l.tgNotAdmin,
      TelegramProblem.tooBig => l.tgTooBig,
      TelegramProblem.rateLimited => l.tgRateLimited,
      TelegramProblem.network => l.tgNetwork,
      TelegramProblem.noMessage => l.tgNoMessage,
      TelegramProblem.noBackup => l.tgNoBackup,
      TelegramProblem.other => l.tgOther,
    };

/// The "Backup to Telegram" card of the Backups page: set up, see when the last locked copy was sent, send now, turn off.
class TelegramBackupCard extends ConsumerWidget {
  const TelegramBackupCard({super.key});

  Future<void> _setup(BuildContext context, WidgetRef ref) async {
    final l = tr(context);
    final v = await showFormSheet(context, title: l.tgFormTitle, saveLabel: l.tgConnect, note: l.tgFormNote, fields: [
      FieldSpec('token', l.tgToken, required: true, autofocus: true, kind: TextKind.token),
      FieldSpec('chat', l.tgChannel),
      FieldSpec('password', l.tgPassword, required: true, hint: l.tgPasswordHelp, check: (x) => goodBackupPassword(x) ? null : l.tgPasswordShort, suffix: (ctl) => IconButton(
        key: const ValueKey('tgMakePassword'),
        tooltip: l.tgPasswordMake,
        icon: const Icon(Icons.auto_fix_high_rounded),
        onPressed: () => ctl.text = makeBackupPassword(),
      )),
    ]);
    if (v == null || !context.mounted) return;
    final problem = await ref.read(telegramBackupProvider.notifier).connect(token: v['token']!, password: v['password']!, chatId: v['chat'] ?? '');
    if (!context.mounted) return;
    toast(context, problem == null ? l.tgConnectedOk : telegramMessage(l, problem));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final s = ref.watch(telegramBackupProvider);
    final ctl = ref.read(telegramBackupProvider.notifier);
    return SectionCard(
      title: l.tgTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.tgHelp, style: th.bodySmall),
        const SizedBox(height: 8),
        if (s.configured) ...[
          Row(children: [
            const Icon(Icons.send_rounded, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(l.tgConnectedTo(s.channel, s.bot), key: const ValueKey('tgConnected'), style: th.titleSmall)),
          ]),
          const SizedBox(height: 4),
          Text(s.lastSent == null ? l.tgNever : l.tgLast(formatDateTime(s.lastSent!), '${(s.lastBytes / (1024 * 1024)).toStringAsFixed(1)} MB'), key: const ValueKey('tgLast'), style: th.bodyMedium),
          if (s.problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: StatusBadge(telegramMessage(l, s.problem!), kind: BadgeKind.danger, icon: Icons.error_outline_rounded)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
              key: const ValueKey('tgSendNow'),
              onPressed: s.busy
                  ? null
                  : () async {
                      final p = await ctl.sendNow();
                      if (context.mounted) toast(context, p == null ? l.tgSentOk : telegramMessage(l, p));
                    },
              icon: s.busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload_rounded),
              label: Text(l.tgSendNow),
            ),
            OutlinedButton(key: const ValueKey('tgChange'), onPressed: s.busy ? null : () => _setup(context, ref), child: Text(l.tgChange)),
            TextButton(key: const ValueKey('tgForget'), onPressed: s.busy ? null : ctl.forget, child: Text(l.tgForget)),
          ]),
        ] else ...[
          if (s.problem != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: StatusBadge(telegramMessage(l, s.problem!), kind: BadgeKind.danger, icon: Icons.error_outline_rounded)),
          FilledButton.icon(key: const ValueKey('tgSetup'), onPressed: s.busy ? null : () => _setup(context, ref), icon: const Icon(Icons.send_rounded), label: Text(l.tgSetup)),
        ],
      ]),
    );
  }
}
