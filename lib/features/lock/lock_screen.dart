import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/lock/pin_lock.dart';
import '../../design/app_logo.dart';
import '../../design/form_sheet.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';

/// The screen that covers the whole program while it is locked: type the PIN, or (forgot it) the recovery code and choose a new PIN.
class LockOverlay extends StatelessWidget {
  const LockOverlay({super.key});

  /// The lock screen sits above the program's own pages (and so above their Navigator): it brings its own Overlay, which text fields need.
  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [OverlayEntry(builder: (_) => const _LockBody())]);
}

class _LockBody extends ConsumerStatefulWidget {
  const _LockBody();
  @override
  ConsumerState<_LockBody> createState() => _LockBodyState();
}

class _LockBodyState extends ConsumerState<_LockBody> {
  final _pin = TextEditingController(), _code = TextEditingController(), _newPin = TextEditingController();
  final _focus = FocusNode();
  bool _recovery = false, _busy = false;
  String? _message, _newCode; // _newCode: the recovery code made by a reset, shown here (this screen sits above the program's own pages)
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null); // the wait counts down
    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _focus.requestFocus() : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pin.dispose();
    _code.dispose();
    _newPin.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final l = tr(context);
    if (_busy) return;
    final ctl = ref.read(pinLockProvider.notifier);
    setState(() => _busy = true);
    final r = await ctl.unlock(_pin.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pin.clear();
      _message = switch (r) { UnlockResult.ok => null, UnlockResult.wrong => l.lockWrong, UnlockResult.waiting => l.lockWait('${ctl.waitLeft}') };
    });
    if (r != UnlockResult.ok) _focus.requestFocus();
  }

  Future<void> _reset() async {
    final l = tr(context);
    if (_busy) return;
    if (!validPin(_newPin.text)) return setState(() => _message = l.lockPinBad);
    final ctl = ref.read(pinLockProvider.notifier);
    setState(() => _busy = true);
    final code = await ctl.resetWithRecovery(_code.text, _newPin.text);
    if (!mounted) return;
    if (code == null) {
      setState(() {
        _busy = false;
        _message = ctl.waitLeft > 0 ? l.lockWait('${ctl.waitLeft}') : l.lockRecoveryBad;
      });
      return;
    }
    setState(() {
      _busy = false;
      _newCode = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    final th = Theme.of(context).textTheme;
    final ctl = ref.read(pinLockProvider.notifier);
    final waiting = ref.watch(pinLockProvider).until != null && ctl.waitLeft > 0;
    return Material(
      color: c.bg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  const Center(child: AppLogo(size: 64)),
                  const SizedBox(height: 12),
                  Text(_newCode != null ? l.lockRecoveryShow : (_recovery ? l.lockRecoveryTitle : l.lockScreenTitle), key: const ValueKey('lockTitle'), style: th.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  if (_newCode != null) ...[
                    Text(l.lockRecoveryHelp, style: th.bodySmall, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Center(child: SelectableText(_newCode!, key: const ValueKey('recoveryCode'), style: th.headlineMedium?.copyWith(letterSpacing: 2, fontWeight: FontWeight.w800))),
                    const SizedBox(height: 14),
                    FilledButton(key: const ValueKey('recoveryWritten'), onPressed: ctl.openAfterReset, style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), child: Text(l.lockWritten)),
                  ] else if (!_recovery) ...[
                    TextField(
                      key: const ValueKey('lockPin'),
                      controller: _pin,
                      focusNode: _focus,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                      onSubmitted: (_) => _unlock(),
                      decoration: InputDecoration(labelText: l.lockPinField, prefixIcon: const Icon(Icons.lock_outline_rounded)),
                    ),
                    if (_message != null || waiting) Padding(padding: const EdgeInsets.only(top: 10), child: StatusBadge(waiting ? l.lockWait('${ctl.waitLeft}') : _message!, kind: BadgeKind.danger, icon: Icons.error_outline_rounded)),
                    const SizedBox(height: 14),
                    FilledButton(key: const ValueKey('lockUnlock'), onPressed: _busy || waiting ? null : _unlock, style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), child: Text(l.lockUnlock)),
                    TextButton(key: const ValueKey('lockForgot'), onPressed: () => setState(() {
                      _recovery = true;
                      _message = null;
                    }), child: Text(l.lockForgot)),
                  ] else ...[
                    Text(l.lockRecoveryAsk, style: th.bodySmall, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextField(key: const ValueKey('lockCode'), controller: _code, autofocus: true, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: l.lockRecoveryField, prefixIcon: const Icon(Icons.key_rounded))),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('lockNewPin'),
                      controller: _newPin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                      onSubmitted: (_) => _reset(),
                      decoration: InputDecoration(labelText: l.lockNewPin, prefixIcon: const Icon(Icons.lock_outline_rounded)),
                    ),
                    if (_message != null) Padding(padding: const EdgeInsets.only(top: 10), child: StatusBadge(_message!, kind: BadgeKind.danger, icon: Icons.error_outline_rounded)),
                    const SizedBox(height: 14),
                    FilledButton(key: const ValueKey('lockReset'), onPressed: _busy ? null : _reset, style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), child: Text(l.lockResetBtn)),
                    TextButton(onPressed: () => setState(() {
                      _recovery = false;
                      _message = null;
                    }), child: Text(l.back)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The recovery code, shown once: it has to be written on paper before the person can go on.
Future<void> showRecoveryCode(BuildContext context, String code) {
  final l = tr(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: Text(l.lockRecoveryShow),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: SelectableText(code, key: const ValueKey('recoveryCode'), style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(letterSpacing: 2, fontWeight: FontWeight.w800))),
        const SizedBox(height: 12),
        Text(l.lockRecoveryHelp),
      ]),
      actions: [FilledButton(key: const ValueKey('recoveryWritten'), onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(), child: Text(l.lockWritten))],
    ),
  );
}

