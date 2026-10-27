import 'package:erp2/core/file_saver.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/core/link_launcher.dart';
import 'package:erp2/core/reveal_file.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/features/print/doc_share.dart';
import 'package:erp2/features/print/print_preview.dart' show samplePrintDoc;
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// What these tests prove: a saved BILL's box and an ESTIMATE's box each have Download PDF and Send on WhatsApp. Download saves a real PDF named after the
// document (Bill A-... / Estimate EST-...), on A4 even when the shop prints on a roll. WhatsApp saves the same PDF, puts it on the clipboard, and opens the chat
// with a message that names the document and its amount.
void main() {
  Future<({FakeSaver saver, FakeLauncher launcher, FakeRevealer revealer})> open(WidgetTester tester, String location) async {
    final saver = FakeSaver(), launcher = FakeLauncher(), revealer = FakeRevealer();
    await pumpApp(tester, size: const ScreenSpec('wide', 1600, 1400), location: location, motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [
      fileSaverProvider.overrideWithValue(saver),
      linkLauncherProvider.overrideWithValue(launcher),
      fileRevealerProvider.overrideWithValue(revealer),
    ]);
    return (saver: saver, launcher: launcher, revealer: revealer);
  }

  Future<void> sendOnWhatsapp(WidgetTester tester) async {
    await tester.enterText(find.byKey(const ValueKey('wa-phone')), '9876543210');
    await tester.tap(find.byKey(const ValueKey('wa-go')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wa-close')));
    await tester.pumpAndSettle();
  }

  testWidgets('a saved bill: Download PDF and Send on WhatsApp', (tester) async {
    final f = await open(tester, '/sales');
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    final id = (await tester.runAsync(() => c.read(appDataProvider).db.rows('SELECT id, number, total_paise FROM bills WHERE cancelled = 0 ORDER BY billed_at DESC LIMIT 1')))!.single;
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/sales?open=${Uri.encodeQueryComponent(id.read<String>('id'))}');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('bill-download-pdf')));
    await tester.tap(find.byKey(const ValueKey('bill-download-pdf')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pumpAndSettle();
    expect(f.saver.saved.keys.single, 'Bill ${id.read<String>('number')}.pdf');
    expect(String.fromCharCodes(f.saver.saved.values.single.take(5)), '%PDF-');
    f.saver.saved.clear();

    await tester.ensureVisible(find.byKey(const ValueKey('bill-whatsapp')));
    await tester.tap(find.byKey(const ValueKey('bill-whatsapp')));
    await tester.pumpAndSettle();
    await sendOnWhatsapp(tester);
    expect(f.saver.saved.keys.single, 'Bill ${id.read<String>('number')}.pdf');
    expect(f.revealer.copied, hasLength(1));
    final url = Uri.decodeComponent(f.launcher.opened.single);
    expect(url, contains('919876543210'));
    expect(url, contains('bill ${id.read<String>('number')}'));
  });

  testWidgets('an estimate: Download PDF and Send on WhatsApp', (tester) async {
    final f = await open(tester, '/estimates');
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    final est = c.read(estimationsProvider).first;
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/estimates?open=${Uri.encodeQueryComponent(est.number)}');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('est-download-pdf')));
    await tester.tap(find.byKey(const ValueKey('est-download-pdf')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pumpAndSettle();
    expect(f.saver.saved.keys.single, 'Estimate ${est.number}.pdf');
    expect(String.fromCharCodes(f.saver.saved.values.single.take(5)), '%PDF-');
    f.saver.saved.clear();

    await tester.ensureVisible(find.byKey(const ValueKey('est-whatsapp')));
    await tester.tap(find.byKey(const ValueKey('est-whatsapp')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    await sendOnWhatsapp(tester);
    expect(f.saver.saved.keys.single, 'Estimate ${est.number}.pdf');
    final url = Uri.decodeComponent(f.launcher.opened.single);
    expect(url, contains('estimate ${est.number}'));
    expect(url, contains('This is an estimate, not a bill'));
  });

  test('the file name, the paper and the message', () {
    final doc = samplePrintDoc(seedProducts(), DateTime(2026, 10, 27, 12));
    expect(docFileName(doc, bill: 'Bill', estimate: 'Estimate'), 'Bill A-020001.pdf');
    expect(docFileName(samplePrintDoc(seedProducts(), DateTime(2026, 10, 27), mode: DocMode.estimation), bill: 'Bill', estimate: 'Estimate'), 'Estimate EST-00231.pdf');
    expect(shareablePaper(PaperSize.mm80), PaperSize.a4, reason: 'a roll is a printer width: a PDF for a customer is A4');
    expect(shareablePaper(PaperSize.mm58), PaperSize.a4);
    expect(shareablePaper(PaperSize.a5), PaperSize.a5);
    final m = docMessage(doc, shopName: 'Senthil Enterprises', shopPhone: '9342363155');
    expect(m, contains('bill A-020001'));
    expect(m, contains('Balance to pay'));
    expect(m, contains('9342363155'));
  });
}
