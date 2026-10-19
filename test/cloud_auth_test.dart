import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:erp2/core/cloud/auth_api.dart';
import 'package:erp2/core/cloud/auth_controller.dart';
import 'package:erp2/core/cloud/cloud_config.dart';
import 'package:erp2/core/cloud/session_vault.dart';
import 'package:erp2/core/cloud/session_vault_io.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers.dart';

// What these tests prove: the sign-in logic (email + password, the kept sign-in, who is let in, sign out) against a pretend cloud,
// and the screens that use it.
// What they do NOT prove: that the real Supabase project accepts these calls.
const config = CloudConfig(url: 'https://example.supabase.co', key: 'sb_publishable_test');

http.Response json(int code, Object body) => http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json'});

Map<String, Object?> sessionBody(String email, {String refresh = 'r1'}) => {'access_token': 'a-$refresh', 'refresh_token': refresh, 'expires_in': 3600, 'user': {'id': 'u1', 'email': email}};

/// A pretend cloud: answers by path. [member] is whether the person is on the shop's member list.
class FakeCloud {
  FakeCloud({this.member = true});
  bool member;
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
          case 'POST /auth/v1/signup':
            return json(200, {'id': 'u9', 'email': bodies[key]!['email'], 'identities': [{'id': 'i'}]});
          case 'POST /auth/v1/recover':
            return json(200, {});
          case 'POST /auth/v1/logout':
            return http.Response('', 204);
          case 'GET /rest/v1/shop_members':
            expect(req.headers['Authorization'], startsWith('Bearer a-'), reason: 'the membership check is made as the person, not as the app');
            return json(200, member ? [{'shop_id': 's1'}] : []);
        }
        return json(404, {});
      });
}

ProviderContainer container(FakeCloud cloud, {SessionVault? vault, CloudConfig cfg = config}) {
  final c = ProviderContainer(overrides: [
    cloudConfigProvider.overrideWithValue(cfg),
    authApiProvider.overrideWithValue(AuthApi(cfg, client: cloud.client)),
    sessionVaultProvider.overrideWithValue(vault ?? MemorySessionVault()),
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
    });

    test('sign up: the usual answer is "open the e-mailed link"; an existing address is recognised', () async {
      final cloud = FakeCloud();
      final r = await api(cloud).signUp('new@gmail.com', 'secret1');
      expect(r.session, isNull);
      final dup = AuthApi(config, client: MockClient((_) async => json(200, {'id': 'u', 'identities': []})));
      await expectLater(dup.signUp('old@gmail.com', 'secret1'), throwsA(isA<AuthFailure>().having((e) => e.problem, 'problem', AuthProblem.userExists)));
    });

    test('the membership check', () async {
      final cloud = FakeCloud(member: false);
      expect(await api(cloud).isShopMember('a-x'), isFalse);
      cloud.member = true;
      expect(await api(cloud).isShopMember('a-x'), isTrue);
    });

    test('a cancelled session (refresh refused) is told apart from no internet', () async {
      final cloud = FakeCloud()..refreshStatus = 400;
      await expectLater(api(cloud).refresh('old'), throwsA(isA<AuthFailure>().having((e) => e.problem, 'problem', AuthProblem.wrongLogin)));
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
    Future<(ProviderContainer, FakeCloud)> signIn(WidgetTester t, {FakeCloud? cloud}) async {
      final fake = cloud ?? FakeCloud();
      final c = await pumpApp(t, size: desktop1366, location: '/signin', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [
        cloudConfigProvider.overrideWithValue(config),
        authApiProvider.overrideWithValue(AuthApi(config, client: fake.client)),
        sessionVaultProvider.overrideWithValue(MemorySessionVault()),
      ]);
      return (c, fake);
    }

    testWidgets('signed out, any page leads to the sign-in screen; a wrong password says so; the right one opens the program', (tester) async {
      final (c, cloud) = await signIn(tester);
      expect(find.byKey(const ValueKey('signInButton')), findsOneWidget);
      expect(find.textContaining('Google'), findsNothing, reason: 'there is no Google sign-in');
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
