/// Opening the shop at start-up: find the data folder, open the database (or say plainly why it cannot be opened), read everything the
/// screens need at once, and decide whether the first-run set-up is still to do.
library;

import 'core/app_paths.dart';
import 'core/data_mode.dart';

export 'core/data_mode.dart';
import 'data/app_data.dart';
import 'data/context.dart';
import 'data/db/errors.dart';
import 'data/db/open.dart';
import 'data/ids.dart';
import 'data/importer/swap.dart';
import 'data/repo/series_registry.dart';
import 'demo/demo_seeder.dart';
import 'fake/data_providers.dart';

sealed class BootOutcome {
  const BootOutcome(this.mode);
  final DataMode mode;
}

class BootReady extends BootOutcome {
  const BootReady(super.mode, {this.swap, required this.data, required this.boot, required this.needsSetup, required this.dataDir, required this.deviceId, required this.location});
  final AppData data;
  final Bootstrap boot;

  /// True until the first-run set-up has been completed (shop details, this computer's bill letter).
  final bool needsSetup;
  final String dataDir, deviceId, location;

  /// Set when this start-up switched the data file (an ERP 1 import or a go-back); the app then opens on the Health page to show the real counts.
  final SwapResult? swap;
}

class BootProblem extends BootOutcome {
  const BootProblem(super.mode, this.error);
  final DatabaseOpenException error;
}

/// The id of THIS computer: made once and kept in a small file outside the data folder (a restored backup never changes it).
Future<String> loadDeviceId(AppPaths paths) async {
  final saved = await paths.readText('device.id');
  if (saved != null && RegExp(r'^[0-9a-f-]{20,40}$').hasMatch(saved)) return saved;
  final id = newId();
  await paths.writeText('device.id', id);
  return id;
}

Future<DataMode> loadMode(AppPaths paths) async => (await paths.readText('mode')) == 'demo' ? DataMode.demo : DataMode.real;

Future<void> saveMode(AppPaths paths, DataMode mode) => paths.writeText('mode', mode.name);

Future<BootOutcome> bootApp({required AppPaths paths, required DataMode mode, DateTime Function()? clock, bool background = true, DemoCounts demoCounts = const DemoCounts()}) async {
  final now = clock ?? DateTime.now;
  final deviceId = await loadDeviceId(paths);
  // a data switch the owner confirmed (an ERP 1 import, or going back) happens HERE, before the file is opened
  final swap = (mode == DataMode.real && paths.dataDir.isNotEmpty) ? await applyPendingSwap(paths.dataDir) : null;
  final location = paths.dbLocation(mode == DataMode.demo ? 'demo' : 'shop');
  try {
    final db = await openShopDatabase(location, background: background);
    final data = AppData(DataContext(db: db, deviceId: deviceId, clock: now));
    if (mode == DataMode.demo && await data.settings.get('shop.created') == null) {
      // the first time demo mode is used: fill the separate demo file with the sample shop (this computer gets the letter A)
      final t = now();
      await seedDemo(data, DateTime(t.year, t.month, t.day, t.hour, t.minute), counts: demoCounts);
      await SeriesRegistry(data.settings, deviceId).claim('A');
      await data.settings.put('shop.created', '${data.cx.nowMs()}');
    }
    if (await data.settings.get('shop.id') == null) await data.settings.put('shop.id', newId()); // names this shop; a backup of another shop is refused by it
    final mine = await SeriesRegistry(data.settings, deviceId).mine();
    final created = await data.settings.get('shop.created') != null;
    data.bills.series = mine ?? 'A';
    final t = now();
    final boot = await Bootstrap.load(data, now: DateTime(t.year, t.month, t.day, t.hour, t.minute));
    return BootReady(mode, swap: swap, data: data, boot: boot, needsSetup: !created || mine == null, dataDir: paths.dataDir, deviceId: deviceId, location: location);
  } on DatabaseOpenException catch (e) {
    return BootProblem(mode, e);
  }
}
