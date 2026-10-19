import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/app.dart';
import 'package:erp2/core/device_store.dart';
import 'package:erp2/core/file_saver.dart';
import 'package:erp2/core/link_launcher.dart';
import 'package:erp2/core/printer_service.dart';
import 'package:erp2/domain/credit/reminder.dart' show LinkPlatform;
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/fake/store.dart';
import 'package:drift/native.dart';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/app_database.dart';
import 'package:erp2/demo/demo_seeder.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

final fixedNow = DateTime(2026, 10, 13, 17, 30);

/// The sample shop is made once per test process (a second or so) and each test gets its own in-memory copy of it.
final _templates = <String, sql.Database>{};

/// The sample numbers the screens were designed with: 757 products, 5,000 customers, 600 recent bills, 300 estimates.
const testShopCounts = DemoCounts(bills: 600, estimates: 300);

Future<AppData> openDemoShop({DemoCounts counts = testShopCounts, DateTime? now}) async {
  final key = '${counts.products}/${counts.customers}/${counts.bills}/${counts.estimates}';
  var template = _templates[key];
  if (template == null) {
    template = sql.sqlite3.openInMemory();
    final db = AppDatabase(NativeDatabase.opened(template), native: false);
    await seedDemo(AppData(DataContext(db: db, deviceId: 'dev-test', clock: () => fixedNow)), fixedNow, counts: counts);
    _templates[key] = template;
  }
  final copy = sql.sqlite3.copyIntoMemory(template);
  final t = now ?? fixedNow;
  return AppData(DataContext(db: AppDatabase(NativeDatabase.opened(copy), native: false), deviceId: 'dev-test', clock: () => t));
}

class ScreenSpec {
  const ScreenSpec(this.name, this.w, this.h);
  final String name;
  final double w, h;
}

const desktop1920 = ScreenSpec('desktop-1920x1080', 1920, 1080);
const desktop1366 = ScreenSpec('desktop-1366x768', 1366, 768);
const desktop1280 = ScreenSpec('desktop-1280x720', 1280, 720);
const tabletPortrait = ScreenSpec('tablet-820x1180', 820, 1180);
const tabletLandscape = ScreenSpec('tablet-1024x768', 1024, 768);
const phone390 = ScreenSpec('phone-390x844', 390, 844);
const phone360 = ScreenSpec('phone-360x640', 360, 640);

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required ScreenSpec size,
  String location = '/',
  ThemeMode theme = ThemeMode.dark,
  double? textScale,
  DeviceStore? store,
  MotionLevel? motion,
  bool? followSystemMotion,
  List<Override> extraOverrides = const [],
  DemoCounts counts = testShopCounts,
  PrinterService? printer,
}) async {
  tester.view.physicalSize = Size(size.w, size.h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final (shop, boot) = (await tester.runAsync(() async {
    final d = await openDemoShop(counts: counts);
    return (d, await Bootstrap.load(d, now: fixedNow));
  }))!;
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [clockProvider.overrideWithValue(fixedNow), appDataProvider.overrideWithValue(shop), bootstrapProvider.overrideWithValue(boot), deviceStoreProvider.overrideWithValue(store ?? MemoryDeviceStore()), printerServiceProvider.overrideWithValue(printer ?? FakePrinter()), ...extraOverrides],
    child: ErpApp(initialLocation: location),
  ));
  final container = ProviderScope.containerOf(tester.element(find.byType(ErpApp)));
  container.read(settingsProvider.notifier).set((s) => s.copyWith(theme: theme, textScale: textScale ?? s.textScale, motion: motion ?? s.motion, followSystemMotion: followSystemMotion ?? s.followSystemMotion));
  await tester.pumpAndSettle();
  return container;
}

/// A stand-in for opening links: records what would be opened, never opens anything.
class FakeLauncher implements LinkLauncher {
  FakeLauncher({this.platform = LinkPlatform.windows, this.ok = true, this.appInstalled = true});
  @override
  final LinkPlatform platform;
  bool ok, appInstalled;
  final opened = <String>[];
  @override
  Future<bool> open(String url) async {
    if (url.startsWith('whatsapp:') && !appInstalled) return false;
    if (!ok) return false;
    opened.add(url);
    return true;
  }
}

/// A stand-in for saving files: keeps the bytes in memory, never touches the disk.
class FakeSaver implements FileSaver {
  final saved = <String, Uint8List>{};
  @override
  Future<String?> save(String fileName, Uint8List bytes) async {
    saved[fileName] = bytes;
    return 'Downloads/$fileName';
  }
}

/// A stand-in for printers: remembers what would have been printed and to which printer, never touches a real printer.
class FakePrinter implements PrinterService {
  FakePrinter({this.list = const [PrinterInfo(name: 'HP LaserJet A4', isDefault: true), PrinterInfo(name: 'Epson Receipt', isDefault: false)], this.status = PrintStatus.sent});
  final List<PrinterInfo> list;
  PrintStatus status;
  final jobs = <({String name, String printer, Uint8List bytes})>[];
  @override
  Future<List<PrinterInfo>> printers() async => list;
  @override
  Future<PrintOutcome> printPdf(Uint8List bytes, {required String jobName, String printerName = ''}) async {
    final target = list.where((p) => p.name == printerName).firstOrNull ?? list.where((p) => p.isDefault).firstOrNull;
    if (status == PrintStatus.sent && target == null) return const PrintOutcome(PrintStatus.noPrinter);
    if (status == PrintStatus.sent) jobs.add((name: jobName, printer: target!.name, bytes: bytes));
    return PrintOutcome(status, printer: target?.name ?? '');
  }
}
