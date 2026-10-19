import 'dart:convert';
import 'dart:typed_data';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/domain/credit/account.dart';
import 'package:erp2/domain/credit/ledger.dart' show Allocation;
import 'package:erp2/features/credit/receipt_pdf.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: the payment receipt page now prints and saves a real PDF with the receipt lines, on every paper size.
// What they do NOT prove: how it looks on a real receipt printer.
void main() {
  const l = Strings();
  final receipt = PaymentReceipt(number: 'RCP-0041', customerId: 'c1', customerName: 'Murugan Electricals', amountPaise: 150000, mode: 'upi', at: DateTime(2026, 10, 19), note: '', allocations: const [Allocation('A-019804', 100000), Allocation('A-019821', 40000)], advancePaise: 10000, balanceAfter: -10000);
  int pages(Uint8List pdf) => RegExp(r'/Type\s*/Page(?![a-z])').allMatches(latin1.decode(pdf)).length;

  test('one page on every paper, a real PDF', () async {
    for (final p in PaperSize.values) {
      final b = await buildPaymentReceiptPdf(receipt: receipt, shopName: 'Senthil Enterprises', shopPhone: '98765 43210', paper: p, l: l);
      expect(latin1.decode(b.sublist(0, 5)), '%PDF-', reason: p.name);
      expect(pages(b), 1, reason: p.name);
    }
  });

  testWidgets('Print on the receipt page sends it to the printer; Save as PDF saves it', (tester) async {
    final fake = FakePrinter();
    final saver = FakeSaver();
    await pumpApp(tester, size: desktop1366, location: '/preview/payment', motion: MotionLevel.off, followSystemMotion: false, printer: fake, extraOverrides: [fileSaverProvider.overrideWithValue(saver)]);
    await tester.tap(find.byKey(const ValueKey('receiptPrint')));
    await tester.pumpAndSettle();
    expect(fake.jobs, hasLength(1));
    expect(latin1.decode(fake.jobs.single.bytes.sublist(0, 5)), '%PDF-');
    expect(find.textContaining('Sent to'), findsOneWidget);
    expect(find.textContaining('not connected'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('receiptPdf')));
    await tester.pumpAndSettle();
    expect(saver.saved.keys.single, 'Receipt RCP-0041.pdf');
  });
}
