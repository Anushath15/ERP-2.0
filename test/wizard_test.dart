import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/data/repo/series_registry.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/features/auth/auth_screens.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'helpers.dart';

// The first-run set-up: shop details, the number prefix and this computer's letter (never one that another computer already has).
void main() {
  Future<void> next(WidgetTester t) async {
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
  }

  testWidgets('every step checks what was typed; finishing saves the shop and gives this computer its letter', (t) async {
    final c = await pumpApp(t, size: desktop1366, location: '/wizard', motion: MotionLevel.off, followSystemMotion: false);
    await next(t); // welcome
    await t.enterText(find.byKey(const ValueKey('wizName')), '');
    await next(t);
    expect(find.text('Please type the name of your shop.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('wizName')), 'Kovai Hardware');
    await t.enterText(find.byKey(const ValueKey('wizOwner')), 'S. Kumar');
    await t.enterText(find.byKey(const ValueKey('wizAddress')), '5 Bazaar Road, Coimbatore');
    await t.enterText(find.byKey(const ValueKey('wizPhone')), '9876543210');
    await next(t);
    await t.enterText(find.byKey(const ValueKey('wizGstin')), '33ABC');
    await next(t);
    expect(find.textContaining('15 letters and digits'), findsWidgets);
    await t.enterText(find.byKey(const ValueKey('wizGstin')), '33AAAAA0000A1Z5');
    await next(t);
    // numbering: a letter is required
    await next(t);
    expect(find.text('Please choose a letter for this computer.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('wizPrefix')), 'KH-');
    await t.tap(find.byKey(const ValueKey('series-B')));
    await t.pump();
    expect(find.text('Your first bill will be KH-B-000001'), findsOneWidget);
    await next(t);
    await next(t); // logo
    await next(t); // printer
    await t.tap(find.byKey(const ValueKey('wizFinish')));
    await t.pumpAndSettle();
    final d = c.read(appDataProvider);
    final shop = c.read(shopProvider);
    expect(shop.name, 'Kovai Hardware');
    expect(shop.ownerName, 'S. Kumar');
    expect(shop.invoicePrefix, 'KH-');
    expect(shop.gstin, '33AAAAA0000A1Z5');
    expect(await SeriesRegistry(d.settings, d.cx.deviceId).mine(), 'B');
    expect(await d.settings.get('shop.created'), isNotNull);
    expect(d.bills.series, 'B');
    expect(await d.bills.peekNextNumber(), 'KH-B-000001', reason: 'series B starts at its own 1, whatever series A has reached');
  });

  testWidgets('a letter another computer already uses cannot be chosen', (t) async {
    final c = await pumpApp(t, size: desktop1366, location: '/wizard', motion: MotionLevel.off, followSystemMotion: false);
    final d = c.read(appDataProvider);
    await SeriesRegistry(d.settings, 'another-computer').claim('A');
    c.invalidate(freeSeriesProvider);
    for (var i = 0; i < 3; i++) {
      await next(t);
    }
    await t.tap(find.byKey(const ValueKey('series-A')), warnIfMissed: false);
    await t.pump();
    expect(tester(t, 'series-A').onSelected, isNull, reason: 'greyed out');
    expect(tester(t, 'series-C').onSelected, isNotNull);
  });
}

ChoiceChip tester(WidgetTester t, String key) => t.widget<ChoiceChip>(find.byKey(ValueKey(key)));
