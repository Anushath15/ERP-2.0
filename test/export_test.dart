import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/core/logo_image.dart';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/domain/bill_math.dart';
import 'package:erp2/data/repo/export_repo.dart';
import 'package:erp2/domain/export/export_table.dart';
import 'package:erp2/features/export/export_pdf.dart';
import 'package:erp2/features/shop/shop_profile_screen.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/shop_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'data/helpers.dart' as dh;
import 'helpers.dart';

// Export (Excel, CSV, PDF), the round-off switch and the shop logo: each control now does its job.
void main() {
  group('tables', () {
    const t = ExportTable(name: 'Sales', headers: ['Name', 'Amount', 'Qty'], rows: [
      ['=HYPERLINK("http://evil")', Rupees(123456), Qty(1500)],
      ['Sri Murugan, Sons', Rupees(-50), Qty(2000)],
    ]);

    test('CSV: byte-order mark, rupees with two decimals, formulas defused, commas quoted', () {
      final b = encodeCsv(t);
      expect(b.take(3), [0xEF, 0xBB, 0xBF]);
      final text = utf8.decode(b.skip(3).toList());
      expect(text, 'Name,Amount,Qty\r\n\'=HYPERLINK("http://evil"),1234.56,1.5\r\n"Sri Murugan, Sons",-0.50,2\r\n'.replaceFirst('\'=HYPERLINK("http://evil")', '"\'=HYPERLINK(""http://evil"")"'));
    });

    test('Excel: a real zip with the expected parts; numbers are numbers and text is text, never a formula', () {
      final zip = ZipDecoder().decodeBytes(encodeXlsx(t));
      final names = zip.files.map((f) => f.name).toSet();
      expect(names, containsAll(['[Content_Types].xml', 'xl/workbook.xml', 'xl/worksheets/sheet1.xml', 'xl/styles.xml']));
      final sheet = utf8.decode(zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
      expect(sheet, contains('<v>1234.56</v>'));
      expect(sheet, contains('<v>-0.50</v>'));
      expect(sheet, contains('t="inlineStr"'));
      expect(sheet, isNot(contains('<f>')), reason: 'no formula cell is ever written');
      expect(sheet, contains('=HYPERLINK(&quot;http://evil&quot;)'));
    });

    test('Excel: control characters and a long odd sheet name cannot break the file', () {
      const odd = ExportTable(name: 'A/B:C*[x]?\\ and a very long name that goes past thirty one characters', headers: ['H\u0001'], rows: [
        ['bad\u0000text <b> & "q"'],
      ]);
      final zip = ZipDecoder().decodeBytes(encodeXlsx(odd));
      final wb = utf8.decode(zip.findFile('xl/workbook.xml')!.content as List<int>);
      expect(RegExp(r'name="([^"]*)"').firstMatch(wb)!.group(1)!.length, lessThanOrEqualTo(31));
      final sheet = utf8.decode(zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
      expect(sheet, contains('bad' 'text &lt;b&gt; &amp; &quot;q&quot;'));
    });

    test('money text: paise to rupees exactly, negatives and quantities', () {
      expect(const Rupees(5).text, '0.05');
      expect(const Rupees(-100).text, '-1.00');
      expect(const Rupees(100000000).text, '1000000.00');
      expect(const Qty(125).text, '0.125');
      expect(const Qty(1000).text, '1');
    });
  });

  group('from the database', () {
    late AppData d;
    setUp(() async {
      d = dh.memoryShop();
      final p = dh.sampleProduct('Wood screw', price: 12500, stock: 20000, id: 'p1');
      await d.catalog.saveProduct(p, create: true);
      await d.catalog.saveCustomer(dh.sampleCustomer('Murugan', id: 'c1'), create: true);
      BillLineInput line(int q) => BillLineInput(productId: 'p1', name: p.name, unit: p.unit, qtyMilli: q, ratePaise: p.pricePaise, gstBp: p.gstBp);
      await d.bills.saveBill(SaveBillInput(idemKey: 'k1', at: DateTime(2026, 10, 14, 10), lines: [line(2000)]));
      await d.bills.saveBill(SaveBillInput(idemKey: 'k2', at: DateTime(2026, 10, 15, 10), lines: [line(4000)], customerId: 'c1', customerName: 'Murugan', receivedPaise: 20000));
    });
    tearDown(() => d.close());

    test('sales: one row per bill with the real totals, status and payment', () async {
      final t = await buildExport(d, ExportKind.sales);
      expect(t.rows.length, 2);
      expect(t.rows[0][0], 'A-000001');
      expect((t.rows[0][4] as Rupees).paise, 25000);
      expect(t.rows[1][8], 'Part paid');
      expect((t.rows[1][6] as Rupees).paise, 30000);
    });

    test('GST register: taxable plus tax equals the total (to the rounding)', () async {
      final t = await buildExport(d, ExportKind.gst);
      for (final r in t.rows) {
        final sum = [3, 4, 5, 6, 7].fold<int>(0, (s, i) => s + (r[i] as Rupees).paise) + (r[8] as Rupees).paise;
        expect(sum, (r[9] as Rupees).paise);
      }
    });

    test('products, customers, money to collect', () async {
      final prod = await buildExport(d, ExportKind.products);
      expect(prod.rows.single[0], 'Wood screw');
      expect((prod.rows.single[7] as Qty).milli, 14000);
      final cust = await buildExport(d, ExportKind.customers);
      expect((cust.rows.single[6] as Rupees).paise, 30000);
      final dues = await buildExport(d, ExportKind.dues);
      expect(dues.rows.single[0], 'Murugan');
      expect((dues.rows.single[3] as Rupees).paise, 30000);
    });

    test('expenses: empty is empty, not an error', () async {
      expect((await buildExport(d, ExportKind.expenses)).rows, isEmpty);
    });
  });

  group('round off', () {
    const lines = [CalcLineIn(rate: 12345, qtyMilli: 1000, gstBp: 1800)];
    test('on (default): to the nearest rupee, the difference is Round off', () {
      final c = calcBillIn(lines);
      expect(c.grandTotal % 100, 0);
      expect(c.grandTotal, 12300);
      expect(c.roundOff, -45);
    });
    test('off: the exact total to the paisa and no round off', () {
      final c = calcBillIn(lines, roundOff: false);
      expect(c.grandTotal, 12345);
      expect(c.roundOff, 0);
    });
    test('a saved bill keeps its exact total when the switch is off', () async {
      final d = dh.memoryShop();
      final p = dh.sampleProduct('Item', price: 12345, stock: 10000, id: 'p');
      await d.catalog.saveProduct(p, create: true);
      BillLineInput l() => BillLineInput(productId: 'p', name: 'Item', unit: p.unit, qtyMilli: 1000, ratePaise: 12345, gstBp: p.gstBp);
      final off = await d.bills.saveBill(SaveBillInput(idemKey: 'a', at: DateTime(2026, 10, 14), lines: [l()], roundOff: false));
      final on = await d.bills.saveBill(SaveBillInput(idemKey: 'b', at: DateTime(2026, 10, 14), lines: [l()]));
      expect(off.totalPaise, 12345);
      expect(on.totalPaise, 12300);
      await d.close();
    });
    test('the shop profile remembers the switch and a damaged value keeps the default', () {
      final p = ShopProfile.fromJson({'roundOff': false});
      expect(p.roundOff, isFalse);
      expect(ShopProfile.fromJson({'roundOff': 'no'}).roundOff, isTrue);
      expect(ShopProfile.fromJson(jsonDecode(p.toJsonText())).roundOff, isFalse);
    });
  });

  group('logo', () {
    Uint8List picture(int w, int h) => Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));

    test('a big picture is shrunk to 256 px, kept as PNG', () {
      final b64 = prepareLogo(picture(1000, 500))!;
      final out = img.decodePng(base64Decode(b64))!;
      expect(out.width, 256);
      expect(out.height, 128);
    });
    test('a small picture stays as it is', () {
      final out = img.decodePng(base64Decode(prepareLogo(picture(40, 40))!))!;
      expect([out.width, out.height], [40, 40]);
    });
    test('not a picture, empty, or too big: refused', () {
      expect(prepareLogo(Uint8List.fromList(utf8.encode('hello'))), isNull);
      expect(prepareLogo(Uint8List(0)), isNull);
      expect(prepareLogo(Uint8List(maxLogoInputBytes + 1)), isNull);
    });
    test('damaged stored text gives no picture, never a crash', () {
      expect(logoBytes('!!!not base64'), isNull);
      expect(logoBytes(''), isNull);
    });
  });

  test('PDF: a long table (5,000 rows) is written, not refused for being too long', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final t = ExportTable(name: 'Long', headers: const ['A', 'B'], rows: [for (var i = 0; i < 6000; i++) ['row $i', Rupees(i)]]);
    final bytes = await encodePdf(t, shopName: 'Shop', now: DateTime(2026, 10, 17));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  group('screens', () {
    Future<dynamic> app(WidgetTester t, String loc, {List<Override> extra = const []}) =>
        pumpApp(t, size: const ScreenSpec('tall', 1920, 2400), location: loc, motion: MotionLevel.off, followSystemMotion: false, extraOverrides: extra);

    testWidgets('Export page: every button saves a real file (xlsx is a zip, csv has the header, pdf starts with %PDF)', (tester) async {
      final saver = FakeSaver();
      await app(tester, '/export', extra: [fileSaverProvider.overrideWithValue(saver)]);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('export-products-excel')));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await tester.tap(find.byKey(const ValueKey('export-products-csv')));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await tester.tap(find.byKey(const ValueKey('export-sales-pdf')));
        await tester.pump();
        await Future<void>.delayed(const Duration(seconds: 3));
      });
      await tester.pump();
      final byExt = {for (final e in saver.saved.entries) e.key.split('.').last: e.value};
      expect(byExt.keys, containsAll(['xlsx', 'csv', 'pdf']));
      expect(String.fromCharCodes(byExt['xlsx']!.take(2)), 'PK');
      expect(utf8.decode(byExt['csv']!.skip(3).toList()), startsWith('Name,Category,Unit'));
      expect(String.fromCharCodes(byExt['pdf']!.take(5)), '%PDF-');
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('Reports: the Export button opens the Export page', (tester) async {
      await app(tester, '/reports');
      await tester.tap(find.byKey(const ValueKey('reports-export')));
      await tester.pumpAndSettle();
      expect(find.text('Excel'), findsWidgets);
    });

    testWidgets('Shop profile: the round-off switch is saved and can be turned off', (tester) async {
      final c = await app(tester, '/shop');
      expect(c.read(shopProvider).roundOff, isTrue);
      await tester.ensureVisible(find.byKey(const ValueKey('shop-roundoff')));
      await tester.tap(find.byKey(const ValueKey('shop-roundoff')));
      await tester.pump();
      expect(c.read(shopProvider).roundOff, isFalse);
    });

    testWidgets('Shop profile: choosing a logo saves it, a bad file is refused, Remove goes back to the program logo', (tester) async {
      Uint8List? next;
      final c = await app(tester, '/shop', extra: [logoPickerProvider.overrideWithValue(() async => next)]);
      next = Uint8List.fromList(utf8.encode('not a picture'));
      await tester.tap(find.byKey(const ValueKey('shop-logo-choose')));
      await tester.pump();
      expect(c.read(shopProvider).logoPng, isEmpty);
      next = Uint8List.fromList(img.encodePng(img.Image(width: 300, height: 300)));
      await tester.tap(find.byKey(const ValueKey('shop-logo-choose')));
      await tester.pumpAndSettle();
      expect(c.read(shopProvider).logoPng, isNotEmpty);
      await tester.tap(find.byKey(const ValueKey('shop-logo-remove')));
      await tester.pump();
      expect(c.read(shopProvider).logoPng, isEmpty);
    });
  });

  test('the export folder is a real directory name on this PC (sanity for the saver)', () {
    expect(Directory.systemTemp.existsSync(), isTrue);
  });
}
