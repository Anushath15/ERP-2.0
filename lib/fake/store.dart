/// In-memory "database" for the prototype: Riverpod providers over the seed data. Nothing is saved to disk.
library;

import 'package:flutter/material.dart' show ThemeMode;
import '../core/device_store.dart';
import '../domain/credit/reminder.dart';
import '../design/motion_level.dart';
import '../design/tokens.dart' show Accent, DensityMode, FontChoice;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import 'seed.dart';

final clockProvider = Provider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, n.hour, n.minute);
});

class ProductsNotifier extends Notifier<List<Product>> {
  @override
  List<Product> build() => seedProducts();
  void add(Product p) => state = [p, ...state];
  void update(Product p) => state = [for (final x in state) x.id == p.id ? p : x];
}

final productsProvider = NotifierProvider<ProductsNotifier, List<Product>>(ProductsNotifier.new);

class CustomersNotifier extends Notifier<List<Customer>> {
  @override
  List<Customer> build() => seedCustomers();
  void add(Customer c) => state = [c, ...state];
  void update(Customer c) => state = [for (final x in state) x.id == c.id ? c : x];
  void updatePhone(String id, String phone) => state = [for (final c in state) c.id == id ? c.copyWith(phone: phone) : c];
}

final customersProvider = NotifierProvider<CustomersNotifier, List<Customer>>(CustomersNotifier.new);

final billBookProvider = Provider<BillBook>((ref) => BillBook(ref.watch(clockProvider), customers: ref.read(customersProvider)));

/// All 20,000 bills, built once on first use.
final billsProvider = Provider<List<BillSummary>>((ref) => ref.watch(billBookProvider).all());

class EstimationsNotifier extends Notifier<List<EstimationDoc>> {
  @override
  List<EstimationDoc> build() => seedEstimations(ref.watch(clockProvider), ref.read(customersProvider));
  void add(EstimationDoc e) => state = [e, ...state];
  void replace(EstimationDoc e) => state = [for (final x in state) x.number == e.number ? e : x];
  void remove(String number) => state = [for (final x in state) if (x.number != number) x];
}

final estimationsProvider = NotifierProvider<EstimationsNotifier, List<EstimationDoc>>(EstimationsNotifier.new);

/// Generic record lists (dealers, purchases, expenses, ...), keyed by kind.
class RecsNotifier extends Notifier<List<Rec>> {
  RecsNotifier(this.kind);
  final String kind;
  @override
  List<Rec> build() {
    final now = ref.watch(clockProvider);
    final customers = ref.read(customersProvider);
    final products = ref.watch(productsProvider);
    switch (kind) {
      case 'dealers':
        return seedDealers();
      case 'categories':
        return seedCategories(products);
      case 'purchases':
        return seedPurchases(now, ref.read(recsProvider('dealers')));
      case 'purchaseReturns':
        return seedPurchaseReturns(now, ref.read(recsProvider('dealers')));
      case 'salesReturns':
        return seedSalesReturns(now, customers);
      case 'delivery':
        return seedDelivery(now, customers);
      case 'adjustments':
        return seedAdjustments(now, products);
      case 'expenses':
        return seedExpenses(now);
      case 'warranty':
        return seedWarranty(now, customers, products);
      case 'projects':
        return seedProjects();
      case 'staff':
        return seedStaff();
      case 'notifications':
        return seedNotifications(now);
    }
    return const [];
  }

  void add(Rec r) => state = [r, ...state];
  void replace(Rec r) => state = [for (final x in state) x.id == r.id ? r : x];
  void remove(String id) => state = [for (final x in state) if (x.id != id) x];
}

final recsProvider = NotifierProvider.family<RecsNotifier, List<Rec>, String>(RecsNotifier.new);

// ---------------- settings (per device; never synced) ----------------
enum PaperSize { a4, a5, mm80, mm58 }

/// How big the printed bill and estimate text is. Small is the default.
enum PrintTextSize { smaller, small, normal }

enum SyncState { synced, syncing, offline, attention }

/// What to do when a bill would take a customer over their credit limit (the owner chooses in Settings).
enum CreditLimitMode { off, warn, block }

/// Everything in here is remembered on THIS device only (see DeviceStore). Shop details are demo data in the prototype.
class AppSettings {
  const AppSettings({
    this.theme = ThemeMode.dark,
    this.accent = Accent.blue,
    this.highContrast = false,
    this.textScale = 1.0,
    this.billingScale = 1.0,
    this.density = DensityMode.normal,
    this.font = FontChoice.inter,
    this.motion = MotionLevel.gentle,
    this.followSystemMotion = true,
    this.motionAutoReduced = false,
    this.soundScan = true,
    this.soundSave = false,
    this.soundError = false,
    this.soundVolume = 0.7,
    this.paper = PaperSize.a4,
    this.printSize = PrintTextSize.small,
    this.sync = SyncState.synced,
    this.firstRunDone = true,
    this.signedIn = true,
  });
  final ThemeMode theme;
  final Accent accent;
  final bool highContrast;
  final double textScale, billingScale;
  final DensityMode density;
  final FontChoice font;
  final MotionLevel motion;
  final bool followSystemMotion, motionAutoReduced;
  final bool soundScan, soundSave, soundError;
  final double soundVolume;
  final PaperSize paper;
  final PrintTextSize printSize;
  final bool firstRunDone, signedIn;
  final SyncState sync;

