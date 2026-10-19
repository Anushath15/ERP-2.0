// Generates a screenshot of EVERY screen (phone, tablet, desktop x dark/light) into docs/ui-review/
// plus an index.md, so the owner can review without running the app.
// Run:  UI_REVIEW=1 flutter test test/ui_review/generate_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:erp2/app.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/fake/credit_store.dart' show seedCredit;
import 'package:erp2/fake/models.dart' show PayMode;
import 'package:erp2/demo/seed.dart';
import 'package:erp2/design/segments.dart';
import '../helpers.dart';

class Shot {
  const Shot(this.id, this.title, this.route, {this.setup, this.phoneOnly = false});
  final String id, title, route;
  final Future<void> Function(WidgetTester t, ProviderContainer c)? setup;
  final bool phoneOnly;
}

final _credit = seedCredit(seedCustomers(), fixedNow);
final dealerId = seedDealers().firstWhere((d) => d.i('balance') > 0).id;
final dueId = _credit.entries.firstWhere((e) => e.value.balance > 0 && e.value.bills.length > 1).key;

/// Taps something that may be far down a long page: scrolls until it is built, then taps it.
Future<void> tapScrolled(WidgetTester t, Finder f) async {
  for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
    await t.dragFrom(Offset(t.view.physicalSize.width / 2, t.view.physicalSize.height * 0.6), const Offset(0, -300));
    await t.pumpAndSettle();
  }
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await t.pumpAndSettle();
}

Future<void> tapKey(WidgetTester t, String k) => tapScrolled(t, find.byKey(ValueKey(k)));

Future<void> fill(WidgetTester t, ProviderContainer c, DocMode mode) async {
  final products = c.read(productsProvider);
  final n = c.read(cartProvider(mode).notifier);
  for (var i = 0; i < 7; i++) {
    n.add(products[i * 11 + 4]);
  }
  n.add(products.firstWhere((p) => p.outOfStock));
  await t.pumpAndSettle();
}

Future<void> fill_(WidgetTester t, ProviderContainer c, DocMode mode) => fill(t, c, mode);

Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = last ? find.text(text).last : find.text(text).first;
  await t.tap(f);
  await t.pumpAndSettle();
}

