import 'package:flutter/material.dart';
import '../../core/cloud/auth_api.dart';
import '../../core/cloud/auth_controller.dart';
import '../../core/cloud/cloud_config.dart';
import '../../core/logo_image.dart';
import '../../core/validators.dart';
import '../shop/shop_profile_screen.dart' show ShopLogo, logoPickerProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/sound.dart';
import '../../design/effects.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../design/app_logo.dart';
import '../../core/plain_error.dart';
import '../../data/repo/series_registry.dart';
import '../../fake/data_providers.dart';
import '../../fake/store.dart';
import '../../fake/shop_profile.dart';
import '../../strings.dart';

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
                  icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
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

/// What went wrong with a sign-in step, in plain words.
String authMessage(Strings l, AuthFailure f) => switch (f.problem) {
      AuthProblem.wrongLogin => l.authWrongLogin,
      AuthProblem.notConfirmed => l.authNotConfirmed,
      AuthProblem.userExists => l.authUserExists,
      AuthProblem.weakPassword => l.authWeakPassword,
      AuthProblem.rateLimited => l.authRateLimited,
      AuthProblem.network => l.authNetwork,
      AuthProblem.notMember => l.authNotMember(f.email),
      AuthProblem.other => l.authOther,
    };

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
  String? _info;
  final _shake = GlobalKey<ShakeState>();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _fail(String msg) {
    setState(() {
      _error = msg; // the message is shown right beside the fields
      _info = null;
    });
    _shake.currentState?.shake();
    playSoundIn(context, SoundKind.error);
  }

  Future<void> _go() async {
    final l = tr(context);
    if (!_email.text.contains('@')) return _fail(l.errEmail);
    if (_pass.text.length < 6) return _fail(l.errPassword);
    setState(() {
      _error = null;
      _info = null;
    });
    if (!ref.read(cloudConfigProvider).configured) return context.go(_create ? '/wizard' : '/'); // no cloud in this build: the old preview
    final auth = ref.read(authProvider.notifier);
    if (_create) {
      final r = await auth.createAccount(_email.text, _pass.text);
      if (!mounted) return;
      if (r.failure != null) return _fail(authMessage(l, r.failure!));
      if (r.needsConfirm) {
        setState(() {
          _create = false;
          _info = l.authAccountCreated(_email.text.trim());
        });
        return;
      }
      return context.go('/wizard');
    }
    final f = await auth.signIn(_email.text, _pass.text);
    if (!mounted) return;
    if (f != null) return _fail(authMessage(l, f));
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final busy = ref.watch(authProvider.select((a) => a.busy));
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
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: InputDecoration(labelText: l.fieldEmail, prefixIcon: const Icon(Icons.mail_outline_rounded))),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: !_show,
              onSubmitted: (_) => busy ? null : _go(),
              decoration: InputDecoration(labelText: l.fieldPassword, prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(tooltip: _show ? l.hidePassword : l.showPassword, onPressed: () => setState(() => _show = !_show), icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded))),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: StatusBadge(_error!, kind: BadgeKind.danger, icon: Icons.error_outline_rounded)),
            if (_info != null) Padding(padding: const EdgeInsets.only(top: 10), child: StatusBadge(_info!, kind: BadgeKind.info, icon: Icons.info_outline_rounded)),
            const SizedBox(height: 16),
            FilledButton(key: const ValueKey('signInButton'), onPressed: busy ? null : _go, style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), child: busy ? Text(l.authBusy) : Text(_create ? l.createAccount : l.signIn)),
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
  String? _error;

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
              Semantics(container: true, child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: l.fieldEmail, prefixIcon: const Icon(Icons.mail_outline_rounded)))),
              const SizedBox(height: 16),
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Semantics(container: true, liveRegion: true, label: _error, child: StatusBadge(_error!, kind: BadgeKind.danger, icon: Icons.error_outline_rounded))),
              FilledButton(
                key: const ValueKey('sendReset'),
                onPressed: ref.watch(authProvider.select((a) => a.busy))
                    ? null
                    : () async {
                        if (!_email.text.contains('@')) return setState(() => _error = l.errEmail);
                        if (ref.read(cloudConfigProvider).configured) {
                          final f = await ref.read(authProvider.notifier).sendResetLink(_email.text);
                          if (!mounted) return;
                          if (f != null) return setState(() => _error = authMessage(l, f));
                        }
                        setState(() {
                          _error = null;
                          _sent = true;
                        });
                      },
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                child: Text(l.sendResetLink),
              ),
            ] else ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.mark_email_read_rounded, color: context.c.success), const SizedBox(width: 10), Expanded(child: Text(l.resetSent(_email.text.isEmpty ? 'owner@example.com' : _email.text), style: th.bodyLarge))]),
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
  static const _total = 7;
  late final TextEditingController _name, _owner, _address, _phone, _gst, _prefix;
  String? _letter;
  String? _error;
  bool _busy = false;
  int _stockChoice = 0;

  @override
  void initState() {
    super.initState();
    final shop = ref.read(shopProvider);
    _name = TextEditingController(text: shop.name);
    _owner = TextEditingController(text: shop.ownerName);
    _address = TextEditingController(text: shop.address);
    _phone = TextEditingController(text: shop.phone);
    _gst = TextEditingController(text: shop.gstin);
    _prefix = TextEditingController(text: shop.invoicePrefix);
  }

  @override
  void dispose() {
    for (final c in [_name, _owner, _address, _phone, _gst, _prefix]) {
      c.dispose();
    }
    super.dispose();
  }

  /// What is wrong with the step the person is on (null = fine to go on).
  String? _check(Strings l) {
    switch (_step) {
      case 1:
        if (_name.text.trim().isEmpty) return l.wizNameRequired;
        if (checkText(TextKind.name, _name.text) != null || checkText(TextKind.address, _address.text) != null) return l.fieldRequired;
      case 2:
        if (_gst.text.trim().isNotEmpty && checkText(TextKind.gstin, _gst.text) != null) return l.errGstin;
      case 3:
        if (!RegExp(r'^[A-Za-z0-9-]{0,6}$').hasMatch(_prefix.text.trim())) return l.wizPrefixBad;
        if (_letter == null) return l.wizSeriesPick;
    }
    return null;
  }

  Future<void> _finish(Strings l) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = ref.read(appDataProvider);
      final registry = SeriesRegistry(d.settings, d.cx.deviceId);
      await ref.read(writeQueueProvider).run(() => registry.claim(_letter!)); // refused if another computer of this shop has the letter
      d.bills.series = _letter!;
      ref.read(shopProvider.notifier).set((x) => x.copyWith(name: _name.text.trim(), ownerName: _owner.text.trim(), address: _address.text.trim(), phone: _phone.text.trim(), gstin: _gst.text.trim(), invoicePrefix: _prefix.text.trim()));
      d.bills.invoicePrefix = _prefix.text.trim();
      await ref.read(writeQueueProvider).run(() => d.settings.put('shop.created', '${d.cx.nowMs()}'));
      await ref.read(writeQueueProvider).flush();
      await ref.read(nextNumbersProvider.notifier).refresh();
      ref.read(settingsProvider.notifier).set((x) => x.copyWith(firstRunDone: true));
      if (mounted) context.go('/');
    } on SeriesTakenException {
      setState(() => _error = l.wizSeriesTaken(_letter ?? ''));
    } catch (e) {
      setState(() => _error = plainError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier).set;
    final th = Theme.of(context).textTheme;
    final titles = [l.wizWelcome, l.wizShop, l.wizGst, l.wizNumbering, l.wizLogo, l.wizPrinter, l.wizStock];
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
          TextField(key: const ValueKey('wizName'), controller: _name, inputFormatters: [safeInput(TextKind.name)], decoration: InputDecoration(labelText: l.setShopName)),
          const SizedBox(height: 12),
          TextField(key: const ValueKey('wizOwner'), controller: _owner, inputFormatters: [safeInput(TextKind.name)], decoration: InputDecoration(labelText: l.fieldOwner)),
          const SizedBox(height: 12),
          TextField(key: const ValueKey('wizAddress'), controller: _address, minLines: 2, maxLines: 3, inputFormatters: [safeInput(TextKind.address)], decoration: InputDecoration(labelText: l.fieldAddress)),
          const SizedBox(height: 12),
          TextField(key: const ValueKey('wizPhone'), controller: _phone, keyboardType: TextInputType.phone, inputFormatters: [safeInput(TextKind.phone)], decoration: InputDecoration(labelText: l.fieldPhone)),
        ]);
      case 2:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(key: const ValueKey('wizGstin'), controller: _gst, inputFormatters: [safeInput(TextKind.gstin)], decoration: const InputDecoration(labelText: 'GSTIN', hintText: '33AAAAA0000A1Z5')),
          const SizedBox(height: 8),
          Text(l.wizGstHelp, style: th.bodySmall),
          const SizedBox(height: 12),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.setPricesIncludeGst), subtitle: Text(l.setPricesIncludeGstHelp), value: ref.watch(shopProvider).pricesIncludeGst, onChanged: (v) => ref.read(shopProvider.notifier).set((x) => x.copyWith(pricesIncludeGst: v))),
        ]);
      case 3:
        final free = ref.watch(freeSeriesProvider);
        final letters = free.value ?? const <String>[];
        // a computer that already has its letter (its old bills carry it) keeps it: shown chosen, the others greyed out
        final mine = ref.watch(mySeriesProvider).value;
        if (mine != null && _letter != mine) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _letter = mine);
          });
        }
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.wizNumberingHelp, style: th.bodyMedium),
          const SizedBox(height: 12),
          TextField(key: const ValueKey('wizPrefix'), controller: _prefix, onChanged: (_) => setState(() {}), inputFormatters: [safeInput(TextKind.town)], decoration: InputDecoration(labelText: l.wizPrefixLabel, hintText: 'SE-', helperText: l.wizPrefixHelp)),
          const SizedBox(height: 16),
          Text(l.wizSeriesLabel, style: th.titleSmall),
          const SizedBox(height: 4),
          Text(mine != null ? l.wizSeriesMine(mine) : l.wizSeriesHelp, key: const ValueKey('wizSeriesHelp'), style: th.bodySmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final x in SeriesRegistry.letters)
              ChoiceChip(
                key: ValueKey('series-$x'),
                label: Text(x),
                selected: _letter == x,
                onSelected: mine != null ? null : (letters.contains(x) ? (_) => setState(() => _letter = x) : null),
              ),
          ]),
          const SizedBox(height: 8),
          if (_letter != null) Text(l.wizSeriesExample('${_prefix.text.trim()}$_letter-000001'), style: th.bodySmall),
        ]);
      case 4:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 120, decoration: BoxDecoration(color: context.c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: context.c.border)), child: Center(child: ref.watch(shopProvider).logoPng.isEmpty ? Icon(Icons.image_rounded, size: 48, color: context.c.textMuted) : ShopLogo(png: ref.watch(shopProvider).logoPng, size: 96))),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('wizard-logo-choose'),
            onPressed: () async {
              final bytes = await ref.read(logoPickerProvider)();
              if (bytes == null || !context.mounted) return;
              final b64 = prepareLogo(bytes);
              if (b64 == null) {
                toast(context, l.logoBad);
                return;
              }
              ref.read(shopProvider.notifier).set((x) => x.copyWith(logoPng: b64));
              toast(context, l.logoSaved);
            },
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(l.chooseFile),
          ),
          const SizedBox(height: 8),
          Text(l.wizLogoHelp, style: th.bodySmall),
        ]);
      case 5:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.setPaper, style: th.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<PaperSize>(showSelectedIcon: false, segments: [ButtonSegment(value: PaperSize.a4, label: Text(l.paperA4)), ButtonSegment(value: PaperSize.a5, label: Text(l.paperA5)), ButtonSegment(value: PaperSize.mm80, label: Text(l.paper80)), ButtonSegment(value: PaperSize.mm58, label: Text(l.paper58))], selected: {s.paper}, onSelectionChanged: (v) => set((x) => x.copyWith(paper: v.first))),
          const SizedBox(height: 12),
          Text(l.wizPrinterHelp, style: th.bodySmall),
        ]);
      default:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.wizStockText, style: th.bodyLarge),
          const SizedBox(height: 12),
          for (final e in [(0, l.wizStockLater, Icons.schedule_rounded), (1, l.wizStockExcel, Icons.table_chart_rounded), (2, l.wizStockHand, Icons.edit_rounded)])
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(color: _stockChoice == e.$1 ? context.c.rowSelected : null, child: ListTile(minTileHeight: 56, leading: Icon(e.$3), title: Text(e.$2, style: th.titleSmall), trailing: _stockChoice == e.$1 ? Icon(Icons.check_circle_rounded, color: context.c.primary) : null, onTap: () => setState(() => _stockChoice = e.$1)))),
        ]);
    }
    void next() {
      final problem = _check(l);
      setState(() => _error = problem);
      if (problem == null) setState(() => _step++);
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
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, key: const ValueKey('wizError'), style: th.bodyMedium?.copyWith(color: context.c.danger))),
            const SizedBox(height: 22),
            Row(children: [
              if (_step > 0) OutlinedButton(onPressed: _busy ? null : () => setState(() { _step--; _error = null; }), child: Text(l.back)),
              const Spacer(),
              if (_step < _total - 1) FilledButton(onPressed: next, child: Text(l.next)) else FilledButton.icon(key: const ValueKey('wizFinish'), onPressed: _busy ? null : () => _finish(l), icon: const Icon(Icons.check_rounded), label: Text(l.finish)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// This computer's own letter, if it already has one.
final mySeriesProvider = FutureProvider<String?>((ref) {
  final d = ref.watch(appDataProvider);
  return SeriesRegistry(d.settings, d.cx.deviceId).mine();
});

/// The series letters nobody in this shop has taken yet.
final freeSeriesProvider = FutureProvider<List<String>>((ref) {
  final d = ref.watch(appDataProvider);
  return SeriesRegistry(d.settings, d.cx.deviceId).free();
});
