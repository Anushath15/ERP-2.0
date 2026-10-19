import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cloud_config.dart';

/// Why a sign-in step failed, in the words the screen needs (never a stack trace, never the server's own text).
enum AuthProblem { wrongLogin, notConfirmed, userExists, weakPassword, rateLimited, network, notMember, other }

class AuthFailure implements Exception {
  const AuthFailure(this.problem, {this.email = ''});
  final AuthProblem problem;
  final String email;
  @override
  String toString() => 'AuthFailure($problem)';
}

class AuthSession {
  const AuthSession({required this.accessToken, required this.refreshToken, required this.email, required this.expiresAt});
  final String accessToken, refreshToken, email;
  final DateTime expiresAt;
}

class SignUpResult {
  const SignUpResult({this.session, required this.email});

  /// Null when the person must first open the link that was e-mailed (the usual case).
  final AuthSession? session;
  final String email;
}

/// The little part of Supabase Auth (GoTrue) and the shop-membership check this program uses, over plain HTTPS. No plugin.
/// Everything that can go wrong comes out as an [AuthFailure].
class AuthApi {
  AuthApi(this.config, {http.Client? client, DateTime Function()? now})
      : _http = client ?? http.Client(),
        _now = now ?? DateTime.now;

  final CloudConfig config;
  final http.Client _http;
  final DateTime Function() _now;

  Map<String, String> _headers([String? bearer]) => {
        'apikey': config.key,
        'Authorization': 'Bearer ${bearer ?? config.key}',
        'Content-Type': 'application/json',
      };

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const AuthFailure(AuthProblem.network);
    }
  }

  Map<String, Object?> _json(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      return j is Map ? j.cast<String, Object?>() : {};
    } catch (_) {
      return {};
    }
  }

  AuthFailure _fail(http.Response r) {
    final j = _json(r);
    final code = '${j['error_code'] ?? ''}'.toLowerCase();
    final text = '${j['msg'] ?? j['error_description'] ?? j['message'] ?? ''}'.toLowerCase();
    if (r.statusCode == 429 || code.contains('rate_limit')) return const AuthFailure(AuthProblem.rateLimited);
    if (code == 'email_not_confirmed' || text.contains('not confirmed')) return const AuthFailure(AuthProblem.notConfirmed);
    if (code == 'user_already_exists' || code == 'email_exists' || text.contains('already registered')) return const AuthFailure(AuthProblem.userExists);
    if (code == 'weak_password' || text.contains('password should be')) return const AuthFailure(AuthProblem.weakPassword);
    if (code == 'invalid_credentials' || text.contains('invalid login') || text.contains('invalid grant')) return const AuthFailure(AuthProblem.wrongLogin);
    if (r.statusCode >= 500) return const AuthFailure(AuthProblem.network);
    return const AuthFailure(AuthProblem.other);
  }

  AuthSession? _session(Map<String, Object?> j) {
    final access = j['access_token'], refresh = j['refresh_token'];
    if (access is! String || refresh is! String || access.isEmpty || refresh.isEmpty) return null;
    final user = j['user'];
    final email = user is Map ? '${user['email'] ?? ''}' : '';
    final secs = j['expires_in'] is num ? (j['expires_in'] as num).toInt() : 3600;
    return AuthSession(accessToken: access, refreshToken: refresh, email: email, expiresAt: _now().add(Duration(seconds: secs)));
  }

  AuthSession _needSession(http.Response r) {
    if (r.statusCode != 200) throw _fail(r);
    return _session(_json(r)) ?? (throw const AuthFailure(AuthProblem.other));
  }

  Future<AuthSession> signInWithPassword(String email, String password) async {
    final r = await _send(() => _http.post(Uri.parse('${config.base}/auth/v1/token?grant_type=password'), headers: _headers(), body: jsonEncode({'email': email, 'password': password})));
    return _needSession(r);
  }

  Future<SignUpResult> signUp(String email, String password) async {
    final r = await _send(() => _http.post(Uri.parse('${config.base}/auth/v1/signup'), headers: _headers(), body: jsonEncode({'email': email, 'password': password})));
    if (r.statusCode != 200) throw _fail(r);
    final j = _json(r);
    // an address that already has an account comes back as a user with no identities (the server does not say so in words)
    final ids = j['identities'] ?? (j['user'] is Map ? (j['user'] as Map)['identities'] : null);
    if (ids is List && ids.isEmpty) throw const AuthFailure(AuthProblem.userExists);
    return SignUpResult(session: _session(j), email: email);
  }

  Future<void> sendResetLink(String email) async {
    final r = await _send(() => _http.post(Uri.parse('${config.base}/auth/v1/recover'), headers: _headers(), body: jsonEncode({'email': email})));
    if (r.statusCode != 200) throw _fail(r);
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final r = await _send(() => _http.post(Uri.parse('${config.base}/auth/v1/token?grant_type=refresh_token'), headers: _headers(), body: jsonEncode({'refresh_token': refreshToken})));
    if (r.statusCode == 400 || r.statusCode == 401) throw const AuthFailure(AuthProblem.wrongLogin); // the session was cancelled
    return _needSession(r);
  }

  /// Does this signed-in person belong to the shop? (Row-level security shows a person only their own shop's rows, so
  /// "no rows" means "no access".)
  Future<bool> isShopMember(String accessToken) async {
    final r = await _send(() => _http.get(Uri.parse('${config.base}/rest/v1/shop_members?select=shop_id&active=eq.true&limit=1'), headers: _headers(accessToken)));
    if (r.statusCode != 200) throw _fail(r);
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      return j is List && j.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Ends the session on the server (best effort: signing out here must work with no internet too).
  Future<void> signOut(String accessToken) async {
    try {
      await _http.post(Uri.parse('${config.base}/auth/v1/logout'), headers: _headers(accessToken)).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}
