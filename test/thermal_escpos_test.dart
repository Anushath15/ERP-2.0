import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:erp2/core/raw_print.dart';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/domain_lite/bill_calc.dart' show calcBill;
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/features/print/escpos.dart';
import 'package:erp2/features/print/print_layout.dart';
import 'package:erp2/features/print/print_preview.dart' show samplePrintDoc;
import 'package:erp2/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers.dart';

// What these tests prove: the thermal printer gets the same bill as the roll PDF, in its own language (ESC/POS): no line is wider than the
// roll, the shop name and the grand total are in tall letters, the rupee sign is "Rs.", the printer draws the UPI QR from the same link, the
// paper is cut, and the drawer opens only for a cash bill right after Save and print. Text typed into the program (a product name, the
// customer) can never become a printer command. A network printer must be in the shop network; the bytes reach it exactly. The Print button
// uses the thermal printer only on roll paper, and when it does not answer the bill is printed the normal way and the person is told.
const l = Strings();
final now = DateTime(2026, 10, 27, 11);

/// Reads ESC/POS bytes back: the text lines, and the commands in order. Fails on any control byte that is not one of ours, so a test
/// passing means nothing else could have reached the printer.
({List<String> lines, List<String> commands, List<String> qrData}) readBack(Uint8List b) {
  final lines = <String>[], commands = <String>[], qr = <String>[];
  var cur = StringBuffer();
  var i = 0;
  while (i < b.length) {
    final x = b[i];
    if (x == 0x0A) {
      lines.add(cur.toString());
      cur = StringBuffer();
      i++;
    } else if (x == 0x1B) {
      final c = String.fromCharCode(b[i + 1]);
      final len = switch (c) { '@' => 2, 't' || 'a' || 'E' || 'd' => 3, 'p' => 5, _ => throw StateError('unknown ESC $c at $i') };
      commands.add(c == 'p' ? 'drawer' : 'ESC $c ${len > 2 ? b[i + 2] : ''}'.trim());
      i += len;
    } else if (x == 0x1D) {
      final c = String.fromCharCode(b[i + 1]);
      if (c == '!') {
        commands.add('size ${b[i + 2]}');
        i += 3;
      } else if (c == 'V') {
        commands.add('cut');
        i += 4;
      } else if (c == '(' && b[i + 2] == 0x6B) {
        final n = b[i + 3] + b[i + 4] * 256;
        if (b[i + 6] == 0x50) qr.add(String.fromCharCodes(b.sublist(i + 8, i + 5 + n)));
        commands.add('qr ${String.fromCharCode(b[i + 6])}');
        i += 5 + n;
      } else {
        throw StateError('unknown GS $c at $i');
      }
    } else if (x < 0x20 || x >= 0x7F) {
      throw StateError('a stray byte $x at $i');
    } else {
      cur.writeCharCode(x);
      i++;
    }
  }
  if (cur.isNotEmpty) lines.add(cur.toString());
  return (lines: lines, commands: commands, qrData: qr);
}

PrintLayout layout(PrintDoc doc, {ShopProfile shop = ShopProfile.sample}) => buildPrintLayout(doc: doc, shop: shop, l: l);

class FakeRaw implements RawPrinter {
  bool ok = true;
  final jobs = <({String to, Uint8List bytes})>[];
  @override
  Future<bool> toWindowsPrinter(String printerName, Uint8List bytes, {required String jobName}) async {
    if (ok) jobs.add((to: printerName, bytes: bytes));
    return ok;
  }

  @override
  Future<bool> toNetwork(String host, int port, Uint8List bytes) async {
    if (ok) jobs.add((to: '$host:$port', bytes: bytes));
    return ok;
  }
}

