import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/sound.dart';
import '../../design/effects.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../design/app_logo.dart';
import '../../fake/store.dart';

class _AuthFrame extends ConsumerWidget {
  const _AuthFrame({required this.child, this.maxWidth = 460});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: Theme.of(context).brightness == Brightness.dark ? l.themeLight : l.themeDark,
                  onPressed: () => ref.read(settingsProvider.notifier).set((x) => x.copyWith(theme: Theme.of(context).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark)),
                  icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                ),
              ]),
            ),
          ),
          Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child)))),
        ]),
      ),
    );
  }
}

Widget _logo(BuildContext context) => const AppLogo(size: 72);

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _show = false;
  bool _create = false;
  String? _error;
  final _shake = GlobalKey<ShakeState>();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _go() {
    final l = tr(context);
    void fail(String msg) {
      setState(() => _error = msg); // the message is shown right beside the fields
      _shake.currentState?.shake();
      playSoundIn(context, SoundKind.error);
    }

    if (!_email.text.contains('@')) return fail(l.errEmail);
    if (_pass.text.length < 6) return fail(l.errPassword);
    setState(() => _error = null);
    context.go(_create ? '/wizard' : '/');
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    return _AuthFrame(
      child: Shake(
        key: _shake,
        child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: _logo(context)),
            const SizedBox(height: 14),
            Text(_create ? l.createAccountTitle : l.signInTitle, style: th.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(_create ? l.createAccountHelp : l.signInHelp, style: th.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go(_create ? '/wizard' : '/'),
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1F1F1F), minimumSize: const Size(0, 52)),
              icon: const Text('G', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF4285F4))),
              label: Text(l.continueWithGoogle),
            ),
            const SizedBox(height: 14),
            Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(l.orWithEmail, style: th.bodySmall)), const Expanded(child: Divider())]),
            const SizedBox(height: 14),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: InputDecoration(labelText: l.fieldEmail, prefixIcon: const Icon(Icons.mail_outline))),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: !_show,
              onSubmitted: (_) => _go(),
              decoration: InputDecoration(labelText: l.fieldPassword, prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(tooltip: _show ? l.hidePassword : l.showPassword, onPressed: () => setState(() => _show = !_show), icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: StatusBadge(_error!, kind: BadgeKind.danger, icon: Icons.error_outline)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _go, style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), child: Text(_create ? l.createAccount : l.signIn)),
            const SizedBox(height: 6),
            if (!_create) TextButton(onPressed: () => context.go('/forgot'), child: Text(l.forgotPassword)),
            TextButton(onPressed: () => setState(() { _create = !_create; _error = null; }), child: Text(_create ? l.haveAccount : l.firstTimeCreate)),
            const SizedBox(height: 4),
            Text(l.staySignedNote, style: th.bodySmall, textAlign: TextAlign.center),
          ]),
        ),
      )),
    );
  }
}

class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key});
  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    return _AuthFrame(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: _logo(context)),
            const SizedBox(height: 14),
            Text(l.forgotTitle, style: th.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(l.forgotHelp, style: th.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            if (!_sent) ...[
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: l.fieldEmail, prefixIcon: const Icon(Icons.mail_outline))),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => setState(() => _sent = true), style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), child: Text(l.sendResetLink)),
            ] else ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.mark_email_read_outlined, color: context.c.success), const SizedBox(width: 10), Expanded(child: Text(l.resetSent(_email.text.isEmpty ? 'owner@example.com' : _email.text), style: th.bodyLarge))]),
              const SizedBox(height: 8),
              Text(l.resetSentHelp, style: th.bodySmall),
            ],
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.go('/signin'), child: Text(l.backToSignIn)),
          ]),
        ),
      ),
    );
  }
}

