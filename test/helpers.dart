import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/app.dart';
import 'package:erp2/fake/store.dart';

final fixedNow = DateTime(2026, 10, 13, 17, 30);

class Viewport {
  const Viewport(this.name, this.w, this.h);
  final String name;
  final double w, h;
}

const desktop1920 = Viewport('desktop-1920x1080', 1920, 1080);
const desktop1366 = Viewport('desktop-1366x768', 1366, 768);
const desktop1280 = Viewport('desktop-1280x720', 1280, 720);
const tabletPortrait = Viewport('tablet-820x1180', 820, 1180);
const tabletLandscape = Viewport('tablet-1024x768', 1024, 768);
const phone390 = Viewport('phone-390x844', 390, 844);
const phone360 = Viewport('phone-360x640', 360, 640);

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required Viewport size,
  String location = '/',
  ThemeMode theme = ThemeMode.dark,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(size.w, size.h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [clockProvider.overrideWithValue(fixedNow)],
    child: ErpApp(initialLocation: location),
  ));
  final container = ProviderScope.containerOf(tester.element(find.byType(ErpApp)));
  container.read(settingsProvider.notifier).set((s) => s.copyWith(theme: theme, textScale: textScale));
  await tester.pumpAndSettle();
  return container;
}