/// The PIN lock settings (in Settings > Security): turn it on with a PIN, change it, lock now, choose when it locks by itself, turn it off.
class AppLockCard extends ConsumerWidget {
  const AppLockCard({super.key});

  Future<void> _setup(BuildContext context, WidgetRef ref) async {
    final l = tr(context);
    final v = await showFormSheet(context, title: l.lockSet, saveLabel: l.save, note: l.lockSetNote, fields: [
      FieldSpec('pin', l.lockPinField, required: true, autofocus: true, obscure: true, digits: 8, check: (x) => validPin(x) ? null : l.lockPinBad),
      FieldSpec('pin2', l.lockRepeat, required: true, obscure: true, digits: 8),
    ]);
    if (v == null || !context.mounted) return;
    if (v['pin'] != v['pin2']) {
      toast(context, l.lockPinSame);
      return;
    }
    final code = await ref.read(pinLockProvider.notifier).setPin(v['pin']!);
    if (code != null && context.mounted) await showRecoveryCode(context, code);
  }

  /// Asks for the current PIN. True when it was right.
  Future<bool> _askCurrent(BuildContext context, WidgetRef ref) async {
    final l = tr(context);
    final v = await showFormSheet(context, title: l.lockCurrentPin, saveLabel: l.lockUnlock, fields: [FieldSpec('pin', l.lockPinField, required: true, autofocus: true, obscure: true, digits: 8)]);
    if (v == null || !context.mounted) return false;
    final ok = await ref.read(pinLockProvider.notifier).check(v['pin']!);
    if (!ok && context.mounted) toast(context, ref.read(pinLockProvider.notifier).waitLeft > 0 ? l.lockWait('${ref.read(pinLockProvider.notifier).waitLeft}') : l.lockCurrentWrong);
    return ok;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final s = ref.watch(pinLockProvider);
    final ctl = ref.read(pinLockProvider.notifier);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.setPin, style: th.titleSmall),
      const SizedBox(height: 2),
      Text(s.enabled ? l.lockOnStatus : l.lockOffStatus, key: const ValueKey('lockStatus'), style: th.bodySmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (!s.enabled) FilledButton(key: const ValueKey('lockSet'), onPressed: () => _setup(context, ref), child: Text(l.lockSet)),
        if (s.enabled) ...[
          OutlinedButton(
            key: const ValueKey('lockChange'),
            onPressed: () async {
              if (await _askCurrent(context, ref) && context.mounted) await _setup(context, ref);
            },
            child: Text(l.lockChange),
          ),
          OutlinedButton.icon(key: const ValueKey('lockNow'), onPressed: ctl.lock, icon: const Icon(Icons.lock_rounded), label: Text(l.lockNow)),
          TextButton(
            key: const ValueKey('lockOff'),
            onPressed: () async {
              if (await _askCurrent(context, ref)) ctl.turnOff();
            },
            child: Text(l.lockOff),
          ),
          DropdownButton<int>(
            key: const ValueKey('lockMinutes'),
            value: const [5, 15, 30, 60, 0].contains(s.minutes) ? s.minutes : 15,
            items: [for (final m in const [5, 15, 30, 60, 0]) DropdownMenuItem(value: m, child: Text(m == 0 ? l.lockNever : l.lockAfterMinutes('$m')))],
            onChanged: (m) => ctl.setMinutes(m ?? 15),
          ),
        ],
      ]),
    ]);
  }
}