class WizardScreen extends ConsumerStatefulWidget {
  const WizardScreen({super.key});
  @override
  ConsumerState<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends ConsumerState<WizardScreen> {
  int _step = 0;
  static const _total = 6;
  final _name = TextEditingController(text: 'Senthil Enterprises');
  final _gst = TextEditingController();
  int _stockChoice = 0;

  @override
  void dispose() {
    _name.dispose();
    _gst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier).set;
    final th = Theme.of(context).textTheme;
    final titles = [l.wizWelcome, l.wizShop, l.wizGst, l.wizLogo, l.wizPrinter, l.wizStock];
    Widget body;
    switch (_step) {
      case 0:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.wizWelcomeText, style: th.bodyLarge),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          const SizedBox(height: 16),
          Text(l.setTheme, style: th.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(showSelectedIcon: false, segments: [ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)), ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight))], selected: {s.theme}, onSelectionChanged: (v) => set((x) => x.copyWith(theme: v.first))),
        ]);
      case 1:
        body = Column(children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: l.setShopName)),
          const SizedBox(height: 12),
          TextField(minLines: 2, maxLines: 3, decoration: InputDecoration(labelText: l.fieldAddress)),
          const SizedBox(height: 12),
          TextField(keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l.fieldPhone)),
        ]);
      case 2:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _gst, decoration: const InputDecoration(labelText: 'GSTIN', hintText: '33AAAAA0000A1Z5')),
          const SizedBox(height: 8),
          Text(l.wizGstHelp, style: th.bodySmall),
          const SizedBox(height: 12),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.setPricesIncludeGst), subtitle: Text(l.setPricesIncludeGstHelp), value: s.pricesIncludeGst, onChanged: (v) => set((x) => x.copyWith(pricesIncludeGst: v))),
        ]);
      case 3:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 120, decoration: BoxDecoration(color: context.c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: context.c.border)), child: Center(child: Icon(Icons.image_outlined, size: 48, color: context.c.textMuted))),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => toast(context, l.demoOnly), icon: const Icon(Icons.upload_file), label: Text(l.chooseFile)),
          const SizedBox(height: 8),
          Text(l.wizLogoHelp, style: th.bodySmall),
        ]);
      case 4:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.setPaper, style: th.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<PaperSize>(showSelectedIcon: false, segments: [ButtonSegment(value: PaperSize.a4, label: Text(l.paperA4)), ButtonSegment(value: PaperSize.mm80, label: Text(l.paper80)), ButtonSegment(value: PaperSize.mm58, label: Text(l.paper58))], selected: {s.paper}, onSelectionChanged: (v) => set((x) => x.copyWith(paper: v.first))),
          const SizedBox(height: 12),
          Text(l.wizPrinterHelp, style: th.bodySmall),
        ]);
      default:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.wizStockText, style: th.bodyLarge),
          const SizedBox(height: 12),
          for (final e in [(0, l.wizStockLater, Icons.schedule), (1, l.wizStockExcel, Icons.table_chart_outlined), (2, l.wizStockHand, Icons.edit_outlined)])
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(color: _stockChoice == e.$1 ? context.c.rowSelected : null, child: ListTile(minTileHeight: 56, leading: Icon(e.$3), title: Text(e.$2, style: th.titleSmall), trailing: _stockChoice == e.$1 ? Icon(Icons.check_circle, color: context.c.primary) : null, onTap: () => setState(() => _stockChoice = e.$1)))),
        ]);
    }
    return _AuthFrame(
      maxWidth: 560,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.wizStepOf((_step + 1).toString(), _total.toString()), style: th.bodySmall),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (_step + 1) / _total, minHeight: 6, color: context.c.primary, backgroundColor: context.c.surfaceAlt)),
            const SizedBox(height: 16),
            Text(titles[_step], style: th.headlineSmall),
            const SizedBox(height: 14),
            body,
            const SizedBox(height: 22),
            Row(children: [
              if (_step > 0) OutlinedButton(onPressed: () => setState(() => _step--), child: Text(l.back)),
              const Spacer(),
              if (_step < _total - 1) FilledButton(onPressed: () => setState(() => _step++), child: Text(l.next)) else FilledButton.icon(onPressed: () { set((x) => x.copyWith(shopName: _name.text.trim().isEmpty ? x.shopName : _name.text.trim(), firstRunDone: true)); context.go('/'); }, icon: const Icon(Icons.check), label: Text(l.finish)),
            ]),
          ]),
        ),
      ),
    );
  }
}
