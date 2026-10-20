import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/bank.dart';
import 'package:erp2/features/billing/cart.dart' show DocMode;
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/features/print/bill_template.dart';
import 'package:erp2/features/print/print_preview.dart' show samplePrintDoc;
import 'package:erp2/demo/seed.dart';
import 'package:erp2/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: the bank details are three separate fields (bank name, account number, IFSC code) that are checked, saved, and printed
// on the invoice; the old single text is split into them once, without losing anything.
void main() {
  group('splitting the old single text', () {
    test('the way it was typed in the shop: name, account, IFSC separated by commas', () {
      final b = parseBankDetails('State Bank Of India, 44131804620,SBIN0003780');
      expect((b.name, b.account, b.ifsc), ('State Bank Of India', '44131804620', 'SBIN0003780'));
    });

    test('with labels, in any order, in capitals or small letters, with spaces in the number', () {
      var b = parseBankDetails('Sample Bank, A/c 0000000000, IFSC SAMP0000000');
      expect((b.name, b.account, b.ifsc), ('Sample Bank', '0000000000', 'SAMP0000000'));
      b = parseBankDetails('IFSC: sbin0003780\nAccount No. 4413 1804 620\nSBI Nagercoil');
      expect((b.name, b.account, b.ifsc), ('SBI Nagercoil', '44131804620', 'SBIN0003780'));
    });

    test('missing pieces stay empty; nothing typed gives nothing; text that fits nowhere stays in the name', () {
      expect(parseBankDetails('Indian Bank').name, 'Indian Bank');
      expect(parseBankDetails('').name, '');
      final b = parseBankDetails('Federal Bank, 12345');
      expect((b.name, b.account, b.ifsc), ('Federal Bank, 12345', '', ''), reason: '5 digits is not an account number');
    });

    test('IFSC and account shapes', () {
      expect(validIfsc('SBIN0003780'), isTrue);
      expect(validIfsc('sbin0003780'), isTrue);
      expect(validIfsc('SBIN1003780'), isFalse, reason: 'the 5th character is always zero');
      expect(validIfsc('SBIN000378'), isFalse);
      expect(validAccount('44131804620'), isTrue);
      expect(validAccount('12345'), isFalse);
      expect(validAccount('4413 1804 620'), isFalse);
      expect(validAccount('1234567890123456789'), isFalse);
    });
  });

  group('the shop profile', () {
    test('saved pieces come back as they were; the old text key is split once and then not used', () {
      const p = ShopProfile(bankName: 'State Bank Of India', bankHolder: 'Senthil Enterprises', bankAccount: '44131804620', bankIfsc: 'SBIN0003780');
      final j = p.toJson();
      expect(j.containsKey('bankDetails'), isFalse);
      final back = ShopProfile.fromJson(j);
      expect((back.bankName, back.bankHolder, back.bankAccount, back.bankIfsc), ('State Bank Of India', 'Senthil Enterprises', '44131804620', 'SBIN0003780'));
      final old = ShopProfile.fromJson({'name': 'X', 'bankDetails': 'State Bank Of India, 44131804620,SBIN0003780'});
      expect((old.bankName, old.bankAccount, old.bankIfsc), ('State Bank Of India', '44131804620', 'SBIN0003780'));
      final edited = ShopProfile.fromJson({'bankDetails': 'Old Bank, 111111111, OLDB0000001', 'bankName': 'New Bank', 'bankAccount': '', 'bankIfsc': ''});
      expect((edited.bankName, edited.bankAccount, edited.bankIfsc), ('New Bank', '', ''), reason: 'once the pieces exist the old text is ignored');
    });
  });

  group('on the invoice', () {
    const l = Strings();
    final now = DateTime(2026, 10, 13, 17, 30);
    final products = seedProducts();

    test('A/c and IFSC come from the fields (capital letters), under the GST number; an empty field prints nothing', () {
      final doc = samplePrintDoc(products, now);
      final full = buildBillTemplate(doc: doc, shop: ShopProfile.sample.copyWith(bankAccount: '44131804620', bankIfsc: 'sbin0003780'), l: l);
      expect(full.shopRight, containsAll(['A/c 44131804620', 'IFSC SBIN0003780']));
      expect(full.shopRight.first, startsWith('GST'));
      final none = buildBillTemplate(doc: doc, shop: ShopProfile.sample.copyWith(bankAccount: '', bankIfsc: ''), l: l);
      expect(none.shopRight.where((x) => x.startsWith('A/c') || x.startsWith('IFSC')), isEmpty);
    });
  });

  testWidgets('Shop profile has separate Bank name, Account number and IFSC fields; a wrong IFSC or account number is flagged', (tester) async {
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 2600), location: '/shop', motion: MotionLevel.off, followSystemMotion: false);
    for (final k in ['shop-bankName', 'shop-bankHolder', 'shop-bankAccount', 'shop-bankIfsc']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    expect(find.byKey(const ValueKey('shop-bank')), findsNothing, reason: 'the single text box is gone');
    await tester.ensureVisible(find.byKey(const ValueKey('shop-bankIfsc')));
    await tester.enterText(find.byKey(const ValueKey('shop-bankIfsc')), 'sbin0003');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bankIfscWarn')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('shop-bankIfsc')), 'sbin0003780');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bankIfscWarn')), findsNothing);
    expect(c.read(shopProvider).bankIfsc, 'SBIN0003780', reason: 'kept in capitals');
    await tester.enterText(find.byKey(const ValueKey('shop-bankAccount')), '12 34');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bankAccountWarn')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('shop-bankAccount')), '44131804620');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bankAccountWarn')), findsNothing);
    expect(c.read(shopProvider).bankAccount, '44131804620');
  });

  group('the estimate shows the rate WITH GST, so rate x quantity is the amount the customer sees', () {
    const l = Strings();
    final now = DateTime(2026, 10, 20, 12);
    final products = seedProducts();

    // (the bill maths always takes the entered price as the price with GST, as the shop sets it)
    for (final inclusive in [true]) {
      test('${inclusive ? 'prices entered with GST' : 'prices entered without GST'}: every estimate row has rate x quantity = total; the invoice keeps the rate without GST', () {
        final doc = samplePrintDoc(products, now, mode: DocMode.estimation);
        final shop = ShopProfile.sample.copyWith(pricesIncludeGst: inclusive);
        final t = buildBillTemplate(doc: doc, shop: shop, l: l);
        expect(t.rows, isNotEmpty);
        for (final r in t.rows) {
          final rate = double.parse(r.rate), qty = double.parse(r.qty), total = double.parse(r.total.replaceAll(',', ''));
          expect(rate.toStringAsFixed(2), r.rate, reason: 'two decimals, no 139.822');
          expect(rate * qty, closeTo(total, 0.06 * qty), reason: '${r.goods}: ${r.rate} x ${r.qty} should be ${r.total}');
        }
        final inv = buildBillTemplate(doc: samplePrintDoc(products, now), shop: shop, l: l);
        expect(inv.rows.any((r) => r.rate.split('.').last.length == 3), isTrue, reason: 'the tax invoice still shows the rate without GST (three decimals)');
      });
    }
  });
}