final shots = <Shot>[
  const Shot('signin', 'Sign in', '/signin'),
  const Shot('forgot-password', 'Forgot password', '/forgot'),
  const Shot('first-run-wizard', 'First-run wizard', '/wizard'),
  const Shot('dashboard', 'Dashboard (Home)', '/'),
  Shot('billing', 'POS billing (bill with 8 lines, one out of stock)', '/bill', setup: (t, c) => fill(t, c, DocMode.invoice)),
  Shot('estimate', 'New estimate', '/estimate', setup: (t, c) => fill(t, c, DocMode.estimation)),
  const Shot('saved-estimates', 'Saved estimates', '/estimates'),
  const Shot('sales-register', 'Sales register (20,000 bills)', '/sales'),
  const Shot('sales-returns', 'Sales returns', '/sales-returns'),
  const Shot('delivery', 'Delivery', '/delivery'),
  const Shot('products', 'Products (757)', '/products'),
  const Shot('categories', 'Categories', '/categories'),
  const Shot('inventory', 'Stock left (Inventory)', '/inventory'),
  const Shot('purchases', 'Purchases', '/purchases'),
  const Shot('purchase-returns', 'Purchase returns', '/purchase-returns'),
  const Shot('stock-changes', 'Stock changes (adjustments)', '/adjustments'),
  const Shot('customers', 'Customers (5,000)', '/customers'),
  const Shot('dealers', 'Dealers', '/dealers'),
  const Shot('credit', 'Money to collect (credit and dues)', '/credit'),
  const Shot('staff', 'Staff', '/staff'),
  const Shot('expenses', 'Expenses', '/expenses'),
  const Shot('daily-closing', 'Daily closing', '/closing'),
  const Shot('reports', 'Reports and analytics', '/reports'),
  const Shot('export', 'Export center', '/export'),
  const Shot('import', 'Import old data (ERP 1.0)', '/import'),
  const Shot('warranty', 'Warranty', '/warranty'),
  const Shot('notifications', 'Notifications', '/notifications'),
  const Shot('settings', 'Settings', '/settings'),
  const Shot('database-health', 'Database health', '/health'),
  const Shot('help', 'Help', '/help'),
  const Shot('about', 'About', '/about'),
  const Shot('more-menu', 'More (phone menu)', '/more', phoneOnly: true),
  const Shot('print-a4', 'Print preview: A4 invoice', '/preview/a4'),
  const Shot('print-80mm', 'Print preview: 80 mm receipt', '/preview/80'),
  const Shot('print-58mm', 'Print preview: 58 mm receipt', '/preview/58'),
  const Shot('print-estimate', 'Print preview: estimate (with its own date)', '/preview/estimate'),
  // dialogs and sheets
  Shot('dlg-quick-add-product', 'Dialog: add a product from the bill (bill stays untouched)', '/bill', setup: (t, c) async {
    await fill(t, c, DocMode.invoice);
    await t.tap(find.byIcon(Icons.add).first);
    await t.pumpAndSettle();
  }),
  Shot('dlg-no-product-found', 'Product search with no match: + Add row', '/bill', setup: (t, c) async {
    await t.enterText(find.byType(TextField).first, 'pvc 3 inch nipple');
    await t.pumpAndSettle();
  }),
  Shot('dlg-choose-customer', 'Dialog: choose customer (5,000, searchable)', '/bill', setup: (t, c) async {
    await fill(t, c, DocMode.invoice);
    final seg = find.byType(SlideSegments<int>);
    if (seg.evaluate().isNotEmpty) {
      await t.tap(find.descendant(of: seg, matching: find.byIcon(Icons.receipt_long_outlined)));
      await t.pumpAndSettle();
    }
    await t.tap(find.byIcon(Icons.person_outline).first);
    await t.pumpAndSettle();
  }),
  Shot('dlg-bill-detail', 'Bill details with Print again / Return / Cancel (owner only)', '/sales', setup: (t, c) async {
    await t.tap(find.textContaining('A-020000').first);
    await t.pumpAndSettle();
  }),
  Shot('dlg-estimate-actions', 'Saved estimate: View, Edit, Copy, Make into bill, Delete with reason', '/estimates', setup: (t, c) async {
    await t.tap(find.textContaining('EST-00300').first);
    await t.pumpAndSettle();
  }),
  const Shot('dlg-add-product-form', 'Form: add product (Ctrl+Shift+N)', '/products?add=1'),
  Shot('pos-part-paid', 'POS: part payment, balance goes to the customer', '/bill', setup: (t, c) async {
    await fill(t, c, DocMode.invoice);
    c.read(cartProvider(DocMode.invoice).notifier)
      ..setCustomer(c.read(customersProvider).first)
      ..setReceived(100000);
    await t.pumpAndSettle();
  }),
  Shot('pos-walkin-balance', 'POS: walk-in with a balance must pick a customer', '/bill', setup: (t, c) async {
    await fill(t, c, DocMode.invoice);
    c.read(cartProvider(DocMode.invoice).notifier).setReceived(100000);
    await t.pumpAndSettle();
  }),
  Shot('pos-overpaid', 'POS: overpaid, change or keep as advance', '/bill', setup: (t, c) async {
    await fill(t, c, DocMode.invoice);
    c.read(cartProvider(DocMode.invoice).notifier)
      ..setCustomer(c.read(customersProvider).first)
      ..setReceived(5000000);
    await t.pumpAndSettle();
  }),
  Shot('pos-credit-mode', 'POS: Credit with Paid now, Half, Full', '/bill', setup: (t, c) async {
    await fill(t, c, DocMode.invoice);
    c.read(cartProvider(DocMode.invoice).notifier)
      ..setCustomer(c.read(customersProvider).first)
      ..setPay(PayMode.credit)
      ..setReceived(100000);
    await t.pumpAndSettle();
  }),
  Shot('dlg-credit-walkin', 'Dialog: who is this credit for? (walk-in on credit)', '/bill', setup: (t, c) async {
    await fill(t, c, DocMode.invoice);
    c.read(cartProvider(DocMode.invoice).notifier).setPay(PayMode.credit);
    await t.pumpAndSettle();
    await t.tap(find.text('Save bill').first);
    await t.pumpAndSettle();
  }),
  Shot('dealer-profile', 'Dealer profile: what we owe, dates, ledger, Pay dealer', '/dealers/$dealerId'),
  Shot('dlg-settle-fully', 'Dialog: Settle fully (how paid, note)', '/customers/$dueId', setup: (t, c) async {
    await tapKey(t, 'settleFully');
  }),
  Shot('dlg-add-credit-customer', 'Dialog: add a credit customer (amount owed and start date)', '/credit', setup: (t, c) async {
    await t.tap(find.text('Add credit customer').first);
    await t.pumpAndSettle();
  }),
  const Shot('shop-profile', 'Shop profile: details, estimate switches, tax, messages, credit', '/shop'),
  const Shot('print-a5', 'Print: A5 invoice', '/preview/a5'),
  Shot('customer-detail', 'Customer: balance, ageing, bills, ledger, reminders', '/customers/$dueId'),
  Shot('customer-statement', 'Customer statement (print and PDF)', '/customers/$dueId/statement'),
  const Shot('receipt-payment', 'Payment receipt preview', '/preview/payment'),
  Shot('dlg-receive-payment', 'Dialog: receive payment (oldest bills first, or choose)', '/customers/$dueId', setup: (t, c) => tapKey(t, 'receiveOrPay')),
  Shot('dlg-reminder', 'Dialog: WhatsApp reminder preview (editable)', '/customers/$dueId', setup: (t, c) => tapScrolled(t, find.text('Remind on WhatsApp'))),
  Shot('dlg-reminder-offline', 'Dialog: reminder while offline (Copy message)', '/customers/$dueId', setup: (t, c) async {
    c.read(settingsProvider.notifier).set((x) => x.copyWith(sync: SyncState.offline));
    await t.pumpAndSettle();
    await tapScrolled(t, find.text('Remind on WhatsApp'));
  }),
  Shot('settings-reminders', 'Shop profile > Messages to customers (template, tone, guard)', '/shop', setup: (t, c) async {
    final k = find.byKey(const ValueKey('templateField'));
    for (var i = 0; i < 40 && k.evaluate().isEmpty; i++) {
      await t.dragFrom(Offset(t.view.physicalSize.width / 2, t.view.physicalSize.height * 0.6), const Offset(0, -300));
      await t.pumpAndSettle();
    }
    await t.ensureVisible(k.first);
    await t.pumpAndSettle();
  }),
];

