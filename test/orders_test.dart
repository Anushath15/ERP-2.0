import 'dart:io';
import 'package:erp2/core/reveal_file.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/core/link_launcher.dart';
import 'package:erp2/domain/orders.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: an order to a dealer is made, saved with its number, sent on WhatsApp (the PDF is saved, its folder is shown, the chat opens with the
// items in the message), and turned into a purchase whose quantities and rates can be changed; saving that purchase marks the order done.
void main() {
  test('the order message numbers the items, carries the note, and a very long list is cut with a pointer to the PDF', () {
    final lines = [for (var i = 0; i < 400; i++) OrderLine(productId: 'p$i', name: 'ITEM NUMBER $i', unit: 'pcs', qtyMilli: 1000 * (i + 1))];
    final m = orderMessage(dealerName: 'Sakthi', shopName: 'Senthil Enterprises', shopPhone: '9342363155', number: 'PO-0001', lines: lines, note: 'Deliver by Friday');
    expect(m, startsWith('Hello Sakthi,'));
    expect(m, contains('1. ITEM NUMBER 0 - 1 pcs'));
    expect(m, contains('Deliver by Friday'));
    expect(m, contains('more (see the PDF)'));
    expect(m.length, lessThan(1700), reason: 'a WhatsApp link stays short enough to open');
    final small = orderMessage(dealerName: 'Sakthi', shopName: 'Shop', shopPhone: '', number: 'PO-2', lines: [const OrderLine(productId: 'a', name: 'WIRE', unit: 'm', qtyMilli: 2500)]);
    expect(small, contains('1. WIRE - 2.5 m'));
    expect(small, isNot(contains('more (see the PDF)')));
  });

  testWidgets('make an order, send it on WhatsApp, turn it into a purchase with a changed rate: the order is done', (tester) async {
    final saver = FakeSaver();
    final launcher = FakeLauncher();
    final revealer = FakeRevealer();
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1500, 3600), location: '/orders/new', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [
      fileSaverProvider.overrideWithValue(saver),
      linkLauncherProvider.overrideWithValue(launcher),
      fileRevealerProvider.overrideWithValue(revealer),
    ]);
    Future<void> settle([int ms = 400]) async {
      await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
      await tester.pumpAndSettle();
    }

    final product = c.read(productsProvider).first;
    final dealerCount = c.read(recsProvider('dealers')).length;
    expect(dealerCount, greaterThan(0));

    // add an item, quantity 3, a note, save
    await tester.enterText(find.byKey(const ValueKey('order-picker')), product.name);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('order-option-${product.id}')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ValueKey('order-qty-${product.id}')), '3');
    await tester.enterText(find.byKey(const ValueKey('order-note')), 'Deliver by Friday');
    await tester.tap(find.byKey(const ValueKey('order-save')));
    await settle();
    final orders = c.read(recsProvider('orders'));
    expect(orders.length, 1);
    var order = OrderDoc.fromRec(orders.single);
    expect(order.number, 'PO-0001');
    expect(order.status, OrderStatus.open);
    expect((order.lines.single.productId, order.lines.single.qtyMilli), (product.id, 3000));
    expect(order.note, 'Deliver by Friday');

    // order now: the dialog, a number, go
    await tester.tap(find.byKey(const ValueKey('order-now')));
    await settle();
    expect(find.byKey(const ValueKey('wa-message')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('wa-phone')), '9876543210');
    await tester.tap(find.byKey(const ValueKey('wa-go')));
    await settle(800);
    expect(saver.saved.keys.single, startsWith('Order PO-0001'), reason: 'the PDF is saved');
    final dumpDir = Platform.environment['ASK_PDF_DIR'];
    if (dumpDir != null) {
      Directory(dumpDir).createSync(recursive: true);
      File('$dumpDir/${saver.saved.keys.single.replaceAll(' ', '_')}').writeAsBytesSync(saver.saved.values.single);
    }
    expect(String.fromCharCodes(saver.saved.values.single.take(5)), '%PDF-');
    expect(revealer.shown, isNotEmpty, reason: 'its folder is shown so the file can be dragged into WhatsApp');
    expect(launcher.opened.single, contains('919876543210'));
    expect(Uri.decodeComponent(launcher.opened.single), contains(product.name));
    order = OrderDoc.fromRec(c.read(recsProvider('orders')).single);
    expect(order.status, OrderStatus.sent);
    expect(order.sentAt, isNotNull);

    // make the purchase: the form is filled in from the order; change the rate, save
    await tester.ensureVisible(find.byKey(const ValueKey('order-make-purchase')));
    await tester.tap(find.byKey(const ValueKey('order-make-purchase')));
    await settle(800);
    final qty = tester.widget<TextField>(find.byKey(ValueKey('pur-qty-${product.id}')));
    expect(qty.controller!.text, '3', reason: 'the quantity ordered');
    await tester.enterText(find.byKey(ValueKey('pur-rate-${product.id}')), '77.00');
    await tester.ensureVisible(find.byKey(const ValueKey('pur-save')));
    await tester.tap(find.byKey(const ValueKey('pur-save')));
    await settle(900);
    expect(tester.takeException(), isNull);
    final purchases = (await tester.runAsync(() => c.read(appDataProvider).purchases.list()))!;
    expect(purchases.length, 1);
    final det = (await tester.runAsync(() => c.read(appDataProvider).purchases.detail(purchases.single.id)))!;
    expect(det.lines.single.ratePaise, 7700, reason: 'the changed rate was kept');
    order = OrderDoc.fromRec(c.read(recsProvider('orders')).single);
    expect(order.status, OrderStatus.converted);
    expect(order.purchaseNo, purchases.single.number);
  });
}