  AppSettings copyWith({
    ThemeMode? theme,
    Accent? accent,
    bool? highContrast,
    double? textScale,
    double? billingScale,
    DensityMode? density,
    FontChoice? font,
    MotionLevel? motion,
    bool? followSystemMotion,
    bool? motionAutoReduced,
    bool? soundScan,
    bool? soundSave,
    bool? soundError,
    double? soundVolume,
    PaperSize? paper,
    PrintTextSize? printSize,
    bool? pricesIncludeGst,
    CreditLimitMode? creditLimitMode,
    ReminderTone? reminderTone,
    String? templateFriendly,
    String? templateFirm,
    String? shopPhone,
    String? upiId,
    int? guardHours,
    String? countryCode,
    String? shopName,
    String? gstin,
    SyncState? sync,
    bool? firstRunDone,
    bool? signedIn,
  }) =>
      AppSettings(
        theme: theme ?? this.theme,
        accent: accent ?? this.accent,
        highContrast: highContrast ?? this.highContrast,
        textScale: textScale ?? this.textScale,
        billingScale: billingScale ?? this.billingScale,
        density: density ?? this.density,
        font: font ?? this.font,
        motion: motion ?? this.motion,
        followSystemMotion: followSystemMotion ?? this.followSystemMotion,
        motionAutoReduced: motionAutoReduced ?? this.motionAutoReduced,
        soundScan: soundScan ?? this.soundScan,
        soundSave: soundSave ?? this.soundSave,
        soundError: soundError ?? this.soundError,
        soundVolume: soundVolume ?? this.soundVolume,
        paper: paper ?? this.paper,
        printSize: printSize ?? this.printSize,
        sync: sync ?? this.sync,
        firstRunDone: firstRunDone ?? this.firstRunDone,
        signedIn: signedIn ?? this.signedIn,
      );

  Map<String, Object?> toJson() => {
        'theme': theme.name,
        'accent': accent.name,
        'highContrast': highContrast,
        'textScale': textScale,
        'billingScale': billingScale,
        'density': density.name,
        'font': font.name,
        'motion': motion.name,
        'followSystemMotion': followSystemMotion,
        'motionAutoReduced': motionAutoReduced,
        'soundScan': soundScan,
        'soundSave': soundSave,
        'soundError': soundError,
        'soundVolume': soundVolume,
        'paper': paper.name,
        'printSize': printSize.name,
      };

  /// SECURITY: tolerant and strict at once. Unknown keys are ignored; wrong types, unknown names and out-of-range or non-finite numbers
  /// fall back to the defaults. Nothing about permissions or trust is read from here (see docs/threat-model.md).
  static AppSettings fromJson(Map<String, Object?> j) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) => values.firstWhere((v) => v.name == name, orElse: () => fallback);
    double num_(Object? v, double min, double max, double fallback) => v is num && v.isFinite && v >= min && v <= max ? v.toDouble() : fallback; // out of range or not a number: the default
    bool bool_(Object? v, bool fallback) => v is bool ? v : fallback;
    const d = AppSettings();
    return AppSettings(
      theme: pick(ThemeMode.values, j['theme'], d.theme),
      accent: pick(Accent.values, j['accent'], d.accent),
      highContrast: bool_(j['highContrast'], d.highContrast),
      textScale: num_(j['textScale'], 0.8, 2.0, d.textScale),
      billingScale: num_(j['billingScale'], 0.8, 2.5, d.billingScale),
      density: pick(DensityMode.values, j['density'], d.density),
      font: pick(FontChoice.values, j['font'], d.font),
      motion: pick(MotionLevel.values, j['motion'], d.motion),
      followSystemMotion: bool_(j['followSystemMotion'], d.followSystemMotion),
      motionAutoReduced: bool_(j['motionAutoReduced'], d.motionAutoReduced),
      soundScan: bool_(j['soundScan'], d.soundScan),
      soundSave: bool_(j['soundSave'], d.soundSave),
      soundError: bool_(j['soundError'], d.soundError),
      soundVolume: num_(j['soundVolume'], 0, 1, d.soundVolume),
      paper: pick(PaperSize.values, j['paper'], d.paper),
      printSize: pick(PrintTextSize.values, j['printSize'], d.printSize),
    );
  }
}

/// Where this device keeps its settings. The app overrides it with the real store; tests use memory.
final deviceStoreProvider = Provider<DeviceStore>((ref) => MemoryDeviceStore());

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.fromJson(ref.read(deviceStoreProvider).load());

  void set(AppSettings Function(AppSettings) f) {
    state = f(state);
    ref.read(deviceStoreProvider).save(state.toJson());
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
