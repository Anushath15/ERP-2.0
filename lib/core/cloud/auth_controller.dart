import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../link_launcher.dart';
import 'auth_api.dart';
import 'cloud_config.dart';
import 'google_flow.dart';
import 'session_vault.dart';

enum AuthStatus { loading, signedOut, signedIn }

class AuthState {
  const AuthState({this.status = AuthStatus.signedOut, this.email = '', this.busy = false});
  final AuthStatus status;
  final String email;

  /// A sign-in step is running (the screen shows a spinner and ignores a second press).
  final bool busy;

  AuthState copyWith({AuthStatus? status, String? email, bool? busy}) => AuthState(status: status ?? this.status, email: email ?? this.email, busy: busy ?? this.busy);
}

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(cloudConfigProvider)));

/// Signing in to the shop's cloud account, once per computer.
///  * Email + password, or Google. Only people in the shop's member list get in (everyone else is signed straight out again).
///  * The session is kept (encrypted) on this computer: opening the program never asks again. Only Sign out, or the cloud cancelling the
///    session, asks again. With no internet the kept sign-in is trusted, so the shop keeps working offline.
///  * Without a cloud address in the build ([CloudConfig.configured] false) nothing here is used: the program works on this computer only.
class AuthController extends Notifier<AuthState> {
  String _access = '';

  @override
  AuthState build() => ref.watch(cloudConfigProvider).configured ? const AuthState(status: AuthStatus.loading) : const AuthState();

  AuthApi get _api => ref.read(authApiProvider);
  SessionVault get _vault => ref.read(sessionVaultProvider);

  /// At program start: use the kept sign-in, if there is one.
  Future<void> restore() async {
    if (!ref.read(cloudConfigProvider).configured) return;
    String refresh = '', email = '';
    try {
      final j = jsonDecode(_vault.read() ?? '');
      if (j is Map) {
        refresh = '${j['refresh'] ?? ''}';
        email = '${j['email'] ?? ''}';
      }
    } catch (_) {}
    if (refresh.isEmpty) {
      state = const AuthState();
      return;
    }
    try {
      final s = await _api.refresh(refresh);
      _keep(s, fallbackEmail: email);
      state = AuthState(status: AuthStatus.signedIn, email: s.email.isEmpty ? email : s.email);
    } on AuthFailure catch (e) {
      if (e.problem == AuthProblem.network) {
        state = AuthState(status: AuthStatus.signedIn, email: email); // no internet: the shop keeps working
      } else {
        _vault.write(null); // the cloud cancelled this sign-in (password changed, access removed...)
        state = const AuthState();
      }
    }
  }

  void _keep(AuthSession s, {String fallbackEmail = ''}) {
    _access = s.accessToken;
    _vault.write(jsonEncode({'refresh': s.refreshToken, 'email': s.email.isEmpty ? fallbackEmail : s.email}));
  }

  /// A new session: let it in only when this person belongs to the shop.
  Future<AuthFailure?> _finish(AuthSession s) async {
    try {
      if (!await _api.isShopMember(s.accessToken)) {
        await _api.signOut(s.accessToken);
        _vault.write(null);
        _access = '';
        state = const AuthState();
        return AuthFailure(AuthProblem.notMember, email: s.email);
      }
    } on AuthFailure catch (e) {
      state = const AuthState();
      return e;
    }
    _keep(s);
    state = AuthState(status: AuthStatus.signedIn, email: s.email);
    return null;
  }

  Future<AuthFailure?> _run(Future<AuthFailure?> Function() step) async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      return await step();
    } on AuthFailure catch (e) {
      return e;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<AuthFailure?> signIn(String email, String password) => _run(() async => _finish(await _api.signInWithPassword(email.trim(), password)));

  /// Makes the account. Returns null with [AuthState.status] signed in only when the cloud lets the person straight in; the usual
  /// answer is "open the link we e-mailed", which the screen explains (see [createAccount]).
  Future<({AuthFailure? failure, bool needsConfirm})> createAccount(String email, String password) async {
    AuthFailure? failure;
    var needs = false;
    failure = await _run(() async {
      final r = await _api.signUp(email.trim(), password);
      if (r.session == null) {
        needs = true;
        return null;
      }
      return _finish(r.session!);
    });
    return (failure: failure, needsConfirm: needs);
  }

  Future<AuthFailure?> google() => _run(() async {
        if (!await _api.googleEnabled()) return const AuthFailure(AuthProblem.googleOff);
        return _finish(await ref.read(googleFlowProvider).run(_api, ref.read(linkLauncherProvider)));
      });

  Future<AuthFailure?> sendResetLink(String email) => _run(() async {
        await _api.sendResetLink(email.trim());
        return null;
      });

  /// Sign out of this computer: forgets the kept sign-in (the next start asks again). Works with no internet.
  Future<void> signOut() async {
    final token = _access;
    _access = '';
    _vault.write(null);
    state = const AuthState();
    if (token.isNotEmpty) await _api.signOut(token);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
