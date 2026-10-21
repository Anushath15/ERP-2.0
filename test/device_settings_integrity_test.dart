import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/core/device_store_io.dart';
import 'package:erp2/fake/store.dart';

// SECURITY: device.json (and the browser's local storage) is a plain file anybody who sits at the computer can edit. It holds
// PREFERENCES only (text size, theme, paper...). Nothing about permission, roles, approval or trust is ever read from it.
void main() {
  const d = AppSettings();

  test('what is saved is display preferences only: no role, trust, approval, sign-in or shop field', () {
    final keys = d.toJson().keys.toSet();
    expect(keys, {'theme', 'accent', 'highContrast', 'textScale', 'billingScale', 'density', 'font', 'motion', 'followSystemMotion', 'motionAutoReduced', 'soundScan', 'soundSave', 'soundError', 'soundVolume', 'paper', 'printSize', 'printerName', 'labelPrinterName', 'printViaDialog', 'printAfterSave', 'featuresOff'});
  });

  test('security-looking keys in the file are ignored: the result is the same as a clean file', () {
    final evil = AppSettings.fromJson({
      'role': 'owner',
      'isOwner': true,
      'trusted': true,
      'deviceTrusted': true,
      'deviceApproved': true,
      'approved': true,
      'signedIn': true,
      'firstRunDone': false,
      'email': 'attacker@example.com',
      'shopName': 'Hacked',
      'creditLimitMode': 'off',
      'sync': 'offline',
      '__proto__': {'x': 1},
    });
    expect(jsonEncode(evil.toJson()), jsonEncode(d.toJson()));
    expect(evil.signedIn, d.signedIn);
    expect(evil.firstRunDone, d.firstRunDone);
    expect(evil.sync, d.sync);
  });

  test('out-of-range, wrong-type and non-number values go back to the default', () {
    final s = AppSettings.fromJson({'textScale': 999, 'billingScale': -3, 'soundVolume': 7, 'theme': 7, 'accent': {'a': 1}, 'font': null, 'paper': 'banner', 'printSize': 99, 'highContrast': 'yes', 'motion': []});
    expect(s.textScale, d.textScale);
    expect(s.billingScale, d.billingScale);
    expect(s.soundVolume, d.soundVolume);
    expect(s.theme, d.theme);
    expect(s.accent, d.accent);
    expect(s.font, d.font);
    expect(s.paper, d.paper);
    expect(s.printSize, d.printSize);
    expect(s.highContrast, d.highContrast);
    expect(s.motion, d.motion);
    expect(AppSettings.fromJson({'textScale': double.infinity}).textScale, d.textScale);
    expect(AppSettings.fromJson({'textScale': double.nan}).textScale, d.textScale);
    expect(AppSettings.fromJson({'soundVolume': double.negativeInfinity}).soundVolume, d.soundVolume);
  });

  test('values inside the range are kept', () {
    final s = AppSettings.fromJson({'textScale': 1.5, 'billingScale': 2.5, 'soundVolume': 0, 'paper': 'mm80', 'printSize': 'normal'});
    expect(s.textScale, 1.5);
    expect(s.billingScale, 2.5);
    expect(s.soundVolume, 0);
    expect(s.paper, PaperSize.mm80);
    expect(s.printSize, PrintTextSize.normal);
  });

  group('the settings file on disk', () {
    late Directory tmp;
    late File file;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('erp2_dev_');
      file = File('${tmp.path}${Platform.pathSeparator}device.json');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('a missing, empty, damaged, wrong-shaped or binary file gives defaults and never crashes', () {
      final store = FileDeviceStore(file);
      expect(store.load(), isEmpty);
      for (final bad in [<int>[], utf8.encode('{'), utf8.encode('[1,2,3]'), utf8.encode('"just text"'), utf8.encode('null'), [0xFF, 0xFE, 0x00, 0x01, 0x80, 0x81]]) {
        file.writeAsBytesSync(bad);
        expect(store.load(), isEmpty, reason: 'bytes $bad');
        expect(AppSettings.fromJson(store.load()).textScale, d.textScale);
      }
    });

    test('an enormous file is not read (a settings file is a few hundred bytes)', () {
      file.writeAsStringSync('{"textScale":1.5,"pad":"${'x' * 300000}"}');
      expect(FileDeviceStore(file).load(), isEmpty);
    });

    test('a normal file is read and saved without leaving a half-written file behind', () {
      final store = FileDeviceStore(file);
      store.save({'textScale': 1.25, 'theme': 'light'});
      expect(store.load()['textScale'], 1.25);
      expect(tmp.listSync().whereType<File>().map((f) => f.path.split(Platform.pathSeparator).last).toList(), ['device.json']);
    });
  });
}
