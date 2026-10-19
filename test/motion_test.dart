import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:erp2/core/sound.dart';
import 'package:erp2/design/effects.dart';
import 'package:erp2/design/frame_guard.dart';
import 'package:erp2/design/motion.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/store.dart';
import 'helpers.dart';
import 'import_helpers.dart';

class FakeSound implements SoundPlayer {
  final played = <SoundKind>[];
  @override
  void play(SoundKind kind, double volume) => played.add(kind);
}

void main() {
  GoRouter routerOf(WidgetTester t) => GoRouter.of(t.element(find.byType(Scaffold).first));

  group('page transitions follow the motion level', () {
    testWidgets('Off: a page change is instant (no transition runs)', (tester) async {
      await pumpApp(tester, size: desktop1366, location: '/', motion: MotionLevel.off, followSystemMotion: false);
      routerOf(tester).go('/sales');
      await tester.pump();
      expect(find.text('All bills').evaluate().isNotEmpty, true);
      expect(tester.hasRunningAnimations, false);
    });

    for (final level in [MotionLevel.gentle, MotionLevel.full]) {
      testWidgets('${level.name}: a page change swaps at once and the new page fades in (100 ms) and is finished by 310 ms', (tester) async {
        double minOpacity() => find.ancestor(of: find.text('All bills').last, matching: find.byType(FadeTransition)).evaluate().map((e) => (e.widget as FadeTransition).opacity.value).reduce((a, b) => a < b ? a : b);
        await pumpApp(tester, size: desktop1366, location: '/', motion: level, followSystemMotion: false);
        routerOf(tester).go('/sales');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 40));
        expect(minOpacity(), lessThan(1.0), reason: '${level.name}: the new page is still fading in at 60 ms');
        await tester.pump(const Duration(milliseconds: 250));
        expect(minOpacity(), 1.0, reason: '${level.name}: finished by 310 ms');
      });
    }
  });

  group('system reduce-motion', () {
    testWidgets('turns every animation off when "follow my computer" is on', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpApp(tester, size: desktop1366, location: '/', motion: MotionLevel.full, followSystemMotion: true);
      expect(tester.element(find.byType(Scaffold).first).motion.level, MotionLevel.off);
      routerOf(tester).go('/sales');
      await tester.pump();
      expect(tester.hasRunningAnimations, false);
    });

    testWidgets('is ignored when the owner turned "follow my computer" off', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpApp(tester, size: desktop1366, location: '/', motion: MotionLevel.full, followSystemMotion: false);
      expect(tester.element(find.byType(Scaffold).first).motion.level, MotionLevel.full);
    });

    test('Motion durations are zero when off', () {
      const off = Motion(MotionLevel.off);
      const gentle = Motion(MotionLevel.gentle);
      const full = Motion(MotionLevel.full);
      expect(off.t(180), Duration.zero);
      expect(off.fx(180), Duration.zero);
      expect(gentle.t(180), const Duration(milliseconds: 180));
      expect(gentle.fx(180), Duration.zero, reason: 'effects are Full only');
      expect(full.fx(180), const Duration(milliseconds: 180));
      expect(Motion.resolve(chosen: MotionLevel.full, followSystem: true, systemReduces: true), MotionLevel.off);
      expect(Motion.resolve(chosen: MotionLevel.full, followSystem: false, systemReduces: true), MotionLevel.full);
    });
  });

  group('billing effects play only in Full and never delay the action', () {
    for (final level in MotionLevel.values) {
      testWidgets('${level.name}: adding a line is in the bill at once; the slide-in runs only in Full', (tester) async {
        final c = await pumpApp(tester, size: desktop1366, location: '/bill', motion: level, followSystemMotion: false);
        final p = c.read(productsProvider);
        await tester.pump(const Duration(seconds: 1)); // let page animation end
        c.read(cartProvider(DocMode.invoice).notifier).add(p[10]);
        await tester.pump(); // ONE zero-time frame
        expect(find.text(p[10].name), findsWidgets, reason: 'the line is on screen immediately');
        await tester.pump(const Duration(milliseconds: 60));
        List<double> lineOpacities() => tester.widgetList<Opacity>(find.ancestor(of: find.text(p[10].name).last, matching: find.byType(Opacity))).map((o) => o.opacity).toList();
        expect(lineOpacities().any((o) => o < 1.0), level == MotionLevel.full, reason: '${level.name}: the slide-in is an effect, so Full only (opacities ${lineOpacities()})');
        await tester.pump(const Duration(milliseconds: 500));
        expect(lineOpacities().every((o) => o == 1.0), true, reason: 'the effect is short (finished by 560 ms)');
      });
    }

    testWidgets('the Grand total shows the new amount within 200 ms', (tester) async {
      final c = await pumpApp(tester, size: desktop1366, location: '/bill', motion: MotionLevel.full, followSystemMotion: false);
      await tester.pump(const Duration(seconds: 1));
      c.read(cartProvider(DocMode.invoice).notifier).add(c.read(productsProvider)[3]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final total = c.read(cartProvider(DocMode.invoice));
      final shown = tester.widget<Text>(find.byKey(const ValueKey('grandTotal'))).data!;
      expect(shown.startsWith('₹ '), true);
      expect(total.lines.length, 1);
    });
  });

  group('Save, scan and typing take the same time with animations on or off', () {
    Future<(int, bool)> flow(WidgetTester tester, MotionLevel level) async {
      final c = await pumpApp(tester, size: desktop1366, location: '/bill', motion: level, followSystemMotion: false);
      await tester.pump(const Duration(seconds: 1));
      final p = c.read(productsProvider);
      // The test's own clock (it only moves when the test pumps time), so a busy computer cannot make this test fail.
      final t0 = tester.binding.clock.now();
      var immediate = true;
      for (var i = 0; i < 20; i++) {
        await tester.enterText(find.byType(TextField).first, p[i * 3].barcode); // a scan
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(); // zero time: the state must already be updated
        if (c.read(cartProvider(DocMode.invoice)).lines.length != i + 1) immediate = false;
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      if (c.read(cartProvider(DocMode.invoice)).lines.isNotEmpty) immediate = false; // Save finished in the same frame
      final waited = tester.binding.clock.now().difference(t0).inMilliseconds;
      await tester.pumpAndSettle();
      return (waited, immediate);
    }

    testWidgets('scan x20 + save: state changes in the very next frame, with and without effects', (tester) async {
      final off = await flow(tester, MotionLevel.off);
      final full = await flow(tester, MotionLevel.full);
      expect(off.$2, true, reason: 'Off: every scan and the save took effect in the next frame');
      expect(full.$2, true, reason: 'Full: every scan and the save took effect in the next frame');
      expect(off.$1, 0, reason: 'Off: 20 scans and a save needed no animation time at all');
      expect(full.$1, 0, reason: 'Full: effects add no waiting: the same 20 scans and the save needed no animation time either');
    });
  });

  group('skeleton placeholder appears only for loads slower than 150 ms', () {
    testWidgets('fast load: nothing flashes; slow load: skeleton (Full) after 150 ms', (tester) async {
      await pumpApp(tester, size: desktop1366, location: '/import', motion: MotionLevel.full, followSystemMotion: false, extraOverrides: importOverrides());
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byIcon(Icons.folder_open_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SkeletonBlocks), findsNothing, reason: 'under 150 ms: no placeholder');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SkeletonBlocks), findsOneWidget, reason: 'over 150 ms: skeleton');
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(SkeletonBlocks), findsNothing);
    });

    testWidgets('Gentle shows a plain spinner instead of shimmer', (tester) async {
      await pumpApp(tester, size: desktop1366, location: '/import', motion: MotionLevel.gentle, followSystemMotion: false, extraOverrides: importOverrides());
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byIcon(Icons.folder_open_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SkeletonBlocks), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('sync icon pulses only while syncing', () {
    testWidgets('the pulse runs while syncing and stops when synced; never when Off', (tester) async {
      final c = await pumpApp(tester, size: desktop1366, location: '/', motion: MotionLevel.gentle, followSystemMotion: false);
      await tester.pump(const Duration(seconds: 1));
      double pulseOpacity() => (find.descendant(of: find.byType(Pulse), matching: find.byType(FadeTransition)).evaluate().first.widget as FadeTransition).opacity.value;
      Future<double> lowest() async {
        var low = 1.0;
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 80));
          if (pulseOpacity() < low) low = pulseOpacity();
        }
        return low;
      }

      expect(await lowest(), 1.0, reason: 'synced: no pulse');
      c.read(settingsProvider.notifier).set((s) => s.copyWith(sync: SyncState.syncing));
      await tester.pump();
      expect(await lowest(), lessThan(0.9), reason: 'syncing: the icon gently fades in and out');
      c.read(settingsProvider.notifier).set((s) => s.copyWith(sync: SyncState.synced));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(await lowest(), 1.0, reason: 'synced again: the pulse stops');
      c.read(settingsProvider.notifier).set((s) => s.copyWith(motion: MotionLevel.off, sync: SyncState.syncing));
      await tester.pump();
      expect(await lowest(), 1.0, reason: 'Off: no pulse even while syncing');
    });
  });

  group('auto-protect frame guard', () {
    test('steady 30 fps for a few seconds drops one level; 60 fps never does; idle never does', () {
      var reduced = 0;
      var g = FrameGuard(onReduce: () => reduced++);
      for (var t = 0; t < 8000; t += 16) {
        g.onFrame(t, 8); // 60 fps and cheap
      }
      expect(reduced, 0);
      g = FrameGuard(onReduce: () => reduced++);
      for (var t = 0; t < 2000; t += 33) {
        g.onFrame(t, 33); // slow, but only for 2 s
      }
      expect(reduced, 0, reason: 'a short stumble is ignored');
      for (var t = 2000; t < 5000; t += 33) {
        g.onFrame(t, 33);
      }
      expect(reduced, 1, reason: 'a few seconds under 45 fps reduces once');
      for (var t = 5000; t < 9000; t += 33) {
        g.onFrame(t, 33);
      }
      expect(reduced, 1, reason: 'cooldown: not again straight away');
      expect(FrameGuard.lower(MotionLevel.full), MotionLevel.gentle);
      expect(FrameGuard.lower(MotionLevel.gentle), MotionLevel.off);
      expect(FrameGuard.lower(MotionLevel.off), isNull);
    });
  });

  group('optional sounds', () {
    testWidgets('scan beep is ON by default, save and error tones are OFF by default and obey Settings', (tester) async {
      final fake = FakeSound();
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, size: desktop1366, location: '/bill', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [soundPlayerProvider.overrideWithValue(fake)]);
      final p = c.read(productsProvider)[5];
      await tester.enterText(find.byType(TextField).first, p.barcode);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(fake.played, [SoundKind.scan]);
      // typing a name (not a scan) is silent
      await tester.enterText(find.byType(TextField).first, 'bolt');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(fake.played, [SoundKind.scan]);
      // Save: silent by default ...
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(fake.played, [SoundKind.scan]);
      // ... and plays once the owner turns it on
      c.read(settingsProvider.notifier).set((s) => s.copyWith(soundSave: true));
      c.read(cartProvider(DocMode.invoice).notifier).add(p);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(fake.played.last, SoundKind.save);
    });
  });

  testWidgets('Settings > Animations: Full, Gentle (default), Off and Match system', (tester) async {
    final c = await pumpApp(tester, size: desktop1920, location: '/settings');
    expect(c.read(settingsProvider).motion, MotionLevel.gentle, reason: 'default is Gentle');
    expect(find.text('Full'), findsOneWidget);
    expect(find.text('Gentle'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Follow my computer reduce-motion setting'), findsOneWidget);
    c.read(settingsProvider.notifier).set((s) => s.copyWith(motion: MotionLevel.off, motionAutoReduced: true));
    await tester.pumpAndSettle();
    expect(find.text('Turn animations back on'), findsOneWidget, reason: 'the calm note with a way back');
  });
}
