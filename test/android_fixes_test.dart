import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/backup_controller.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/shell.dart' show touchDeviceProvider;
import 'package:erp2/features/auth/auth_screens.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'backup_screens_test.dart' show makeEnv, real;
import 'helpers.dart';

// What these tests prove (Android problems found in the phone audit; the phone-only parts are switched on by the window size or by providers, so
// the computer behaves exactly as before):
//  1 the Back button goes to the page before, then to Home, and closes the program only on a second press on Home;
//  2 the Bill page on a phone has a way out;
//  3 on a phone the backup is also copied to Downloads and can be sent, without touching the computer page;
//  4 an unfinished bill is kept and brought back; on a computer nothing is kept;
//  5 a phone that joins a cloud shop is not offered the letter of the main computer.
class FakeMirror implements BackupMirror {
  FakeMirror({this.place = 'Downloads/ASK ERP 2.0/x.sqlite', this.sendOk = true});
  final String? place;
  final bool sendOk;
  final saved = <String>[];
  final sent = <String>[];
  @override
  Future<String?> save(String path) async {
    saved.add(path);
    return place;
  }

  @override
  Future<bool> send(String path) async {
    sent.add(path);
    return sendOk;
  }
}

String pathOf(WidgetTester t) => GoRouter.of(t.element(find.byType(Scaffold).first)).routerDelegate.currentConfiguration.uri.path;

