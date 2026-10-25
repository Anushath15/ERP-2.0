import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/file_saver.dart';
import '../../core/link_launcher.dart';
import '../../core/reveal_file.dart';
import '../../core/validators.dart';
import '../../design/motion.dart';
import '../../design/widgets.dart';
import '../../domain/credit/reminder.dart';
import '../../fake/shop_profile.dart';

/// "Send a PDF on WhatsApp" for a customer statement or an order to a dealer. WhatsApp's own link carries a message but never a file, so the program
/// saves the PDF, opens its folder with the file selected, and opens the chat with the message ready: the person drags the PDF in (or uses the
/// paper-clip) and presses Send. Nothing is sent by the program itself.
///
/// [pdf] is built only when the person presses the button. [onNumber] is called with the number typed when it was not saved yet, so it is kept.
/// Returns true when WhatsApp was opened.
Future<bool> showWhatsappShare(
  BuildContext context, {
  required String title,
  required String phone,
  required String message,
  required Future<Uint8List> Function() pdf,
  required String fileName,
  void Function(String phone)? onNumber,
}) async {
  final done = await showDialog<bool>(
    context: context,
    animationStyle: dialogStyle(context),
    builder: (_) => _ShareDialog(title: title, phone: phone, message: message, pdf: pdf, fileName: fileName, onNumber: onNumber),
  );
  return done ?? false;
}

class _ShareDialog extends ConsumerStatefulWidget {
  const _ShareDialog({required this.title, required this.phone, required this.message, required this.pdf, required this.fileName, this.onNumber});
  final String title, phone, message, fileName;
  final Future<Uint8List> Function() pdf;
  final void Function(String phone)? onNumber;
  @override
  ConsumerState<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends ConsumerState<_ShareDialog> {
  late final TextEditingController _phone = TextEditingController(text: widget.phone);
  late final TextEditingController _msg = TextEditingController(text: widget.message);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _msg.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final l = tr(context);
    final digits = normalizePhone(_phone.text, defaultCountry: ref.read(shopProvider).countryCode);
    if (digits == null) {
      setState(() => _error = l.remNumberBad);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final bytes = await widget.pdf();
      final where = await ref.read(fileSaverProvider).save(widget.fileName, bytes);
      if (where == null) {
        if (mounted) setState(() => _error = l.pdfFailed);
        return;
      }
      if (_phone.text.trim() != widget.phone.trim()) widget.onNumber?.call(_phone.text.trim());
      unawaited(ref.read(fileRevealerProvider).reveal(where));
      final links = buildWhatsappLinks(digits: digits, message: _msg.text);
      final launcher = ref.read(linkLauncherProvider);
      final ok = await openFirst(launcher, links.tryOrder(launcher.platform));
      if (!mounted) return;
      navigator.pop(ok);
      messenger?.showSnackBar(SnackBar(content: Text(ok ? l.waSent(where) : l.waOffline(where)), duration: const Duration(seconds: 8)));
    } catch (_) {
      if (mounted) setState(() => _error = l.pdfFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.waPdfHelp, style: th.bodySmall),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('wa-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()\-.]'))],
              decoration: InputDecoration(labelText: l.waNumber, errorText: _error),
            ),
            const SizedBox(height: 12),
            TextField(key: const ValueKey('wa-message'), controller: _msg, inputFormatters: [safeInput(TextKind.message)], minLines: 6, maxLines: 12, decoration: InputDecoration(labelText: l.remMessage, alignLabelWithHint: true)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(l.cancel)),
        OutlinedButton.icon(
          onPressed: () {
            unawaited(Clipboard.setData(ClipboardData(text: _msg.text)));
            toast(context, l.remCopied);
          },
          icon: const Icon(Icons.copy_rounded),
          label: Text(l.remCopy),
        ),
        FilledButton.icon(key: const ValueKey('wa-go'), onPressed: _busy ? null : _go, icon: const Icon(Icons.open_in_new_rounded), label: Text(l.waSendPdf)),
      ],
    );
  }
}
