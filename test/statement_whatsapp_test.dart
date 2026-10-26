import 'dart:io';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/core/link_launcher.dart';
import 'package:erp2/core/reveal_file.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/credit_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// What this test proves: a customer's statement can be sent on WhatsApp: the PDF is saved with the customer's name, its folder is shown, and the chat opens with
// the amount to pay in the message.
void main() {
  testWidgets('statement on WhatsApp: PDF saved, folder shown, message has the amount due', (tester) async {
    final saver = FakeSaver();
    final launcher = FakeLauncher();
    final revealer = FakeRevealer();
    final c = await pumpApp(tester, size: const ScreenSpec('wide', 1500, 1400), location: '/credit', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [
      fileSaverProvider.overrideWithValue(saver),
      linkLauncherProvider.overrideWithValue(launcher),
      fileRevealerProvider.overrideWithValue(revealer),
    ]);
    final owing = c.read(creditProvider).entries.firstWhere((e) => e.value.balance > 0);
    final balance = owing.value.balance;
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/customers/${owing.key}/statement');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statementWhatsapp')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wa-phone')), '9876543210');
    await tester.tap(find.byKey(const ValueKey('wa-go')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pumpAndSettle();
    expect(saver.saved.keys.single, startsWith('Statement '));
    final dumpDir = Platform.environment['ASK_PDF_DIR'];
    if (dumpDir != null) {
      Directory(dumpDir).createSync(recursive: true);
      File('$dumpDir/${saver.saved.keys.single.replaceAll(' ', '_')}').writeAsBytesSync(saver.saved.values.single);
    }
    expect(String.fromCharCodes(saver.saved.values.single.take(5)), '%PDF-');
    expect(revealer.copied, hasLength(1), reason: 'the PDF itself is on the clipboard');
    await tester.tap(find.byKey(const ValueKey('wa-close')));
    await tester.pumpAndSettle();
    final url = Uri.decodeComponent(launcher.opened.single);
    expect(url, contains('919876543210'));
    expect(url, contains('Amount to pay'));
    final rupees = (balance / 100).toStringAsFixed(2);
    expect(url.replaceAll(',', ''), contains(rupees.replaceAll(',', '')));
  });
}
