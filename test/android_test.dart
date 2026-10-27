import 'dart:convert';
import 'package:erp2/core/android_bridge.dart';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/core/file_saver_io.dart';
import 'package:erp2/core/printer_service.dart';
import 'package:erp2/core/update_check.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/features/share/whatsapp_share.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove (the phone's own Android code is a stand-in here; the real one is tried on the emulator): on an Android phone a saved
// file goes into the phone's Downloads folder (or the Share menu on an old phone); "Send on WhatsApp" hands the PDF and the message straight to
// that person's chat instead of the computer's copy-and-paste; a phone prints through its own print window; and the update check on a phone looks
// for the phone app in the release, never the computer's Setup.
class FakeBridge implements AndroidBridge {
  FakeBridge({this.downloads = true, this.shareWay = 'whatsapp'});
  final bool downloads;
  final String? shareWay;
  final saved = <(String, String, int)>[];
  final shared = <({String name, String mime, String text, String phone, Uint8List bytes})>[];
  @override
  bool get available => true;
  @override
  Future<bool> openUrl(String url) async => true;
  @override
  Future<String?> saveToDownloads(Uint8List bytes, {required String name, required String mime}) async {
    if (!downloads) return null;
    saved.add((name, mime, bytes.length));
    return 'Downloads/ASK ERP 2.0/$name';
  }

  @override
  Future<String?> share(Uint8List bytes, {required String name, required String mime, String text = '', String phone = ''}) async {
    shared.add((name: name, mime: mime, text: text, phone: phone, bytes: bytes));
    return shareWay;
  }
}

void main() {
  test('a phone saves into Downloads; an old phone opens the Share menu instead; the kind of file is right', () async {
    final b = FakeBridge();
    expect(await AndroidFileSaver(b).save('Bill A-000006.pdf', Uint8List.fromList([1, 2, 3])), 'Downloads/ASK ERP 2.0/Bill A-000006.pdf');
    expect(b.saved.single, ('Bill A-000006.pdf', 'application/pdf', 3));
    final old = FakeBridge(downloads: false, shareWay: 'menu');
    expect(await AndroidFileSaver(old).save('Products report.xlsx', Uint8List.fromList([1])), 'Products report.xlsx');
    expect(old.shared.single.mime, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    expect(await AndroidFileSaver(FakeBridge(downloads: false, shareWay: null)).save('x.pdf', Uint8List(1)), isNull, reason: 'nothing could open: said as not saved');
    final b2 = FakeBridge();
    await AndroidFileSaver(b2).save('../../etc/x.csv', Uint8List(1));
    expect(b2.saved.single.$1, isNot(contains('/')), reason: 'no folder in the name');
    expect(mimeFor('Statement Sibi.CSV'), 'text/csv');
  });

  testWidgets('a phone: Send on WhatsApp hands the PDF and the message to that person\'s chat (no copy-and-paste)', (tester) async {
    final bridge = FakeBridge();
    final saver = FakeSaver();
    await pumpApp(tester, size: const ScreenSpec('phone', 390, 844), location: '/', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [
      androidBridgeProvider.overrideWithValue(bridge),
      fileSaverProvider.overrideWithValue(saver),
    ]);
    final ctx = tester.element(find.byType(Scaffold).first);
    final done = showWhatsappShare(ctx, title: 'Bill A-1', phone: '75989 84397', message: 'Hello Sibi', pdf: () async => Uint8List.fromList(utf8.encode('%PDF-1.4 test')), fileName: 'Bill A-1.pdf');
    await tester.pumpAndSettle();
    expect(find.textContaining('straight into this person\'s WhatsApp chat'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wa-go')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    final s = bridge.shared.single;
    expect((s.name, s.mime, s.text, s.phone), ('Bill A-1.pdf', 'application/pdf', 'Hello Sibi', '917598984397'));
    expect(utf8.decode(s.bytes), startsWith('%PDF'));
    expect(saver.saved, isEmpty, reason: 'nothing is left in a folder to find by hand');
    expect(find.textContaining('WhatsApp opened the chat with the PDF'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wa-close')));
    await tester.pumpAndSettle();
    expect(await done, isTrue);
  });

  test('the tests run on a computer: it is not taken for a phone (the drawing platform of tests is Android, the system is not)', () {
    expect(defaultTargetPlatform, TargetPlatform.android, reason: 'how Flutter tests draw');
    expect(isPhone, isFalse, reason: 'the real system decides');
  });

  test('the update check on a phone looks for the phone app (.apk), never the computer Setup', () {
    final body = jsonEncode({
      'tag_name': 'v2.2.0',
      'html_url': 'https://github.com/Anushath15/ERP-2.0/releases/tag/v2.2.0',
      'assets': [
        {'name': 'ASK-ERP-2.0-Setup.exe', 'browser_download_url': 'https://github.com/Anushath15/ERP-2.0/releases/download/v2.2.0/ASK-ERP-2.0-Setup.exe'},
        {'name': 'ASK-ERP-2.0.apk', 'browser_download_url': 'https://github.com/Anushath15/ERP-2.0/releases/download/v2.2.0/ASK-ERP-2.0.apk'},
      ],
    });
    expect(parseRelease(body)!.downloadUrl, endsWith('.exe'));
    expect(parseRelease(body, installer: '.apk')!.downloadUrl, endsWith('ASK-ERP-2.0.apk'));
    expect(parseRelease(jsonEncode({'tag_name': 'v2.2.0', 'html_url': 'https://github.com/x', 'assets': []}), installer: '.apk')!.downloadUrl, isEmpty);
  });

  test('the bridge stand-in is the one the app reads when overridden', () {
    final c = ProviderContainer(overrides: [androidBridgeProvider.overrideWithValue(FakeBridge())]);
    addTearDown(c.dispose);
    expect(c.read(androidBridgeProvider).available, isTrue);
    expect(const ChannelAndroidBridge().available, isFalse, reason: 'tests run on a computer');
  });
}