void main() {
  late List<String> platformCalls;
  setUp(() {
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call.method);
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

  testWidgets('phone: Back returns page by page to Home; on Home the first press asks, the second closes', (tester) async {
    await pumpApp(tester, size: phone390, location: '/', motion: MotionLevel.off, followSystemMotion: false);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/more');
    await tester.pumpAndSettle();
    router.go('/about');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(pathOf(tester), '/more', reason: 'from About, Back is More (it used to close the program)');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(pathOf(tester), '/');
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Press Back again to close the program'), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')), reason: 'one press on Home never closes');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(platformCalls, contains('SystemNavigator.pop'));
  });

  testWidgets('phone: a page opened first (no page before) goes to Home on Back, not out of the program', (tester) async {
    await pumpApp(tester, size: phone390, location: '/about', motion: MotionLevel.off, followSystemMotion: false);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(pathOf(tester), '/');
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
  });

  testWidgets('a narrow computer window keeps the Bill page as it was (no arrow added): only a real phone gets it', (tester) async {
    await pumpApp(tester, size: phone390, location: '/bill', motion: MotionLevel.off, followSystemMotion: false);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('phone: the Bill page has a back arrow (no tab bar there) and it leaves the page', (tester) async {
    await pumpApp(tester, size: phone390, location: '/bill', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [touchDeviceProvider.overrideWithValue(true)]);
    expect(find.byType(NavigationBar), findsNothing, reason: 'the bill page keeps the screen for the bill');
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget, reason: 'a way out (it had none)');
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(pathOf(tester), '/');
    // the dashboard tab shows the bar and no arrow
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('a computer window: Back is not taken over (no guard, no toast); Windows behaves as before', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/about', motion: MotionLevel.off, followSystemMotion: false);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Press Back again to close the program'), findsNothing);
    expect(pathOf(tester), '/about', reason: 'nothing moved: the computer has no Back button to answer');
  });

  testWidgets('the unfinished bill is saved after every change, brought back when asked, and cleared once it is saved', (tester) async {
    final c = await pumpApp(tester, size: phone390, location: '/', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [cartDraftEnabledProvider.overrideWithValue(true)]);
    final cart = c.read(cartProvider(DocMode.invoice).notifier);
    final prod = c.read(productsProvider).first;
    final cust = c.read(customersProvider).first;
    cart.add(prod, qtyMilli: 2000);
    cart.setCustomer(cust);
    cart.setExtraDiscountAmount(500);
    Future<String?> draft() async => (await tester.runAsync<String?>(() => c.read(appDataProvider).settings.get('draft.bill')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    final saved = await draft();
    expect(saved, isNotNull);
    expect(saved, contains(prod.id));
    // "the program was closed": a new empty cart, then the Bill page asks for the draft
    c.invalidate(cartProvider(DocMode.invoice));
    expect(c.read(cartProvider(DocMode.invoice)).lines, isEmpty);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.runAsync(() => c.read(appDataProvider).settings.put('draft.bill', saved!)); // what the last session left in the file
    final back = (await tester.runAsync(() => c.read(cartProvider(DocMode.invoice).notifier).restoreDraft()))!;
    expect(back, isTrue);
    final s = c.read(cartProvider(DocMode.invoice));
    expect((s.lines.single.product.id, s.lines.single.qtyMilli), (prod.id, 2000));
    expect(s.customer?.id, cust.id);
    expect(s.extraDiscountPaise, 500);
    // saved bill -> cart cleared -> no draft left
    c.read(cartProvider(DocMode.invoice).notifier).clear();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    expect(await draft(), isEmpty);
    expect((await tester.runAsync(() => c.read(cartProvider(DocMode.invoice).notifier).restoreDraft()))!, isFalse);
  });

  testWidgets('opening the Bill page on a phone shows the brought-back bill and says so', (tester) async {
    final c = await pumpApp(tester, size: phone390, location: '/', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [cartDraftEnabledProvider.overrideWithValue(true)]);
    final prod = c.read(productsProvider).first;
    c.read(cartProvider(DocMode.invoice).notifier).add(prod);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    final left = (await tester.runAsync<String?>(() => c.read(appDataProvider).settings.get('draft.bill')))!;
    c.invalidate(cartProvider(DocMode.invoice)); // the program was closed and opened again
    expect(c.read(cartProvider(DocMode.invoice)).lines, isEmpty);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.runAsync(() => c.read(appDataProvider).settings.put('draft.bill', left)); // what the last session left in the file
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/bill');
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(c.read(cartProvider(DocMode.invoice)).lines, hasLength(1));
    expect(find.text('Your unsaved bill was brought back.'), findsOneWidget);
  });

  testWidgets('on a computer nothing is kept (the draft is an Android-only help)', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/', motion: MotionLevel.off, followSystemMotion: false);
    expect(c.read(cartDraftEnabledProvider), isFalse);
    c.read(cartProvider(DocMode.invoice).notifier).add(c.read(productsProvider).first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    expect(await tester.runAsync<String?>(() => c.read(appDataProvider).settings.get('draft.bill')), isNull);
  });

  test('a draft that is old, unreadable or of products that no longer exist brings nothing back', () {
    expect(decodeCartDraft('', const [], const []), isNull);
    expect(decodeCartDraft('not json', const [], const []), isNull);
    expect(decodeCartDraft('{"v":2}', const [], const []), isNull);
    expect(decodeCartDraft('{"v":1,"t":0,"lines":[{"p":"gone","q":1000}]}', const [], const [], nowMs: 10), isNull, reason: 'no such product');
    expect(decodeCartDraft('{"v":1,"t":0,"lines":[{"p":"x","q":1000}]}', const [], const [], nowMs: const Duration(days: 4).inMilliseconds), isNull, reason: 'older than 3 days');
  });

  testWidgets('phone Backups page: a copy in Downloads is made with every backup and can be saved again or sent; the computer folder buttons are not shown', (tester) async {
    final env = await makeEnv(tester);
    final mirror = FakeMirror();
    final c = await pumpApp(tester, size: phone390, location: '/backups', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [...env.overrides, backupMirrorProvider.overrideWithValue(mirror)]);
    await tester.runAsync(() => c.read(backupControllerProvider.notifier).load());
    await real(tester, 200);
    expect(find.byKey(const ValueKey('backupFolderPhone')), findsOneWidget);
    expect(find.byKey(const ValueKey('changeFolder')), findsNothing);
    expect(find.byKey(const ValueKey('copyBackup')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('backupNow')));
    await real(tester, 2500);
    expect(c.read(backupControllerProvider).lastError, isNull);
    expect(mirror.saved, hasLength(1), reason: 'the backup just made was copied out');
    expect(p.basename(mirror.saved.single), startsWith('ASKERP_'));
    expect(c.read(backupControllerProvider).copyPlace, 'Downloads/ASK ERP 2.0/x.sqlite');
    await tester.pump();
    expect(find.byKey(const ValueKey('backupCopyAt')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('sendCopy')));
    await tester.tap(find.byKey(const ValueKey('sendCopy')));
    await real(tester, 300);
    expect(mirror.sent, hasLength(1));
    await tester.ensureVisible(find.byKey(const ValueKey('saveDownloads')));
    await tester.tap(find.byKey(const ValueKey('saveDownloads')));
    await real(tester, 300);
    expect(mirror.saved, hasLength(2));
  });

  testWidgets('phone Backups page: when the copy cannot be made the backup is still fine and the page says so in plain words', (tester) async {
    final env = await makeEnv(tester);
    final mirror = FakeMirror(place: null, sendOk: false);
    final c = await pumpApp(tester, size: phone390, location: '/backups', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [...env.overrides, backupMirrorProvider.overrideWithValue(mirror)]);
    await tester.runAsync(() => c.read(backupControllerProvider.notifier).load());
    await tester.tap(find.byKey(const ValueKey('backupNow')));
    await real(tester, 2500);
    expect(c.read(backupControllerProvider).lastError, isNull, reason: 'the backup itself succeeded');
    await tester.ensureVisible(find.byKey(const ValueKey('saveDownloads')));
    await tester.tap(find.byKey(const ValueKey('saveDownloads')));
    await real(tester, 300);
    expect(find.textContaining('could not be saved'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('sendCopy')));
    await tester.tap(find.byKey(const ValueKey('sendCopy')));
    await real(tester, 300);
    expect(find.textContaining('Nothing on this phone could open the backup'), findsOneWidget);
  });

  testWidgets('computer Backups page is unchanged: folder buttons, no phone copy buttons', (tester) async {
    final env = await makeEnv(tester);
    final c = await pumpApp(tester, size: desktop1366, location: '/backups', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: env.overrides);
    await tester.runAsync(() => c.read(backupControllerProvider.notifier).load());
    await real(tester, 200);
    expect(c.read(backupMirrorProvider), isNull);
    expect(find.byKey(const ValueKey('changeFolder')), findsOneWidget);
    expect(find.byKey(const ValueKey('copyBackup')), findsOneWidget);
    expect(find.byKey(const ValueKey('saveDownloads')), findsNothing);
    expect(find.byKey(const ValueKey('sendCopy')), findsNothing);
  });

  testWidgets('set-up on a phone that joins a cloud shop: the main computer letter A is not offered, the others are, and the page says why', (tester) async {
    await pumpApp(tester, size: phone390, location: '/wizard', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [reservedSeriesProvider.overrideWithValue(const {'A'})]);
    for (var i = 0; i < 6; i++) {
      if (find.byKey(const ValueKey('wizName')).evaluate().isNotEmpty) await tester.enterText(find.byKey(const ValueKey('wizName')), 'Test');
      final next = find.text('Next');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      if (find.byKey(const ValueKey('wizSeriesHelp')).evaluate().isNotEmpty) break;
    }
    expect(find.byKey(const ValueKey('wizSeriesPhone')), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('series-A'))).onSelected, isNull, reason: 'A is kept for the main computer');
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('series-B'))).onSelected, isNotNull);
    await tester.ensureVisible(find.byKey(const ValueKey('series-B')));
    await tester.tap(find.byKey(const ValueKey('series-B')));
    await tester.pump();
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('series-B'))).selected, isTrue);
  });

  testWidgets('set-up on a computer, or in a shop without cloud, still offers every free letter including A', (tester) async {
    final c = await pumpApp(tester, size: phone390, location: '/wizard', motion: MotionLevel.off, followSystemMotion: false);
    expect(c.read(reservedSeriesProvider), isEmpty);
  });
}