class Combo {
  const Combo(this.size, this.w, this.h);
  final String size;
  final double w, h;
}

const combos = [Combo('phone', 390, 844), Combo('tablet', 820, 1180), Combo('desktop', 1440, 900)];

void main() {
  final run = Platform.environment['UI_REVIEW'] == '1';
  final outRoot = Directory('docs/ui-review');
  final written = <String, bool>{};

  for (final combo in combos) {
    for (final theme in ['dark', 'light']) {
      {
        testWidgets('screenshots ${combo.size} $theme', skip: !run, timeout: const Timeout(Duration(minutes: 20)), (tester) async {
          final dir = Directory('${outRoot.path}/${combo.size}/$theme')..createSync(recursive: true);
          for (final s in shots) {
            if (s.phoneOnly && combo.size != 'phone') continue;
            final key = GlobalKey();
            await tester.pumpWidget(const SizedBox.shrink());
            tester.view.physicalSize = Size(combo.w, combo.h);
            tester.view.devicePixelRatio = 1.0;
            await tester.pumpWidget(ProviderScope(
              key: UniqueKey(),
              overrides: [clockProvider.overrideWithValue(fixedNow)],
              child: RepaintBoundary(key: key, child: ErpApp(initialLocation: s.route)),
            ));
            final c = ProviderScope.containerOf(tester.element(find.byType(ErpApp)));
            c.read(settingsProvider.notifier).set((x) => x.copyWith(theme: theme == 'dark' ? ThemeMode.dark : ThemeMode.light));
            await tester.pumpAndSettle();
            if (s.setup != null) {
              try {
                await s.setup!(tester, c);
              } catch (e) {
                // a missing tap target must not stop the whole run; the shot is still taken
                stdout.writeln('setup issue in ${s.id} (${combo.size}): $e');
              }
            }
            final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
            late Uint8List png;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1.0);
              final data = await image.toByteData(format: ui.ImageByteFormat.png);
              png = data!.buffer.asUint8List();
              image.dispose();
            });
            final decoded = img.decodePng(png)!;
            File('${dir.path}/${s.id}.jpg').writeAsBytesSync(img.encodeJpg(decoded, quality: 72));
            written['${combo.size}/$theme/${s.id}'] = true;
            expect(tester.takeException(), isNull, reason: '${s.id} ${combo.size} $theme');
          }
        });
      }
    }
  }

  // POS, Estimations, Products and Settings at 100%, 150% and 200% text size
  for (final combo in [combos[0], combos[2]]) {
    for (final theme in ['dark', 'light']) {
      testWidgets('text-size screenshots ${combo.size} $theme', skip: !run, timeout: const Timeout(Duration(minutes: 20)), (tester) async {
        final dir = Directory('${outRoot.path}/text-sizes/${combo.size}/$theme')..createSync(recursive: true);
        for (final scale in [1.0, 1.5, 2.0]) {
          for (final (id, route, fill) in [('pos', '/bill', true), ('estimations', '/estimate', true), ('saved-estimates', '/estimates', false), ('products', '/products', false), ('settings', '/settings', false)]) {
            final key = GlobalKey();
            await tester.pumpWidget(const SizedBox.shrink());
            tester.view.physicalSize = Size(combo.w, combo.h);
            tester.view.devicePixelRatio = 1.0;
            await tester.pumpWidget(ProviderScope(
              key: UniqueKey(),
              overrides: [clockProvider.overrideWithValue(fixedNow)],
              child: RepaintBoundary(key: key, child: ErpApp(initialLocation: route)),
            ));
            final c = ProviderScope.containerOf(tester.element(find.byType(ErpApp)));
            c.read(settingsProvider.notifier).set((x) => x.copyWith(theme: theme == 'dark' ? ThemeMode.dark : ThemeMode.light, textScale: scale));
            await tester.pumpAndSettle();
            if (fill) await fill_(tester, c, route == '/bill' ? DocMode.invoice : DocMode.estimation);
            final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
            late Uint8List png;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1.0);
              final data = await image.toByteData(format: ui.ImageByteFormat.png);
              png = data!.buffer.asUint8List();
              image.dispose();
            });
            File('${dir.path}/${id}_${(scale * 100).round()}.jpg').writeAsBytesSync(img.encodeJpg(img.decodePng(png)!, quality: 72));
            expect(tester.takeException(), isNull, reason: '$id ${combo.size} $theme ${(scale * 100).round()}%');
          }
        }
      });
    }
  }

  test('write index.md', skip: !run, () {
    final b = StringBuffer()
      ..writeln('# UI review screenshots')
      ..writeln()
      ..writeln('Every screen of the Phase 1 prototype (sample data only) at three widths: **phone** (390 px), **tablet** (820 px) and **desktop** (1440 px), in dark and light colours. Open a picture to see it full size.')
      ..writeln()
      ..writeln('Folder layout: `docs/ui-review/<phone|tablet|desktop>/<dark|light>/<screen>.jpg`')
      ..writeln()
      ..writeln('| Screen | Desktop dark EN | Desktop light EN | Tablet dark EN | Phone dark EN | Phone light EN |')
      ..writeln('|---|---|---|---|---|---|');
    for (final s in shots) {
      String link(String size, String mode) => s.phoneOnly && size != 'phone' ? '-' : '[$size ${mode.toUpperCase().replaceAll('-', ' ')}]($size/$mode/${s.id}.jpg)';
      b.writeln('| ${s.title} | ${link('desktop', 'dark')} | ${link('desktop', 'light')} | ${link('tablet', 'dark')} | ${link('phone', 'dark')} | ${link('phone', 'light')} |');
    }
    b
      ..writeln()
      ..writeln('## Text size 100% / 150% / 200%')
      ..writeln()
      ..writeln('POS billing, estimates, saved estimates, products and settings at three text sizes (desktop and phone, dark and light): folder `text-sizes/<desktop|phone>/<dark|light>/`, files `<screen>_<100|150|200>.jpg`.')
      ..writeln()
      ..writeln('| Screen | Desktop dark 100% | Desktop dark 150% | Desktop dark 200% | Phone dark 100% | Phone dark 200% |')
      ..writeln('|---|---|---|---|---|---|');
    for (final id in ['pos', 'estimations', 'saved-estimates', 'products', 'settings']) {
      b.writeln('| $id | [100%](text-sizes/desktop/dark/${id}_100.jpg) | [150%](text-sizes/desktop/dark/${id}_150.jpg) | [200%](text-sizes/desktop/dark/${id}_200.jpg) | [100%](text-sizes/phone/dark/${id}_100.jpg) | [200%](text-sizes/phone/dark/${id}_200.jpg) |');
    }
    b
      ..writeln()
      ..writeln('All 6 combinations (3 widths x 2 colours) exist for every screen, in the same folders.')
      ..writeln()
      ..writeln('## Previews')
      ..writeln();
    for (final s in shots.where((s) => !s.phoneOnly)) {
      b
        ..writeln('### ${s.title}')
        ..writeln()
        ..writeln('<img src="desktop/dark/${s.id}.jpg" width="520"> <img src="phone/dark/${s.id}.jpg" width="170">')
        ..writeln();
    }
    File('${outRoot.path}/index-full.md').writeAsStringSync(b.toString());
  });
}

