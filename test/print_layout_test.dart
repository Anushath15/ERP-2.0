import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/core/date_fmt.dart';
import 'package:erp2/core/money.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/features/print/print_layout.dart';
import 'package:erp2/features/print/print_preview.dart' show samplePrintDoc;
import 'package:erp2/domain_lite/bill_calc.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/strings.dart';

// What is printed on an estimate and on a tax invoice. One layout feeds both the on-screen paper and the PDF.
const l = Strings();
final now = DateTime(2026, 10, 13, 17, 30);
final products = seedProducts();

PrintDoc estimate() => samplePrintDoc(products, now, mode: DocMode.estimation);
PrintDoc invoice() => samplePrintDoc(products, now);

String joined(PrintLayout p) => p.allText.join('\n');

void main() {
  const shop = ShopProfile();

  group('estimate printout (owner choice: nothing about the shop and no tax lines unless switched on)', () {
    test('by default it shows ONLY: ESTIMATE, customer, date, the item table and the TOTAL, with the note line', () {
      final doc = estimate();
      final t = joined(buildPrintLayout(doc: doc, shop: shop, l: l));
      expect(t, contains('ESTIMATE'));
      expect(t, contains(doc.customer));
      expect(t, contains(formatDate(doc.date)));
      for (final ln in doc.lines) {
        expect(t, contains(ln.product.name));
      }
      expect(t, contains('TOTAL'));
      expect(t, contains(formatPaise(doc.calc.grandTotal)));
      expect(t, contains(l.rcEstimateNote));
      for (final gone in [shop.name.toUpperCase(), shop.address, shop.gstin, 'GSTIN', 'Ph:', doc.number, 'Estimate no', 'Before tax', 'CGST', 'SGST', 'Round off']) {
        expect(t, isNot(contains(gone)), reason: '"$gone" is not printed on an estimate by default');
      }
    });

    test('each switch brings back exactly its own piece', () {
      final doc = estimate();
      String with_(EstimateShows e) => joined(buildPrintLayout(doc: doc, shop: shop.copyWith(estimate: e), l: l));
      expect(with_(const EstimateShows(shopName: true)), allOf(contains(shop.name.toUpperCase()), isNot(contains(shop.address)), isNot(contains('GSTIN'))));
      expect(with_(const EstimateShows(address: true)), allOf(contains(shop.address), isNot(contains(shop.name.toUpperCase()))));
      expect(with_(const EstimateShows(gstin: true)), allOf(contains('GSTIN: ${shop.gstin}'), isNot(contains('Ph:'))));
      expect(with_(const EstimateShows(phone: true)), allOf(contains('Ph: ${shop.phone}'), isNot(contains('GSTIN'))));
      expect(with_(const EstimateShows(number: true)), allOf(contains('Estimate no: ${doc.number}'), isNot(contains('CGST'))));
      final tax = with_(const EstimateShows(taxLines: true));
      for (final t in ['Before tax', 'CGST', 'SGST', 'Round off', 'TOTAL']) {
        expect(tax, contains(t));
      }
      expect(tax, isNot(contains(shop.name.toUpperCase())));
    });

    test('tax and round-off are still worked out (the TOTAL is the same) whether or not they are printed', () {
      final doc = estimate();
      final off = buildPrintLayout(doc: doc, shop: shop, l: l);
      final on = buildPrintLayout(doc: doc, shop: shop.copyWith(estimate: const EstimateShows(taxLines: true)), l: l);
      expect(off.grandTotalPaise, doc.calc.grandTotal);
      expect(on.grandTotalPaise, doc.calc.grandTotal);
      final recomputed = calcBill(doc.lines);
      expect(recomputed.grandTotal, doc.calc.grandTotal);
    });

    test('"Edited on" appears only when the estimate was edited', () {
      final edited = samplePrintDoc(products, now, mode: DocMode.estimation, edited: true);
      expect(joined(buildPrintLayout(doc: edited, shop: shop, l: l)), contains('Edited on'));
      expect(joined(buildPrintLayout(doc: estimate(), shop: shop, l: l)), isNot(contains('Edited on')));
    });
  });

  group('tax invoice printout is not changed by the estimate switches', () {
    test('shows the shop block, bill number, tax lines, total, payment lines and the footer message', () {
      final doc = invoice();
      final t = joined(buildPrintLayout(doc: doc, shop: shop, l: l));
      for (final want in [shop.name.toUpperCase(), shop.address, 'GSTIN: ${shop.gstin}', 'Ph: ${shop.phone}', 'TAX INVOICE', 'Bill no: ${doc.number}', 'Before tax', 'CGST', 'SGST', 'Round off', 'TOTAL', 'Received', shop.billFooter]) {
        expect(t, contains(want), reason: want);
      }
    });

    test('the estimate switches change nothing on a tax invoice', () {
      final doc = invoice();
      final a = joined(buildPrintLayout(doc: doc, shop: shop, l: l));
      final b = joined(buildPrintLayout(doc: doc, shop: shop.copyWith(estimate: const EstimateShows(shopName: true, address: true, gstin: true, phone: true, number: true, taxLines: true)), l: l));
      expect(a, b);
    });

    test('a bill with a balance shows Balance due and the customer\'s new balance', () {
      final doc = PrintDoc(mode: DocMode.invoice, number: 'A-1', date: now, customer: 'Test Trader', lines: invoice().lines, calc: invoice().calc, pay: PayMode.credit, receivedPaise: 1000, newBalancePaise: 99999);
      final t = joined(buildPrintLayout(doc: doc, shop: shop, l: l));
      expect(t, contains('Paid now'));
      expect(t, contains('Balance due'));
      expect(t, contains('Your balance now'));
    });
  });
}
