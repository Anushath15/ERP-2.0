import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/core/device_store.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/features/billing/cart.dart';
import 'helpers.dart';

// The Shop profile page (shop details live there, not in Settings) and what Settings keeps (this device only).
void main() {
  Future<dynamic> app(WidgetTester t, String loc, {ScreenSpec size = desktop1920}) => pumpApp(t, size: size, location: loc, motion: MotionLevel.off, followSystemMotion: false);

  testWidgets('Shop profile is its own page in the sidebar with all the shop details', (tester) async {
    await app(tester, '/shop', size: const ScreenSpec('tall', 1920, 2400));
    expect(find.text('Shop profile'), findsWidgets);
    for (final t in ['Shop details', 'Shop name', 'Owner name', 'Address', 'Phone', 'GSTIN', 'UPI ID (shown in the message)', 'Bank details', 'Bill footer message', 'Invoice number prefix', 'Show on estimate']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(find.byIcon(Icons.storefront_rounded), findsWidgets, reason: 'sidebar entry');
  });

  testWidgets('editing the shop name changes the name in the header at once', (tester) async {
    final c = await app(tester, '/shop');
    await tester.enterText(find.byKey(const ValueKey('shop-name')), 'Senthil Traders');
    await tester.pump();
    expect(c.read(shopProvider).name, 'Senthil Traders');
    expect(find.text('Senthil Traders'), findsWidgets);
  });

  testWidgets('the invoice prefix is used for the next bill number', (tester) async {
    final c = await app(tester, '/shop');
    await tester.enterText(find.byKey(const ValueKey('shop-prefix')), 'S-');
    await tester.pump();
    expect(c.read(shopProvider).invoicePrefix, 'S-');
  });

  testWidgets('the estimate switches are all OFF by default and each can be turned on', (tester) async {
    final c = await app(tester, '/shop', size: const ScreenSpec('tall', 1920, 2400));
    final e = c.read(shopProvider).estimate;
    expect([e.shopName, e.address, e.gstin, e.phone, e.number, e.taxLines], everyElement(isFalse));
    for (final k in ['name', 'address', 'gstin', 'phone', 'number', 'tax']) {
      await tester.tap(find.byKey(ValueKey('est-$k')));
      await tester.pump();
    }
    final on = c.read(shopProvider).estimate;
    expect([on.shopName, on.address, on.gstin, on.phone, on.number, on.taxLines], everyElement(isTrue));
  });

  testWidgets('Settings keeps only this device\'s preferences: no shop details, tax, reminders or credit limit there', (tester) async {
    await app(tester, '/settings', size: const ScreenSpec('tall', 1920, 3000));
    for (final gone in ['Shop details', 'Shop name', 'GSTIN', 'Prices already include GST', 'Credit limit', 'Message tone']) {
      expect(find.text(gone), findsNothing, reason: '$gone moved to the Shop profile');
    }
    for (final kept in ['Text size', 'Printing']) {
      expect(find.textContaining(kept), findsWidgets, reason: kept);
    }
  });

  testWidgets('shop details are not saved as device settings (they will sync with the shop, device settings never do)', (tester) async {
    final store = MemoryDeviceStore();
    final c = await pumpApp(tester, size: desktop1366, location: '/shop', store: store, motion: MotionLevel.off, followSystemMotion: false);
    c.read(shopProvider.notifier).set((x) => x.copyWith(name: 'X'));
    c.read(settingsProvider.notifier).set((x) => x.copyWith(textScale: 1.25));
    await tester.pump();
    expect(store.data.containsKey('shopName'), isFalse);
    expect(store.data.keys.any((k) => k.toLowerCase().contains('shop') || k == 'gstin' || k == 'upiId'), isFalse);
    expect(DocMode.invoice, isNotNull);
  });
}
