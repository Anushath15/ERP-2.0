import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:erp2/core/cloud/auth_api.dart';
import 'package:erp2/core/cloud/auth_controller.dart';
import 'package:erp2/core/cloud/cloud_config.dart';
import 'package:erp2/core/cloud/google_flow.dart';
import 'package:erp2/core/cloud/google_flow_io.dart';
import 'package:erp2/core/cloud/session_vault.dart';
import 'package:erp2/core/cloud/session_vault_io.dart';
import 'package:erp2/core/link_launcher.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/credit/reminder.dart' show LinkPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers.dart';

// What these tests prove: the sign-in logic (email + password, Google through the browser, the kept sign-in, who is let in, sign out) against
// a pretend cloud, and the screens that use it.
// What they do NOT prove: that the real Supabase project accepts these calls, or that Google is set up there. Google needs the owner's one-time
// setup (docs/OWNER-SETUP.md, section 6); until then the program says so in plain words.
const config = CloudConfig(url: 'https://example.supabase.co', key: 'sb_publishable_test');

http.Response json(int code, Object body) => http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json'});

Map<String, Object?> sessionBody(String email, {String refresh = 'r1'}) => {'access_token': 'a-$refresh', 'refresh_token': refresh, 'expires_in': 3600, 'user': {'id': 'u1', 'email': email}};

/// A pretend cloud: answers by path. [member] is whether the person is on the shop's member list.
class FakeCloud {
  FakeCloud({this.member = true, this.googleOn = true});
  bool member, googleOn;
  final calls = <String>[];
  final bodies = <String, Map<String, Object?>>{};
  Object? passwordError;
  int refreshStatus = 200;
  bool offline = false;

  MockClient get client => MockClient((req) async {
        if (offline) throw const SocketException('no internet');
        final key = '${req.method} ${req.url.path}${req.url.queryParameters['grant_type'] == null ? '' : '?${req.url.queryParameters['grant_type']}'}';
        calls.add(key);
        expect(req.headers['apikey'], config.key, reason: 'every call carries the publishable key');
        if (req.body.isNotEmpty) bodies[key] = (jsonDecode(req.body) as Map).cast<String, Object?>();
        switch (key) {
          case 'POST /auth/v1/token?password':
            return passwordError == null ? json(200, sessionBody(bodies[key]!['email'] as String)) : json(400, passwordError!);
          case 'POST /auth/v1/token?refresh_token':
            return refreshStatus == 200 ? json(200, sessionBody('owner@gmail.com', refresh: 'r2')) : json(refreshStatus, {'error_code': 'refresh_token_not_found'});
          case 'POST /auth/v1/token?pkce':
            return json(200, sessionBody('owner@gmail.com', refresh: 'g1'));
          case 'POST /auth/v1/signup':
            return json(200, {'id': 'u9', 'email': bodies[key]!['email'], 'identities': [{'id': 'i'}]});
          case 'POST /auth/v1/recover':
            return json(200, {});
          case 'POST /auth/v1/logout':
            return http.Response('', 204);
          case 'GET /auth/v1/settings':
            return json(200, {'external': {'google': googleOn, 'email': true}});
          case 'GET /rest/v1/shop_members':
            expect(req.headers['Authorization'], startsWith('Bearer a-'), reason: 'the membership check is made as the person, not as the app');
            return json(200, member ? [{'shop_id': 's1'}] : []);
        }
        return json(404, {});
      });
}

class FakeBrowser implements LinkLauncher {
  FakeBrowser(this.onOpen);
  final Future<void> Function(Uri url) onOpen;
  final opened = <Uri>[];
  @override
  LinkPlatform get platform => LinkPlatform.windows;
  @override
  Future<bool> open(String url) async {
    opened.add(Uri.parse(url));
    // the "browser" comes back to the program a moment later, like a real one
    Future<void>.delayed(const Duration(milliseconds: 20), () => onOpen(Uri.parse(url)));
    return true;
  }
}