void main() {
  final products = seedProducts();

  group('the bytes', () {
    for (final chars in [thermalChars80, 42, thermalChars58]) {
      test('$chars letters per line: no line is wider; the whole bill is there; the shop name and grand total are tall; cut at the end', () {
        final lay = layout(samplePrintDoc(products, now));
        final b = encodeEscPosBill(lay, EscPosOptions(chars: chars));
        expect(b.sublist(0, 2), [0x1B, 0x40], reason: 'starts fresh');
        final r = readBack(b);
        for (final s in r.lines) {
          expect(s.length, lessThanOrEqualTo(chars), reason: '"$s"');
        }
        final all = r.lines.join('\n');
        expect(all, contains(ShopProfile.sample.name.toUpperCase()));
        expect(all, contains(l.rcTaxInvoice));
        expect(all, contains('A-020001'));
        for (final it in lay.items) {
          expect(all.replaceAll('\n', ' '), contains(it.name.split(' ').first), reason: it.name);
          expect(all, contains(it.amount));
        }
        expect(all, contains('Rs.${formatGrand(lay)}'), reason: 'the rupee sign as Rs.');
        expect(r.commands.where((c) => c == 'size 1'), hasLength(2), reason: 'the shop name and the grand total');
        expect(r.commands.last, 'cut');
        expect(r.commands, isNot(contains('drawer')));
      });
    }

    test('the printer draws the QR from the same UPI link as the PDF; a paid bill has none', () {
      final due = layout(samplePrintDoc(products, now));
      expect(due.upiData, isNotEmpty, reason: 'the sample bill has money still due');
      expect(readBack(encodeEscPosBill(due, const EscPosOptions(chars: 48))).qrData, [due.upiData]);
      final paid = samplePrintDoc(products, now);
      final paidLay = layout(shop: ShopProfile.sample.copyWith(qrOnEveryBill: false), PrintDoc(mode: paid.mode, number: paid.number, date: paid.date, customer: paid.customer, lines: paid.lines, calc: paid.calc, pay: PayMode.cash, receivedPaise: paid.calc.grandTotal));
      final r = readBack(encodeEscPosBill(paidLay, const EscPosOptions(chars: 48), paidText: l.rcPaidInFull));
      expect(r.qrData, isEmpty, reason: 'paid in full, and the shop does not want a QR on every bill');
      expect(r.lines, contains(l.rcPaidInFull));
    });

    test('no cut when switched off; the drawer pulse only when asked', () {
      final lay = layout(samplePrintDoc(products, now));
      expect(readBack(encodeEscPosBill(lay, const EscPosOptions(chars: 48, cut: false))).commands, isNot(contains('cut')));
      expect(readBack(encodeEscPosBill(lay, const EscPosOptions(chars: 48, drawer: true))).commands.where((c) => c == 'drawer'), hasLength(1));
    });

    test('SECURITY: printer commands typed into a product name or the customer are printed as nothing, never sent as commands', () {
      final p = products.first.copyWith(name: 'BULB\x1Bp\x00\x19\xFA\x1DVB\x00 9W\n\x1B@ மி', brand: '');
      final lines = [CartLine(product: p, qtyMilli: 1000)];
      final doc = PrintDoc(mode: DocMode.invoice, number: 'A-1', date: now, customer: 'Evil\x1Bp\x00\x19\xFA', lines: lines, calc: calcBill(lines), pay: PayMode.cash);
      final r = readBack(encodeEscPosBill(layout(doc), const EscPosOptions(chars: 32, cut: false)));
      expect(r.commands, isNot(contains('drawer')));
      expect(r.commands, isNot(contains('cut')));
      expect(r.commands.where((c) => c == 'ESC @'), hasLength(1), reason: 'only our own start');
      expect(r.lines.join(' '), contains('BULB'));
      expect(r.lines.join(' '), contains('??'), reason: 'Tamil letters the printer cannot show come out as ?');
    });

    test('wrapping and two columns', () {
      expect(wrapText('ANCHOR 10 SQMM FR WIRE 90M GREEN', 12), ['ANCHOR 10', 'SQMM FR WIRE', '90M GREEN']);
      expect(wrapText('ABCDEFGHIJKLMNOP', 6), ['ABCDEF', 'GHIJKL', 'MNOP']);
      expect(twoCols('Total', '8,619.00', 20), ['Total       8,619.00']);
      expect(twoCols('Balance due (added to credit)', 'Rs.7,619.00', 20), ['Balance due (added', 'to credit)', '         Rs.7,619.00']);
    });

    test('the test slip: a ruler exactly one line wide, a QR, the cut', () {
      final r = readBack(encodeEscPosTestSlip(shopName: 'Senthil Enterprises', title: l.thermalTestTitle, message: l.thermalTestLine, when: '27/10/2026', o: const EscPosOptions(chars: 42)));
      expect(r.lines, contains('123456789012345678901234567890123456789012'));
      expect(r.qrData, ['ASK ERP 2.0']);
      expect(r.commands.last, 'cut');
    });
  });

  group('network printers', () {
    test('only an address in the shop network is used (port 9100 when not given)', () {
      expect(parsePrinterAddress('192.168.1.50'), (host: '192.168.1.50', port: 9100));
      expect(parsePrinterAddress(' 192.168.1.50:9101 '), (host: '192.168.1.50', port: 9101));
      expect(parsePrinterAddress('10.0.0.7'), isNotNull);
      expect(parsePrinterAddress('172.20.1.2'), isNotNull);
      for (final bad in ['8.8.8.8', '172.32.0.1', '192.168.1.300', '192.168.1.50:0', '192.168.1.50:70000', 'printer.local', 'http://192.168.1.5', '']) {
        expect(parsePrinterAddress(bad), isNull, reason: bad);
      }
    });

    test('the bytes reach the printer exactly; a printer that is not there gives false (and does not hang)', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final got = Completer<List<int>>();
      final buf = <int>[];
      server.listen((s) => s.listen(buf.addAll, onDone: () => got.complete(buf)));
      final bytes = encodeEscPosBill(layout(samplePrintDoc(products, now)), const EscPosOptions(chars: 48));
      expect(await const SystemRawPrinter().toNetwork('127.0.0.1', server.port, bytes), isTrue);
      expect(await got.future.timeout(const Duration(seconds: 5)), bytes);
      final port = server.port;
      await server.close();
      expect(await const SystemRawPrinter().toNetwork('127.0.0.1', port, bytes), isFalse);
    });
  });

  test('the thermal settings are remembered on this computer; strange saved values fall back', () {
    const s = AppSettings(thermal: ThermalLink.network, thermalAddress: '192.168.1.50:9100', thermalChars: 42, thermalCut: false, thermalDrawer: true);
    final back = AppSettings.fromJson(s.toJson());
    expect((back.thermal, back.thermalAddress, back.thermalChars, back.thermalCut, back.thermalDrawer), (ThermalLink.network, '192.168.1.50:9100', 42, false, true));
    final bad = AppSettings.fromJson({'thermal': 'bluetooth', 'thermalChars': 50, 'thermalCut': 'yes', 'thermalAddress': 7});
    expect((bad.thermal, bad.thermalChars, bad.thermalCut, bad.thermalAddress), (ThermalLink.off, 0, true, ''));
  });

  group('the Print button', () {
    Future<(dynamic, FakeRaw, FakePrinter)> start(WidgetTester tester, {PaperSize paper = PaperSize.mm80}) async {
      final raw = FakeRaw(), pdf = FakePrinter();
      final c = await pumpApp(tester, size: desktop1366, location: '/', motion: MotionLevel.off, followSystemMotion: false, printer: pdf, extraOverrides: [rawPrinterProvider.overrideWithValue(raw)]);
      c.read(settingsProvider.notifier).set((x) => x.copyWith(paper: paper, thermal: ThermalLink.windows, thermalDrawer: true));
      // the same thing Save and print does: the document, the flag, then the page
      c.read(printDocProvider.notifier).set(samplePrintDoc(products, now));
      c.read(autoPrintProvider.notifier).set(true);
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/print');
      await tester.pumpAndSettle();
      return (c, raw, pdf);
    }

    testWidgets('roll paper: straight to the thermal printer (the default one); the drawer opens right after Save and print, not on a reprint', (tester) async {
      final (_, raw, pdf) = await start(tester);
      expect(raw.jobs, hasLength(1));
      expect(raw.jobs.single.to, 'HP LaserJet A4', reason: 'no bill printer chosen: the computer default');
      expect(readBack(raw.jobs.single.bytes).commands, contains('drawer'), reason: 'a cash bill, just saved');
      expect(pdf.jobs, isEmpty, reason: 'no PDF when the thermal printer took it');
      await tester.tap(find.byKey(const ValueKey('printNow')));
      await tester.pumpAndSettle();
      expect(raw.jobs, hasLength(2));
      expect(readBack(raw.jobs.last.bytes).commands, isNot(contains('drawer')), reason: 'a reprint never opens the drawer');
      expect(find.text(l.thermalSent), findsOneWidget);
    });

    testWidgets('the thermal printer does not answer: the bill prints the normal way and the person is told', (tester) async {
      final (_, raw, pdf) = await start(tester);
      raw.ok = false;
      await tester.tap(find.byKey(const ValueKey('printNow')));
      await tester.pumpAndSettle();
      expect(pdf.jobs, hasLength(1));
      expect(find.textContaining(l.thermalFailed), findsOneWidget);
    });

    testWidgets('A4 paper: the normal way, even with the thermal printer switched on', (tester) async {
      final (_, raw, pdf) = await start(tester, paper: PaperSize.a4);
      expect(raw.jobs, isEmpty);
      expect(pdf.jobs, hasLength(1));
    });
  });

  testWidgets('Settings: the thermal card switches on, keeps only a good network address, and prints a test slip there', (tester) async {
    final raw = FakeRaw();
    final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 3000), location: '/settings', motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [rawPrinterProvider.overrideWithValue(raw)]);
    expect(find.byKey(const ValueKey('thermalTest')), findsNothing, reason: 'off by default');
    await tester.ensureVisible(find.byKey(const ValueKey('thermal-network')));
    await tester.tap(find.byKey(const ValueKey('thermal-network')));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).thermal, ThermalLink.network);
    expect(find.byKey(const ValueKey('thermalNeedsRoll')), findsOneWidget, reason: 'the paper is A4: said in words');
    await tester.enterText(find.byKey(const ValueKey('thermalAddress')), '8.8.8.8');
    await tester.pumpAndSettle();
    expect(find.text(l.thermalAddressBad), findsOneWidget);
    expect(c.read(settingsProvider).thermalAddress, '', reason: 'an address outside the shop is not kept');
    await tester.enterText(find.byKey(const ValueKey('thermalAddress')), '192.168.1.80');
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).thermalAddress, '192.168.1.80');
    await tester.ensureVisible(find.byKey(const ValueKey('thermalTest')));
    await tester.tap(find.byKey(const ValueKey('thermalTest')));
    await tester.pumpAndSettle();
    expect(raw.jobs.single.to, '192.168.1.80:9100');
    await tester.tap(find.byKey(const ValueKey('thermalOpenDrawer')));
    await tester.pumpAndSettle();
    expect(readBack(raw.jobs.last.bytes).commands, ['ESC @', 'ESC t 0', 'drawer']);
  });
}

String formatGrand(PrintLayout lay) => lay.totals.firstWhere((t) => t.id == 'paperTotal').value.replaceAll('₹ ', '');
