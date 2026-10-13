import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/app.dart';
import 'package:erp2/core/device_store.dart';
import 'package:erp2/core/link_launcher.dart';
import 'package:erp2/domain/credit/reminder.dart' show LinkPlatform;
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/store.dart';

final fixedNow = DateTime(2026, 10, 13, 17, 30);

class ScreenSpec {
  const ScreenSpec(this.name, this.w, this.h);
  final String name;
  final double w, h;
}

const desktop1920 = ScreenSpec('desktop-1920x1080', 1920, 1080);
const desktop1366 = ScreenSpec('desktop-1366x768', 1366, 768);
const desktop1280 = ScreenSpec('desktop-1280x720', 1280, 720);
const tabletPortrait = ScreenSpec('tablet-820x1180', 820, 1180);
const tabletLandscape = ScreenSpec('tablet-1024x768', 1024, 768);
const phone390 = ScreenSpec('phone-390x844', 390, 844);
const phone360 = ScreenSpec('phone-360x640', 360, 640);

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required ScreenSpec size,
  String location = '/',
  ThemeMode theme = ThemeMode.dark,
  double? textScale,
  DeviceStore? store,
  MotionLevel? motion,
  bool? followSystemMotion,
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = Size(size.w, size.h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [clockProvider.overrideWithValue(fixedNow), deviceStoreProvider.overrideWithValue(store ?? MemoryDeviceStore()), ...extraOverrides],
    child: ErpApp(initialLocation: location),
  ));
  final container = ProviderScope.containerOf(tester.element(find.byType(ErpApp)));
  container.read(settingsProvider.notifier).set((s) => s.copyWith(theme: theme, textScale: textScale ?? s.textScale, motion: motion ?? s.motion, followSystemMotion: followSystemMotion ?? s.followSystemMotion));
  await tester.pumpAndSettle();
  return container;
}

/// A stand-in for opening links: records what would be opened, never opens anything.
class FakeLauncher implements LinkLauncher {
  FakeLauncher({this.platform = LinkPlatform.windows, this.ok = true, this.appInstalled = true});
  @override
  final LinkPlatform platform;
  bool ok, appInstalled;
  final opened = <String>[];
  @override
  Future<bool> open(String url) async {
    if (url.startsWith('whatsapp:') && !appInstalled) return false;
    if (!ok) return false;
    opened.add(url);
    return true;
  }
}