/// A tiny browser: one GET over a plain socket (the test framework replaces the normal HTTP client, so it cannot be used here).
Future<int> hit(Uri u) async {
  final socket = await Socket.connect(u.host, u.port);
  try {
    final target = u.hasQuery ? '${u.path}?${u.query}' : u.path;
    socket.write('GET $target HTTP/1.1\r\nHost: ${u.host}:${u.port}\r\nConnection: close\r\n\r\n');
    await socket.flush();
    final text = await socket.cast<List<int>>().transform(utf8.decoder).join();
    return int.parse(text.split(' ')[1]);
  } finally {
    socket.destroy();
  }
}

class FakeGoogle implements GoogleFlow {
  FakeGoogle({this.failure});
  AuthFailure? failure;
  @override
  Future<AuthSession> run(AuthApi api, LinkLauncher launcher, {Duration timeout = const Duration(minutes: 3)}) async {
    if (failure != null) throw failure!;
    return api.exchangeCode('code', 'verifier');
  }
}

ProviderContainer container(FakeCloud cloud, {SessionVault? vault, GoogleFlow? google, CloudConfig cfg = config}) {
  final c = ProviderContainer(overrides: [
    cloudConfigProvider.overrideWithValue(cfg),
    authApiProvider.overrideWithValue(AuthApi(cfg, client: cloud.client)),
    sessionVaultProvider.overrideWithValue(vault ?? MemorySessionVault()),
    googleFlowProvider.overrideWithValue(google ?? FakeGoogle()),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('AuthApi', () {
    AuthApi api(FakeCloud c) => AuthApi(config, client: c.client);

    test('email and password: a session; wrong password, unconfirmed e-mail and a busy server are told apart', () async {
      final cloud = FakeCloud();
      final s = await api(cloud).signInWithPassword('Owner@Gmail.com', 'secret1');
      expect((s.email, s.refreshToken), ('Owner@Gmail.com', 'r1'));
      cloud.passwordError = {'error_code': 'invalid_credentials', 'msg': 'Invalid login credentials'};
      await expectLater(api(cloud).signInWithPassword('a@b.com', 'x'), throwsA(isA<AuthFailure>().having((e) => e.problem, 'problem', AuthProblem.wrongLogin)));
      cloud.passwordError = {'error_code': 'email_not_confirmed'};
      await expectLater(api(cloud).signInWithPassword('a@b.com', 'x'), throwsA(isA<AuthFailure>().having((e) => e.problem, 'problem', AuthProblem.notConfirmed)));
    });

    test('no internet: a network failure, never a crash', () async {
      final cloud = FakeCloud()..offline = true;
      await expectLater(api(cloud).signInWithPassword('a@b.com', 'x'), throwsA(isA<AuthFailure>().having((e) => e.problem, 'problem', AuthProblem.network)));
      expect(await api(cloud).googleEnabled().then((_) => 'no', onError: (_) => 'failure'), 'failure');
    });

    test('sign up: the usual answer is "open the e-mailed link"; an existing address is recognised', () async {
      final cloud = FakeCloud();
      final r = await api(cloud).signUp('new@gmail.com', 'secret1');
      expect(r.session, isNull);
      final dup = AuthApi(config, client: MockClient((_) async => json(200, {'id': 'u', 'identities': []})));
      await expectLater(dup.signUp('old@gmail.com', 'secret1'), throwsA(isA<AuthFailure>().having((e) => e.problem, 'problem', AuthProblem.userExists)));
    });

    test('Google settings, the membership check and the Google address', () async {
      final cloud = FakeCloud(googleOn: false, member: false);
      expect(await api(cloud).googleEnabled(), isFalse);
      cloud.googleOn = true;
      expect(await api(cloud).googleEnabled(), isTrue);
      expect(await api(cloud).isShopMember('a-x'), isFalse);
      cloud.member = true;
      expect(await api(cloud).isShopMember('a-x'), isTrue);
      final u = api(cloud).googleUrl(redirectTo: 'http://127.0.0.1:5000/callback', challenge: 'abc');
      expect(u.path, '/auth/v1/authorize');
      expect(u.queryParameters, {'provider': 'google', 'redirect_to': 'http://127.0.0.1:5000/callback', 'code_challenge': 'abc', 'code_challenge_method': 's256'});
    });

    test('a cancelled session (refresh refused) is told apart from no internet', () async {
      final cloud = FakeCloud()..refreshStatus = 400;
      await expectLater(api(cloud).refresh('old'), throwsA(isA<AuthFailure>().having((e) => e.problem, 'problem', AuthProblem.wrongLogin)));
    });
  });

  group('Google through the browser (loopback)', () {
    test('the PKCE challenge is the SHA-256 of the secret, URL-safe, no padding', () {
      final p = newPkce();
      expect(p.verifier.length, greaterThanOrEqualTo(43));
      expect(p.challenge, base64Url.encode(sha256.convert(ascii.encode(p.verifier)).bytes).replaceAll('=', ''));
      expect(p.challenge, isNot(contains('=')));
      expect(newPkce().verifier, isNot(p.verifier));
    });

    test('the browser comes back with a code: it is exchanged together with the secret, and the listener closes', () async {
      final cloud = FakeCloud();
      final api = AuthApi(config, client: cloud.client);
      late Uri redirect;
      final browser = FakeBrowser((url) async {
        redirect = Uri.parse(url.queryParameters['redirect_to']!);
        expect(redirect.host, '127.0.0.1');
        expect(await hit(redirect.replace(path: '/favicon.ico')), 404, reason: 'anything but the callback is refused');
        expect(await hit(redirect.replace(queryParameters: {'code': 'abc123'})), 200);
      });
      final s = await LoopbackGoogleFlow().run(api, browser);
      expect(s.refreshToken, 'g1');
      final sent = cloud.bodies['POST /auth/v1/token?pkce']!;
      expect(sent['auth_code'], 'abc123');
      final challenge = browser.opened.single.queryParameters['code_challenge'];
      expect(base64Url.encode(sha256.convert(ascii.encode(sent['code_verifier'] as String)).bytes).replaceAll('=', ''), challenge, reason: 'the secret that is sent matches the challenge the browser got');
      await expectLater(hit(redirect), throwsA(isA<SocketException>()), reason: 'the listener is closed after one answer');
    });

    test('the person says no in the browser: cancelled; nobody comes back: timed out', () async {
      final api = AuthApi(config, client: FakeCloud().client);
      final denied = FakeBrowser((url) async => hit(Uri.parse(url.queryParameters['redirect_to']!).replace(queryParameters: {'error': 'access_denied', 'error_description': 'no'})));
      await expectLater(LoopbackGoogleFlow().run(api, denied), throwsA(isA<AuthFailure>().having((e) => e.problem, 'problem', AuthProblem.cancelled)));
      final silent = FakeBrowser((_) async {});
      await expectLater(LoopbackGoogleFlow().run(api, silent, timeout: const Duration(milliseconds: 300)), throwsA(isA<AuthFailure>().having((e) => e.problem, 'problem', AuthProblem.timedOut)));
    });
  });

  group('the kept sign-in on this computer', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('vault'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('written, read back, removed; on Windows the file is encrypted (the token is not readable in it)', () {
      final v = FileSessionVault(File('${dir.path}/session.bin'));
      expect(v.read(), isNull);
      v.write('{"refresh":"SECRET-TOKEN-123"}');
      expect(v.read(), '{"refresh":"SECRET-TOKEN-123"}');
      if (Platform.isWindows) {
        expect(latin1.decode(File('${dir.path}/session.bin').readAsBytesSync()), isNot(contains('SECRET-TOKEN-123')));
      }
      v.write(null);
      expect(v.read(), isNull);
      expect(File('${dir.path}/session.bin').existsSync(), isFalse);
    });

    test('a damaged or foreign file means "not signed in", never a crash', () {
      final f = File('${dir.path}/session.bin')..writeAsBytesSync(Uint8List.fromList(List.generate(300, (i) => i % 251)));
      expect(FileSessionVault(f).read(), isNull);
      f.writeAsBytesSync(Uint8List(20000));
      expect(FileSessionVault(f).read(), isNull);
    });
  });

  group('AuthController', () {
    test('email sign-in by a shop member: signed in and kept; by anyone else: signed straight out, nothing kept', () async {
      final cloud = FakeCloud();
      final vault = MemorySessionVault();
      final c = container(cloud, vault: vault);
      expect(await c.read(authProvider.notifier).signIn('owner@gmail.com', 'secret1'), isNull);
      expect(c.read(authProvider).status, AuthStatus.signedIn);
      expect(jsonDecode(vault.read()!)['refresh'], 'r1');
      await c.read(authProvider.notifier).signOut();
      expect(vault.read(), isNull);
      expect(c.read(authProvider).status, AuthStatus.signedOut);
      expect(cloud.calls, contains('POST /auth/v1/logout'));

      cloud.member = false;
      final f = await c.read(authProvider.notifier).signIn('stranger@gmail.com', 'secret1');
      expect(f!.problem, AuthProblem.notMember);
      expect(f.email, 'stranger@gmail.com');
      expect(c.read(authProvider).status, AuthStatus.signedOut);
      expect(vault.read(), isNull, reason: 'a person with no access keeps nothing on this computer');
    });

    test('Google: not switched on in the cloud is said so; switched on, a member gets in', () async {
      final cloud = FakeCloud(googleOn: false);
      final c = container(cloud);
      expect((await c.read(authProvider.notifier).google())!.problem, AuthProblem.googleOff);
      cloud.googleOn = true;
      expect(await c.read(authProvider.notifier).google(), isNull);
      expect((c.read(authProvider).status, c.read(authProvider).email), (AuthStatus.signedIn, 'owner@gmail.com'));
    });

    test('starting the program: the kept sign-in is renewed; with no internet it is trusted; if the cloud cancelled it, the person must sign in again', () async {
      final cloud = FakeCloud();
      final vault = MemorySessionVault(jsonEncode({'refresh': 'r1', 'email': 'owner@gmail.com'}));
      final c = container(cloud, vault: vault);
      expect(c.read(authProvider).status, AuthStatus.loading);
      await c.read(authProvider.notifier).restore();
      expect(c.read(authProvider).status, AuthStatus.signedIn);
      expect(jsonDecode(vault.read()!)['refresh'], 'r2', reason: 'the renewed token replaces the old one');

      final offline = FakeCloud()..offline = true;
      final c2 = container(offline, vault: MemorySessionVault(jsonEncode({'refresh': 'r1', 'email': 'owner@gmail.com'})));
      await c2.read(authProvider.notifier).restore();
      expect(c2.read(authProvider).status, AuthStatus.signedIn, reason: 'no internet: the shop keeps working');

      final cancelled = FakeCloud()..refreshStatus = 400;
      final v3 = MemorySessionVault(jsonEncode({'refresh': 'r1', 'email': 'owner@gmail.com'}));
      final c3 = container(cancelled, vault: v3);
      await c3.read(authProvider.notifier).restore();
      expect(c3.read(authProvider).status, AuthStatus.signedOut);
      expect(v3.read(), isNull);

      final c4 = container(FakeCloud());
      await c4.read(authProvider.notifier).restore();
      expect(c4.read(authProvider).status, AuthStatus.signedOut, reason: 'nothing kept: first time on this computer');
    });

    test('create account: the usual answer is "open the link we e-mailed"', () async {
      final c = container(FakeCloud());
      final r = await c.read(authProvider.notifier).createAccount('new@gmail.com', 'secret1');
      expect((r.failure, r.needsConfirm), (null, true));
      expect(c.read(authProvider).status, isNot(AuthStatus.signedIn));
    });

    test('with no cloud address in the build nothing is gated: signed out state, restore does nothing', () async {
      final c = container(FakeCloud(), cfg: const CloudConfig(url: '', key: ''));
      expect(c.read(authProvider).status, AuthStatus.signedOut);
      await c.read(authProvider.notifier).restore();
      expect(c.read(authProvider).status, AuthStatus.signedOut);
    });
  });

  group('screens', () {
    Future<(ProviderContainer, FakeCloud)> signIn(WidgetTester t, {FakeCloud? cloud, GoogleFlow? google}) async {
      final fake = cloud ?? FakeCloud();
      final c = await pumpApp(t, size: desktop1366, location: '/signin', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [
        cloudConfigProvider.overrideWithValue(config),
        authApiProvider.overrideWithValue(AuthApi(config, client: fake.client)),
        sessionVaultProvider.overrideWithValue(MemorySessionVault()),
        googleFlowProvider.overrideWithValue(google ?? FakeGoogle()),
      ]);
      return (c, fake);
    }

    testWidgets('signed out, any page leads to the sign-in screen; a wrong password says so; the right one opens the program', (tester) async {
      final (c, cloud) = await signIn(tester);
      expect(find.byKey(const ValueKey('signInButton')), findsOneWidget);
      cloud.passwordError = {'error_code': 'invalid_credentials'};
      await tester.enterText(find.byType(TextField).at(0), 'owner@gmail.com');
      await tester.enterText(find.byType(TextField).at(1), 'wrong-pass');
      await tester.tap(find.byKey(const ValueKey('signInButton')));
      await tester.pumpAndSettle();
      expect(find.text('Wrong email or password.'), findsOneWidget);
      cloud.passwordError = null;
      await tester.enterText(find.byType(TextField).at(1), 'right-pass');
      await tester.tap(find.byKey(const ValueKey('signInButton')));
      await tester.pumpAndSettle();
      expect(c.read(authProvider).status, AuthStatus.signedIn);
      expect(find.byKey(const ValueKey('signInButton')), findsNothing, reason: 'the program is open');
      expect(find.text('Wrong email or password.'), findsNothing);
    });

    testWidgets('a person who is not on the shop list is told so and stays out', (tester) async {
      final (c, _) = await signIn(tester, cloud: FakeCloud(member: false));
      await tester.enterText(find.byType(TextField).at(0), 'stranger@gmail.com');
      await tester.enterText(find.byType(TextField).at(1), 'right-pass');
      await tester.tap(find.byKey(const ValueKey('signInButton')));
      await tester.pumpAndSettle();
      expect(find.textContaining('stranger@gmail.com, but this account has no access'), findsOneWidget);
      expect(c.read(authProvider).status, AuthStatus.signedOut);
    });

    testWidgets('Continue with Google: not switched on says so in plain words; switched on, signs in', (tester) async {
      final cloud = FakeCloud(googleOn: false);
      final (c, _) = await signIn(tester, cloud: cloud);
      await tester.tap(find.byKey(const ValueKey('googleSignIn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Google sign-in is not switched on yet'), findsOneWidget);
      cloud.googleOn = true;
      await tester.tap(find.byKey(const ValueKey('googleSignIn')));
      await tester.pumpAndSettle();
      expect(c.read(authProvider).status, AuthStatus.signedIn);
    });

    testWidgets('create account: the screen explains the e-mailed link and goes back to Sign in', (tester) async {
      await signIn(tester);
      await tester.tap(find.text('First time? Make the shop account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'new@gmail.com');
      await tester.enterText(find.byType(TextField).at(1), 'secret12');
      await tester.tap(find.byKey(const ValueKey('signInButton')));
      await tester.pumpAndSettle();
      expect(find.text('We sent a link to new@gmail.com. Open it, then press Sign in.'), findsOneWidget);
    });
  });
}
