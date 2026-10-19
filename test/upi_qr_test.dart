import 'dart:convert';
import 'dart:typed_data';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/upi.dart';
import 'package:erp2/domain_lite/bill_calc.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/features/print/bill_template.dart';
import 'package:erp2/features/print/doc_pdf.dart';
import 'package:erp2/features/print/print_layout.dart';
import 'package:erp2/features/print/print_preview.dart' show samplePrintDoc;
import 'package:erp2/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: the UPI payment link carries the right id, shop and amount; a QR code with the amount still due is on the bill
// (A4/A5 and roll paper, on screen and in the PDF) only when something is due; and the counter can show the QR full size.
// What they do NOT prove: that a phone's UPI app accepts the code (scan one printout with a real phone once).
void main() {
  const l = Strings();
  final now = DateTime(2026, 10, 13, 17, 30);
  final products = seedProducts();

  group('the UPI link', () {
    test('id, shop, amount in rupees with two decimals, note: all encoded', () {
      final u = upiPayUri(upiId: 'senthil@okbank', payeeName: 'Senthil Enterprises', amountPaise: 761950, note: 'A-020001')!;
      expect(u, 'upi://pay?pa=senthil%40okbank&pn=Senthil%20Enterprises&am=7619.50&cu=INR&tn=A-020001');
      expect(Uri.parse(u).queryParameters, {'pa': 'senthil@okbank', 'pn': 'Senthil Enterprises', 'am': '7619.50', 'cu': 'INR', 'tn': 'A-020001'});
    });

    test('whole rupees and paise are written correctly', () {
      expect(upiPayUri(upiId: 'a.b@upi', payeeName: '', amountPaise: 100000)!, contains('am=1000.00'));
      expect(upiPayUri(upiId: 'a.b@upi', payeeName: '', amountPaise: 5)!, contains('am=0.05'));
      expect(upiPayUri(upiId: 'a.b@upi', payeeName: '', amountPaise: 12345)!, isNot(contains('pn=')));
    });

    test('nothing to pay or no usable UPI id: no link', () {
      expect(upiPayUri(upiId: 'senthil@okbank', payeeName: 'S', amountPaise: 0), isNull);
      expect(upiPayUri(upiId: 'senthil@okbank', payeeName: 'S', amountPaise: -5), isNull);
      expect(upiPayUri(upiId: '', payeeName: 'S', amountPaise: 100), isNull);
      expect(upiPayUri(upiId: 'not a upi id', payeeName: 'S', amountPaise: 100), isNull);
      expect(upiPayUri(upiId: 'x&am=1@upi', payeeName: 'S', amountPaise: 100), isNull, reason: 'an id that could add fields to the link is refused');
    });

    test('the shop name and note cannot add fields or run long', () {
      final u = upiPayUri(upiId: 'ab@upi', payeeName: 'Ravi & Sons&am=1 ${'x' * 80}', amountPaise: 100, note: 'Bill #7/A?')!;
      expect(Uri.parse(u).queryParameters.keys, containsAll(['pa', 'pn', 'am', 'cu', 'tn']));
      expect(Uri.parse(u).queryParameters['am'], '1.00');
      expect(Uri.parse(u).queryParameters['pn']!.length, lessThanOrEqualTo(40));
    });
  });

  PrintDoc bill({required int receivedPaise, PayMode pay = PayMode.cash, int lines = 3}) {
    final ls = [for (var i = 0; i < lines; i++) CartLine(product: products[(i * 7) % products.length], qtyMilli: 1000)];
    return PrintDoc(mode: DocMode.invoice, number: 'A-020009', date: now, customer: 'Murugan Electricals', lines: ls, calc: calcBill(ls), pay: pay, receivedPaise: receivedPaise);
  }

  group('on the bill', () {
    test('money still due: the template carries a QR for exactly the balance', () {
      final d = bill(receivedPaise: 1000);
      final t = buildBillTemplate(doc: d, shop: ShopProfile.sample, l: l);
      expect(Uri.parse(t.upiData).queryParameters['am'], '${d.balancePaise ~/ 100}.${(d.balancePaise % 100).toString().padLeft(2, '0')}');
      expect(t.upiLabel, startsWith('Scan to pay'));
      expect(t.upiLabel, contains('₹'));
    });

    test('paid in full (even by UPI), an estimate, or a shop with no UPI id: no QR', () {
      final full = bill(receivedPaise: 99999999, pay: PayMode.upi);
      expect(buildBillTemplate(doc: full, shop: ShopProfile.sample, l: l).upiData, isEmpty, reason: 'already paid: nobody can pay twice');
      expect(buildPrintLayout(doc: full, shop: ShopProfile.sample, l: l).upiData, isEmpty);
      final est = samplePrintDoc(products, now, mode: DocMode.estimation);
      expect(buildBillTemplate(doc: est, shop: ShopProfile.sample, l: l).upiData, isEmpty);
      final noUpi = ShopProfile.sample.copyWith(upiId: '');
      expect(buildBillTemplate(doc: bill(receivedPaise: 1000), shop: noUpi, l: l).upiData, isEmpty);
    });

    test('roll paper gets the same QR', () {
      final lay = buildPrintLayout(doc: bill(receivedPaise: 1000), shop: ShopProfile.sample, l: l);
      expect(lay.upiData, startsWith('upi://pay?pa=senthil%40okbank'));
      expect(lay.upiLabel, startsWith('Scan to pay'));
    });

    test('the PDFs still make one page with the QR, on every paper', () async {
      int pages(Uint8List pdf) => RegExp(r'/Type\s*/Page(?![a-z])').allMatches(latin1.decode(pdf)).length;
      for (final p in PaperSize.values) {
        final b = await buildDocPdf(doc: bill(receivedPaise: 1000), paper: p, shop: ShopProfile.sample, size: PrintTextSize.small, l: l);
        expect(pages(b), 1, reason: p.name);
        final noQr = await buildDocPdf(doc: bill(receivedPaise: 99999999), paper: p, shop: ShopProfile.sample, size: PrintTextSize.small, l: l);
        expect(b.length, greaterThan(noQr.length - 400), reason: '${p.name}: the QR drawing is in the file');
      }
    });

    testWidgets('on screen: A4 and roll show the QR and its caption; a paid bill shows none', (tester) async {
      final c = await pumpApp(tester, size: desktop1366, location: '/print', motion: MotionLevel.off, followSystemMotion: false);
      expect(find.byKey(const ValueKey('paperUpiQr')), findsOneWidget, reason: 'the sample bill is part paid');
      expect(find.byKey(const ValueKey('paperUpi')), findsOneWidget);
      expect(find.textContaining('Scan to pay ₹ 7,619.00'), findsOneWidget);
      c.read(settingsProvider.notifier).set((s) => s.copyWith(paper: PaperSize.mm80));
      await tester.pumpAndSettle();
      await tester.tap(find.text('80 mm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paperUpiQr')), findsOneWidget);
      c.read(printDocProvider.notifier).set(bill(receivedPaise: 99999999));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paperUpiQr')), findsNothing);
    });
  });

  group('at the counter', () {
    testWidgets('UPI chosen: a QR button shows the code full size with the amount; Cash: no button', (tester) async {
      final c = await pumpApp(tester, size: desktop1366, location: '/bill', motion: MotionLevel.off, followSystemMotion: false);
      c.read(shopProvider.notifier).set((s) => s.copyWith(upiId: 'senthil@okbank'));
      final cart = c.read(cartProvider(DocMode.invoice).notifier);
      cart.add(c.read(productsProvider)[5]);
      cart.setRate(0, 15000);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('showUpiQr')), findsNothing, reason: 'cash is the default');
      cart.setPay(PayMode.upi);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('showUpiQr')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('showUpiQr')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('upiQrBig')), findsOneWidget);
      expect(find.byKey(const ValueKey('upiQrAmount')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('upiQrAmount'))).data, startsWith('₹ 1'));
    });

    testWidgets('no UPI id in Shop profile: the button says what to do instead of showing a broken code', (tester) async {
      final c = await pumpApp(tester, size: desktop1366, location: '/bill', motion: MotionLevel.off, followSystemMotion: false);
      c.read(shopProvider.notifier).set((s) => s.copyWith(upiId: ''));
      final cart = c.read(cartProvider(DocMode.invoice).notifier);
      cart.add(c.read(productsProvider)[5]);
      cart.setPay(PayMode.upi);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('showUpiQr')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('upiQrBig')), findsNothing);
      expect(find.textContaining('Add the shop UPI id'), findsOneWidget);
    });
  });
}
