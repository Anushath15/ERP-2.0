import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../link_launcher.dart';
import 'auth_api.dart';
import 'google_flow.dart';

GoogleFlow createGoogleFlow() => LoopbackGoogleFlow();

String _b64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// The PKCE pair: a random secret ("verifier") that never leaves this program until the last step, and its SHA-256 ("challenge"), which
/// goes to Google/Supabase first. Whoever catches the one-time code on the way back cannot use it without the verifier.
({String verifier, String challenge}) newPkce([Random? random]) {
  final r = random ?? Random.secure();
  final verifier = _b64url(List<int>.generate(48, (_) => r.nextInt(256)));
  return (verifier: verifier, challenge: _b64url(sha256.convert(ascii.encode(verifier)).bytes));
}

/// Standard desktop sign-in ("loopback"): this program listens on 127.0.0.1 on a free port for a few minutes, opens the browser, and
/// the browser comes back to that address with a one-time code. The listener only accepts this computer, answers once, then closes.
class LoopbackGoogleFlow implements GoogleFlow {
  @override
  Future<AuthSession> run(AuthApi api, LinkLauncher launcher, {Duration timeout = const Duration(minutes: 3)}) async {
    final pkce = newPkce();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final redirect = 'http://127.0.0.1:${server.port}/callback';
      final opened = await launcher.open(api.googleUrl(redirectTo: redirect, challenge: pkce.challenge).toString());
      if (!opened) throw const AuthFailure(AuthProblem.other);
      final code = await _waitForCode(server).timeout(timeout, onTimeout: () => throw const AuthFailure(AuthProblem.timedOut));
      return await api.exchangeCode(code, pkce.verifier);
    } finally {
      await server.close(force: true);
    }
  }

  Future<String> _waitForCode(HttpServer server) async {
    await for (final req in server) {
      if (req.uri.path != '/callback') {
        req.response.statusCode = 404;
        await req.response.close();
        continue;
      }
      final q = req.uri.queryParameters;
      final code = q['code'];
      final failed = q.containsKey('error') || q.containsKey('error_description');
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..headers.set('Cache-Control', 'no-store')
        ..write(_page(ok: code != null && !failed));
      await req.response.close();
      if (failed || code == null || code.isEmpty) throw const AuthFailure(AuthProblem.cancelled);
      return code;
    }
    throw const AuthFailure(AuthProblem.cancelled);
  }

  String _page({required bool ok}) => '<!doctype html><meta charset="utf-8"><title>ASK ERP 2.0</title>'
      '<body style="font-family:Segoe UI,Arial,sans-serif;text-align:center;margin-top:18vh">'
      '<h2>${ok ? 'You are signed in' : 'Sign-in was not completed'}</h2>'
      '<p>${ok ? 'You can close this tab and go back to ASK ERP 2.0.' : 'Go back to ASK ERP 2.0 and press the Google button to try again.'}</p></body>';
}
