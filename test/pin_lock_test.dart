import 'package:erp2/core/cloud/session_vault.dart';
import 'package:erp2/core/lock/pin_lock.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: the PIN lock (hashes only, wrong tries counted across restarts with a growing wait, recovery code, lock after idle time,
// lock on start), and the screens (lock screen over everything, Settings card, top-bar Lock button).
// What they do NOT prove: protection against someone who can already sign in to this Windows account (the lock is for casual users).
void main() {
  late MemorySessionVault vault;
  late DateTime now;

  ProviderContainer make() {
    final c = ProviderContainer(overrides: [
      lockVaultProvider.overrideWithValue(vault),
      pinRoundsProvider.overrideWithValue(1000),
      lockClockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    vault = MemorySessionVault();
    now = DateTime(2026, 10, 19, 10, 0);
  });

  group('the PIN', () {
    test('only 4 to 8 digits; the recovery code is shown once; the vault holds hashes, not the PIN or the code', () async {
      final c = make();
      final ctl = c.read(pinLockProvider.notifier);
      for (final bad in ['', '123', '123456789', 'abcd', '12 34', '12.34']) {
        expect(await ctl.setPin(bad), isNull, reason: bad);
      }
      expect(c.read(pinLockProvider).enabled, isFalse);
      final code = (await ctl.setPin('482916'))!;
      expect(code, matches(RegExp(r'^[A-Z2-9]{4}(-[A-Z2-9]{4}){2}$')));
      expect(c.read(pinLockProvider).enabled, isTrue);
      expect(vault.read(), isNot(contains('482916')));
      expect(vault.read(), isNot(contains(code.replaceAll('-', ''))));
      expect(validPin('0000'), isTrue);
    });

    test('every start of the program is locked; the right PIN opens it, a wrong one does not', () async {
      final c1 = make();
      await c1.read(pinLockProvider.notifier).setPin('4821');
      final c2 = make(); // the program is started again
      expect(c2.read(pinLockProvider).locked, isTrue);
      expect(await c2.read(pinLockProvider.notifier).unlock('1111'), UnlockResult.wrong);
      expect(c2.read(pinLockProvider).locked, isTrue);
      expect(await c2.read(pinLockProvider.notifier).unlock('4821'), UnlockResult.ok);
      expect(c2.read(pinLockProvider).locked, isFalse);
    });

    test('without a PIN nothing is locked', () {
      final c = make();
      expect((c.read(pinLockProvider).enabled, c.read(pinLockProvider).locked), (false, false));
      c.read(pinLockProvider.notifier).lock();
      expect(c.read(pinLockProvider).locked, isFalse);
    });
  });

  group('wrong tries', () {
    test('every 5th wrong try in a row makes the program wait, even for the right PIN; the wait ends; a good try clears the count', () async {
      final c = make();
      final ctl = c.read(pinLockProvider.notifier);
      await ctl.setPin('4821');
      ctl.lock();
      for (var i = 0; i < 4; i++) {
        expect(await ctl.unlock('0000'), UnlockResult.wrong);
      }
      expect(await ctl.unlock('0000'), UnlockResult.waiting, reason: 'the 5th');
      expect(ctl.waitLeft, inInclusiveRange(29, 31));
      expect(await ctl.unlock('4821'), UnlockResult.waiting, reason: 'even the right PIN must wait');
      now = now.add(const Duration(seconds: 31));
      expect(await ctl.unlock('4821'), UnlockResult.ok);
      expect(c.read(pinLockProvider).failed, 0);
    });

    test('closing and opening the program does not reset the count; the wait grows (30 s, 60 s, ... up to 15 minutes)', () async {
      final c1 = make();
      await c1.read(pinLockProvider.notifier).setPin('4821');
      final c2 = make();
      var ctl = c2.read(pinLockProvider.notifier);
      for (var i = 0; i < 5; i++) {
        await ctl.unlock('0000');
      }
      final c3 = make(); // restarted during the wait
      ctl = c3.read(pinLockProvider.notifier);
      expect(await ctl.unlock('4821'), UnlockResult.waiting, reason: 'the wait survived the restart');
      now = now.add(const Duration(seconds: 31));
      for (var i = 0; i < 5; i++) {
        await ctl.unlock('0000');
      }
      expect(ctl.waitLeft, inInclusiveRange(59, 61), reason: 'the second round of five waits twice as long');
      for (var round = 0; round < 8; round++) {
        now = now.add(const Duration(minutes: 20));
        for (var i = 0; i < 5; i++) {
          await ctl.unlock('0000');
        }
      }
      expect(ctl.waitLeft, lessThanOrEqualTo(901));
    });
  });

  group('forgot the PIN', () {
    test('the recovery code (any capitals, with or without dashes) sets a new PIN and a new code; the old PIN and the old code stop working', () async {
      final c = make();
      final ctl = c.read(pinLockProvider.notifier);
      final code = (await ctl.setPin('4821'))!;
      ctl.lock();
      expect(await ctl.resetWithRecovery('AAAA-BBBB-CCCC', '7777'), isNull);
      expect(c.read(pinLockProvider).failed, 1, reason: 'a wrong recovery code counts as a wrong try');
      expect(await ctl.resetWithRecovery(code.toLowerCase().replaceAll('-', ' '), '12'), isNull, reason: 'the new PIN must be 4 to 8 digits');
      final newCode = (await ctl.resetWithRecovery(code.toLowerCase().replaceAll('-', ''), '7777'))!;
      expect(newCode, isNot(code));
      expect(await ctl.unlock('4821'), UnlockResult.wrong);
      expect(await ctl.unlock('7777'), UnlockResult.ok);
      ctl.lock();
      expect(await ctl.resetWithRecovery(code, '8888'), isNull, reason: 'the old recovery code is dead');
    });
  });

  group('locking by itself', () {
    test('after the chosen minutes without use; touching the program starts the time again; Never means only when Lock is pressed', () async {
      final c = make();
      final ctl = c.read(pinLockProvider.notifier);
      await ctl.setPin('4821');
      ctl.setMinutes(5);
      now = now.add(const Duration(minutes: 4));
      ctl.checkIdle();
      expect(c.read(pinLockProvider).locked, isFalse);
      ctl.touch();
      now = now.add(const Duration(minutes: 4));
      ctl.checkIdle();
      expect(c.read(pinLockProvider).locked, isFalse, reason: 'used 4 minutes ago');
      now = now.add(const Duration(minutes: 2));
      ctl.checkIdle();
      expect(c.read(pinLockProvider).locked, isTrue);
      await ctl.unlock('4821');
      ctl.setMinutes(0);
      now = now.add(const Duration(hours: 5));
      ctl.checkIdle();
      expect(c.read(pinLockProvider).locked, isFalse);
      ctl.lock();
      expect(c.read(pinLockProvider).locked, isTrue);
    });

    test('the chosen time is remembered; turning the lock off forgets everything', () async {
      final c1 = make();
      await c1.read(pinLockProvider.notifier).setPin('4821');
      c1.read(pinLockProvider.notifier).setMinutes(30);
      final c2 = make();
      expect(c2.read(pinLockProvider).minutes, 30);
      c2.read(pinLockProvider.notifier).turnOff();
      expect(vault.read(), isNull);
      expect(make().read(pinLockProvider).enabled, isFalse);
    });

    test('check(): the current PIN is told apart (for changing or turning off)', () async {
      final c = make();
      final ctl = c.read(pinLockProvider.notifier);
      await ctl.setPin('4821');
      expect(await ctl.check('4821'), isTrue);
      expect(await ctl.check('1234'), isFalse);
    });
  });

  group('screens', () {
    Future<ProviderContainer> app(WidgetTester t, {String location = '/', bool startLocked = false}) async {
      if (startLocked) {
        final seed = ProviderContainer(overrides: [lockVaultProvider.overrideWithValue(vault), pinRoundsProvider.overrideWithValue(1000)]);
        await t.runAsync(() => seed.read(pinLockProvider.notifier).setPin('4821'));
        seed.dispose();
      }
      return pumpApp(t, size: desktop1366, location: location, motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [
        lockVaultProvider.overrideWithValue(vault),
        pinRoundsProvider.overrideWithValue(1000),
      ]);
    }

    Future<void> real(WidgetTester t, [int ms = 300]) async {
      await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
      await t.pump(const Duration(milliseconds: 100));
    }

    testWidgets('the program opens locked: nothing under the lock screen can be used; wrong PIN says so; the right PIN opens it', (tester) async {
      await app(tester, startLocked: true);
      expect(find.byKey(const ValueKey('lockTitle')), findsOneWidget);
      expect(find.text('New bill').hitTestable(), findsNothing, reason: 'the program underneath cannot be clicked');
      await tester.enterText(find.byKey(const ValueKey('lockPin')), '1111');
      await tester.tap(find.byKey(const ValueKey('lockUnlock')));
      await real(tester);
      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(find.byKey(const ValueKey('lockTitle')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('lockPin')), '4821');
      await tester.tap(find.byKey(const ValueKey('lockUnlock')));
      await real(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lockTitle')), findsNothing);
      expect(find.text('New bill'), findsWidgets);
    });

    testWidgets('five wrong tries: the screen says to wait and the Unlock button is off', (tester) async {
      await app(tester, startLocked: true);
      for (var i = 0; i < 5; i++) {
        await tester.enterText(find.byKey(const ValueKey('lockPin')), '000$i');
        await tester.tap(find.byKey(const ValueKey('lockUnlock')), warnIfMissed: false);
        await real(tester);
      }
      expect(find.textContaining('Too many wrong tries'), findsWidgets);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('lockUnlock'))).onPressed, isNull);
    });

    testWidgets('Forgot the PIN: the recovery code and a new PIN get back in, and a new recovery code is shown', (tester) async {
      late String code;
      final seed = ProviderContainer(overrides: [lockVaultProvider.overrideWithValue(vault), pinRoundsProvider.overrideWithValue(1000)]);
      await tester.runAsync(() async => code = (await seed.read(pinLockProvider.notifier).setPin('4821'))!);
      seed.dispose();
      await pumpApp(tester, size: desktop1366, location: '/', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [lockVaultProvider.overrideWithValue(vault), pinRoundsProvider.overrideWithValue(1000)]);
      await tester.tap(find.byKey(const ValueKey('lockForgot')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('lockCode')), 'WRONG-CODE-0000');
      await tester.enterText(find.byKey(const ValueKey('lockNewPin')), '9090');
      await tester.tap(find.byKey(const ValueKey('lockReset')));
      await real(tester);
      expect(find.text('That recovery code is not right.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('lockCode')), code);
      await tester.tap(find.byKey(const ValueKey('lockReset')));
      await real(tester, 500);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recoveryCode')), findsOneWidget, reason: 'a new code, shown once');
      await tester.tap(find.byKey(const ValueKey('recoveryWritten')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lockTitle')), findsNothing);
    });

    testWidgets('Settings: set a PIN (two entries must match, the recovery code is shown), the top bar gets a Lock button, Lock now locks, Turn off needs the PIN', (tester) async {
      final c = await app(tester, location: '/settings');
      expect(find.byKey(const ValueKey('topbar-lock')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('lockSet')));
      await tester.tap(find.byKey(const ValueKey('lockSet')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '4821');
      await tester.enterText(find.byType(TextFormField).at(1), '4822');
      await tester.tap(find.text('Save'));
      await real(tester);
      await tester.pumpAndSettle();
      expect(find.text('The two PINs are different.'), findsOneWidget);
      expect(c.read(pinLockProvider).enabled, isFalse);
      await tester.ensureVisible(find.byKey(const ValueKey('lockSet')));
      await tester.tap(find.byKey(const ValueKey('lockSet')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '4821');
      await tester.enterText(find.byType(TextFormField).at(1), '4821');
      await tester.tap(find.text('Save'));
      await real(tester, 500);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recoveryCode')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recoveryWritten')));
      await tester.pumpAndSettle();
      expect(c.read(pinLockProvider).enabled, isTrue);
      expect(find.byKey(const ValueKey('topbar-lock')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('topbar-lock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lockTitle')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('lockPin')), '4821');
      await tester.tap(find.byKey(const ValueKey('lockUnlock')));
      await real(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('lockOff')));
      await tester.tap(find.byKey(const ValueKey('lockOff')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '0000');
      await tester.tap(find.text('Unlock'));
      await real(tester);
      await tester.pumpAndSettle();
      expect(c.read(pinLockProvider).enabled, isTrue, reason: 'a wrong PIN does not turn it off');
      await tester.tap(find.byKey(const ValueKey('lockOff')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '4821');
      await tester.tap(find.text('Unlock'));
      await real(tester);
      await tester.pumpAndSettle();
      expect(c.read(pinLockProvider).enabled, isFalse);
      expect(vault.read(), isNull);
    });
  });
}
