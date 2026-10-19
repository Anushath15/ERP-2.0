import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/data/repo/return_repo.dart' show SaveReturnInput;
import 'package:erp2/data/repo/records_repo.dart' show EstimateLine;
import 'package:erp2/data/repo/self_check.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/bill_math.dart';
import 'package:erp2/domain/models.dart';
import 'package:erp2/domain/credit/ledger.dart';
import 'package:erp2/domain_lite/bill_calc.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'data/helpers.dart' as dh;
import 'helpers.dart';

// A discount on the whole bill (an amount or a percent), the profit shown to the owner, and what it does to the saved bill.
void main() {
  const lineA = CalcLineIn(rate: 10000, qtyMilli: 1000, gstBp: 1800); // 100.00 with GST
  const lineB = CalcLineIn(rate: 5000, qtyMilli: 3000, gstBp: 500); // 150.00 with GST

  group('maths', () {
    test('allocateByWeight: shares add up to exactly the amount, in proportion', () {
      for (final amount in [0, 1, 7, 100, 999, 12345]) {
        final shares = allocateByWeight(amount, [10000, 15000, 333]);
        expect(shares.fold<int>(0, (a, b) => a + b), amount, reason: 'amount $amount');
      }
      expect(allocateByWeight(100, [1, 1]), [50, 50]);
      expect(allocateByWeight(5, [0, 0]), [0, 0], reason: 'nothing to share it with');
    });

    test('no discount: exactly the same figures as before the feature', () {
      final a = calcBillIn([lineA, lineB], roundOff: false);
      final b = calcBillIn([lineA, lineB], roundOff: false, extraDiscountPaise: 0, extraDiscountBp: 0);
      expect(b.grandTotal, a.grandTotal);
      expect(b.taxable, a.taxable);
      expect(b.cgst + b.sgst, a.cgst + a.sgst);
      expect(b.extraDiscount, 0);
    });

    test('an amount off the whole bill: the total goes down by exactly that, GST comes down with it, lines add up', () {
      final before = calcBillIn([lineA, lineB], roundOff: false);
      final c = calcBillIn([lineA, lineB], roundOff: false, extraDiscountPaise: 2500);
      expect(c.extraDiscount, 2500);
      expect(c.grandTotal, before.grandTotal - 2500);
      expect(c.lines.fold<int>(0, (s, x) => s + x.total), c.grandTotal);
      for (final x in c.lines) {
        expect(x.taxable + x.tax, x.total, reason: 'each line: value before tax + tax = what is paid');
      }
      expect(c.taxable + c.cgst + c.sgst, c.grandTotal);
      expect(c.taxable, lessThan(before.taxable));
      expect(c.lines.fold<int>(0, (s, x) => s + x.extraShare), 2500);
    });

    test('a percent: worked out on what the customer would pay; when both are given the percent wins', () {
      final before = calcBillIn([lineA, lineB], roundOff: false);
      final c = calcBillIn([lineA, lineB], roundOff: false, extraDiscountBp: 1000, extraDiscountPaise: 99);
      expect(c.extraDiscount, (before.grandTotal * 0.10).round());
      expect(calcBillIn([lineA], roundOff: false, extraDiscountBp: 50000).extraDiscount, 10000, reason: 'more than 100% is the whole bill, no more');
    });

    test('more than the bill is the whole bill: total zero, never negative; a negative discount is nothing', () {
      final c = calcBillIn([lineA, lineB], roundOff: false, extraDiscountPaise: 99999999);
      expect(c.grandTotal, 0);
      expect(c.lines.every((x) => x.total >= 0 && x.taxable >= 0), isTrue);
      expect(calcBillIn([lineA], roundOff: false, extraDiscountPaise: -500).extraDiscount, 0);
    });

    test('it also works when prices are kept without GST', () {
      final before = calcBillIn([lineA, lineB], roundOff: false, inclusive: false);
      final c = calcBillIn([lineA, lineB], roundOff: false, inclusive: false, extraDiscountPaise: 1000);
      expect(c.grandTotal, before.grandTotal - 1000);
      for (final x in c.lines) {
        expect(x.taxable + x.tax, x.total);
      }
    });

    test('profit: value before tax after every discount, minus what the goods cost', () {
      const p = Product(id: 'p', name: 'P', category: 'c', unit: 'pcs', pricePaise: 11800, costPaise: 6000, stockMilli: 0, gstBp: 1800, barcode: '');
      final lines = [const CartLine(product: p, qtyMilli: 2000)];
      final plain = calcBill(lines, roundOff: false);
      expect(billProfit(lines, plain), plain.taxable - 12000);
      final discounted = calcBill(lines, roundOff: false, extraDiscountPaise: 2360);
      expect(billProfit(lines, discounted), lessThan(billProfit(lines, plain)));
      expect(billProfit(lines, plain) - billProfit(lines, discounted), plain.taxable - discounted.taxable);
    });
  });

  group('saving a bill with the discount', () {
    test('stored totals add up, stock and day totals follow, the self-check is clean, the discount comes back with the bill', () async {
      final d = dh.memoryShop();
      await d.catalog.saveProduct(dh.sampleProduct('Bulb', price: 9000, cost: 6000, stock: 50000, id: 'p1', gst: 1800), create: true);
      await d.catalog.saveProduct(dh.sampleProduct('Plug', price: 5000, cost: 3000, stock: 50000, id: 'p2', gst: 1800), create: true);
      BillLineInput line(String p, int qty, int rate) => BillLineInput(productId: p, name: p, unit: 'pcs', qtyMilli: qty, ratePaise: rate, gstBp: 1800, costPaise: p == 'p1' ? 6000 : 3000);
      final s = await d.bills.saveBill(SaveBillInput(idemKey: 'k', at: DateTime(2026, 10, 17), lines: [line('p1', 4000, 9000), line('p2', 2000, 5000)], roundOff: false, extraDiscountPaise: 3000));
      // 4 x 90.00 + 2 x 50.00 = 460.00, less 30.00 = 430.00
      expect(s.totalPaise, 43000);
      final detail = (await d.bills.detail(s.id))!;
      expect(detail.extraDiscountPaise, 3000);
      expect(detail.extraDiscountBp, 0);
      expect(detail.lines.fold<int>(0, (a, x) => a + x.totalPaise), 43000, reason: 'the saved lines already carry the discount');
      expect(detail.discount, 3000, reason: 'the discount given in all');
      final day = (await d.db.rows("SELECT * FROM day_totals")).single;
      expect(day.read<int>('sales_paise'), 43000);
      expect(await selfCheck(d.db, deep: true), isEmpty);

      // a percent
      final p = await d.bills.saveBill(SaveBillInput(idemKey: 'k2', at: DateTime(2026, 10, 17), lines: [line('p1', 1000, 9000)], roundOff: false, extraDiscountBp: 1000));
      expect(p.totalPaise, 9000 - 900);
      final pd = (await d.bills.detail(p.id))!;
      expect(pd.extraDiscountBp, 1000);
      expect(pd.extraDiscountPaise, 900);

      // the same bill worked out again from its lines (a reprint) gives the same figures
      final lines = [for (final x in detail.lines) CartLine(product: Product(id: x.productId, name: x.name, category: '', unit: x.unit, pricePaise: x.ratePaise, costPaise: 0, stockMilli: 0, gstBp: x.gstBp, barcode: ''), qtyMilli: x.qtyMilli, discountBp: x.discountBp, ratePaise: x.ratePaise)];
      final again = calcBill(lines, roundOff: false, extraDiscountPaise: detail.extraDiscountPaise, extraDiscountBp: detail.extraDiscountBp);
      expect(again.grandTotal, 43000);
      expect([for (final x in again.lines) x.total], [for (final x in detail.lines) x.totalPaise]);

      // a return after the discount gives back what was really paid for the item; cancelling a bill with a discount puts everything back
      final back = await d.returns.saveReturn(SaveReturnInput(idemKey: 'r', billId: s.id, at: DateTime(2026, 10, 18), lines: {(await d.returns.returnable(s.id))!.lines.first.billLineId: 4000}, reason: 'x'));
      final firstLineTotal = detail.lines.first.totalPaise;
      expect(back.totalPaise, firstLineTotal);
      expect(await d.bills.cancelBill(p.id, reason: 'x'), isTrue);
      expect(await selfCheck(d.db, deep: true), isEmpty);
      expect(LedgerKind.returnCredit, isNotNull);
      await d.close();
    });

    test('an estimate keeps its discount: saved, listed, saved again', () async {
      final d = dh.memoryShop();
      await d.catalog.saveProduct(dh.sampleProduct('X', id: 'x'), create: true);
      final doc = await d.estimations.save(lines: const [EstimateLine(productId: 'x', name: 'X', unit: 'pcs', qtyMilli: 1000, ratePaise: 10000)], totalPaise: 9000, customerName: '', at: DateTime(2026, 10, 17), extraDiscountBp: 1000);
      expect(doc.extraDiscountBp, 1000);
      final list = await d.estimations.list();
      expect(list.single.extraDiscountBp, 1000);
      final edited = await d.estimations.save(lines: const [EstimateLine(productId: 'x', name: 'X', unit: 'pcs', qtyMilli: 1000, ratePaise: 10000)], totalPaise: 9500, customerName: '', at: DateTime(2026, 10, 17), editNumber: doc.number, extraDiscountPaise: 500);
      expect(edited.extraDiscountPaise, 500);
      expect(edited.extraDiscountBp, 0);
      await d.close();
    });
  });

  group('the bill screen', () {
    Future<ProviderContainer> app(WidgetTester t, {String loc = '/bill'}) => pumpApp(t, size: const ScreenSpec('desk', 1600, 1000), location: loc, motion: MotionLevel.off, followSystemMotion: false);

    testWidgets('amount and percent follow each other, the total goes down, the profit is shown and can be hidden', (tester) async {
      final c = await app(tester);
      final product = c.read(productsProvider).firstWhere((p) => p.pricePaise > 0 && p.costPaise > 0);
      c.read(cartProvider(DocMode.invoice).notifier).add(product, qtyMilli: 2000);
      await tester.pumpAndSettle();
      final before = calcFor(c.read(cartProvider(DocMode.invoice)), inclusive: true).grandTotal;
      expect(find.byKey(const ValueKey('profit-value')), findsOneWidget);
      // 10 percent
      await tester.enterText(find.byKey(const ValueKey('disc-percent')), '10');
      await tester.pump();
      final cart = c.read(cartProvider(DocMode.invoice));
      expect(cart.extraDiscountBp, 1000);
      expect(find.byKey(const ValueKey('disc-clear')), findsOneWidget);
      final amountText = (tester.widget<TextField>(find.byKey(const ValueKey('disc-amount'))).controller!.text);
      expect(double.parse(amountText), closeTo(before * 0.10 / 100, 0.02), reason: 'the amount field shows what 10 percent is');
      // an amount instead
      await tester.enterText(find.byKey(const ValueKey('disc-amount')), '5');
      await tester.pump();
      final cart2 = c.read(cartProvider(DocMode.invoice));
      expect(cart2.extraDiscountPaise, 500);
      expect(cart2.extraDiscountBp, 0);
      expect(calcFor(cart2, inclusive: true, roundOff: false).extraDiscount, 500);
      // profit can be hidden
      expect(find.textContaining('••••'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profit-toggle')));
      await tester.pump();
      expect(find.textContaining('••••'), findsOneWidget);
      // remove the discount
      await tester.tap(find.byKey(const ValueKey('disc-clear')));
      await tester.pump();
      expect(c.read(cartProvider(DocMode.invoice)).extraDiscountPaise, 0);
    });

    testWidgets('the printed bill shows the discount and never the profit', (tester) async {
      final c = await app(tester);
      final product = c.read(productsProvider).first;
      c.read(cartProvider(DocMode.invoice).notifier).add(product, qtyMilli: 2000);
      c.read(cartProvider(DocMode.invoice).notifier).setExtraDiscountPercent(500);
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/print');
      final cart = c.read(cartProvider(DocMode.invoice));
      final calc = calcFor(cart, inclusive: true);
      c.read(printDocProvider.notifier).set(PrintDoc(mode: DocMode.invoice, number: 'A-1', date: DateTime(2026, 10, 17), customer: 'X', lines: cart.lines, calc: calc, pay: PayMode.cash, extraDiscountBp: cart.extraDiscountBp));
      await tester.pumpAndSettle();
      expect(find.textContaining('Discount (5%)'), findsOneWidget);
      expect(find.textContaining('Profit'), findsNothing);
      expect(find.textContaining('profit'), findsNothing);
    });
  });
}
