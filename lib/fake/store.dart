/// In-memory "database" for the prototype: Riverpod providers over the seed data. Nothing is saved to disk.
library;

import 'package:flutter/material.dart' show ThemeMode;
import '../core/device_store.dart';
import '../core/validators.dart' show cleanText;
import '../domain/credit/reminder.dart';
import '../design/motion_level.dart';
import '../design/tokens.dart' show Accent, DensityMode, FontChoice;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import '../data/app_data.dart';
import '../data/repo/records_repo.dart' show EstimateLine;
import 'data_providers.dart';

final clockProvider = Provider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, n.hour, n.minute);
});

/// Starts a write behind the scenes: the screen already shows the change, the database gets it right after (in order).
void _write(Ref ref, Future<void> Function(AppData d) job) => ref.read(writeQueueProvider).add(() => job(ref.read(appDataProvider)));

class ProductsNotifier extends Notifier<List<Product>> {
  @override
  List<Product> build() => ref.read(bootstrapProvider).products;

  void add(Product p) {
    state = [p, ...state];
    _write(ref, (d) async {
      await d.catalog.saveProduct(p, create: true);
      // the product code is made inside the save: show it as soon as it exists
      final saved = await d.catalog.product(p.id);
      if (saved != null && ref.mounted) state = [for (final x in state) x.id == p.id ? saved : x];
    });
  }

  void update(Product p) {
    state = [for (final x in state) x.id == p.id ? p : x];
    _write(ref, (d) => d.catalog.saveProduct(p, create: false));
  }

  /// Reads every product again from the database (after many were changed or added at once, for example from an Excel sheet).
  Future<void> reloadAll() async {
    final all = await ref.read(appDataProvider).catalog.products();
    if (ref.mounted) state = all;
  }

  /// Reads the named products again from the database (their stock changed: a sale, a purchase, a stock change).
  Future<void> reload(Iterable<String> ids) async {
    final d = ref.read(appDataProvider);
    final fresh = <String, Product>{};
    for (final id in ids.toSet()) {
      final p = await d.catalog.product(id);
      if (p != null) fresh[id] = p;
    }
    state = [for (final x in state) fresh[x.id] ?? x];
  }
}

final productsProvider = NotifierProvider<ProductsNotifier, List<Product>>(ProductsNotifier.new);

class CustomersNotifier extends Notifier<List<Customer>> {
  @override
  List<Customer> build() => ref.read(bootstrapProvider).customers;

  void add(Customer c) {
    state = [c, ...state];
    _write(ref, (d) => d.catalog.saveCustomer(c, create: true));
  }

  void update(Customer c) {
    state = [for (final x in state) x.id == c.id ? c : x];
    _write(ref, (d) => d.catalog.saveCustomer(c, create: false));
  }

  void updatePhone(String id, String phone) {
    final c = state.firstWhere((x) => x.id == id);
    update(c.copyWith(phone: phone));
  }

  /// What the customer owes now (after a bill, a payment or an adjustment). The balance itself lives in the ledger; this keeps the list in step.
  void setBalance(String id, int balancePaise) {
    state = [for (final c in state) c.id == id ? Customer(id: c.id, name: c.name, phone: c.phone, city: c.city, balancePaise: balancePaise, creditLimitPaise: c.creditLimitPaise, address: c.address, gstin: c.gstin) : c];
  }
}

final customersProvider = NotifierProvider<CustomersNotifier, List<Customer>>(CustomersNotifier.new);

class EstimationsNotifier extends Notifier<List<EstimationDoc>> {
  @override
  List<EstimationDoc> build() => ref.read(bootstrapProvider).estimations;

  Future<void> reload() async => state = await ref.read(appDataProvider).estimations.list();

  /// Saves a new estimate (or [editNumber] in place). Returns what was saved, with its number.
  Future<EstimationDoc> save({required List<EstimateLine> lines, required int totalPaise, required String customerName, String? customerId, required DateTime at, String? editNumber, int extraDiscountPaise = 0, int extraDiscountBp = 0}) async {
    final d = ref.read(appDataProvider);
    final doc = await ref.read(writeQueueProvider).run(() => d.estimations.save(lines: lines, totalPaise: totalPaise, customerName: customerName, customerId: customerId, at: at, editNumber: editNumber, extraDiscountPaise: extraDiscountPaise, extraDiscountBp: extraDiscountBp));
    await reload();
    await ref.read(nextNumbersProvider.notifier).refresh();
    return doc;
  }

  Future<void> markConverted(String number, String billNumber) async {
    final d = ref.read(appDataProvider);
    await ref.read(writeQueueProvider).run(() => d.estimations.markConverted(number, billNumber));
    await reload();
  }

  Future<void> remove(String number, {String reason = ''}) async {
    state = [for (final x in state) if (x.number != number) x];
    final d = ref.read(appDataProvider);
    await ref.read(writeQueueProvider).run(() => d.estimations.remove(number, reason: reason));
  }
}

final estimationsProvider = NotifierProvider<EstimationsNotifier, List<EstimationDoc>>(EstimationsNotifier.new);

/// The number the next bill and the next estimate will get (shown before saving; the real number is taken inside the save).
class NextNumbers {
  const NextNumbers(this.invoice, this.estimate);
  final String invoice, estimate;
}

class NextNumbersNotifier extends Notifier<NextNumbers> {
  @override
  NextNumbers build() {
    final b = ref.read(bootstrapProvider);
    return NextNumbers(b.nextInvoice, b.nextEstimate);
  }

  Future<void> refresh() async {
    final d = ref.read(appDataProvider);
    state = NextNumbers(await d.bills.peekNextNumber(), await d.estimations.peekNextNumber());
  }
}

final nextNumbersProvider = NotifierProvider<NextNumbersNotifier, NextNumbers>(NextNumbersNotifier.new);

/// Generic record lists (dealers, purchases, expenses, ...), keyed by kind. Dealers, categories and stock changes live in their own
/// tables; everything else is a small record each.
class RecsNotifier extends Notifier<List<Rec>> {
  RecsNotifier(this.kind);
  final String kind;

  @override
  List<Rec> build() => kind == 'dealers' ? ref.read(bootstrapProvider).dealers : (kind == 'categories' ? ref.read(bootstrapProvider).categories : (ref.read(bootstrapProvider).recs[kind] ?? const []));

  void add(Rec r) {
    state = [r, ...state];
    switch (kind) {
      case 'dealers':
        _write(ref, (d) => d.catalog.saveDealer(r, create: true));
      case 'categories':
        _write(ref, (d) => d.catalog.addCategory(r.s('name')));
      case 'adjustments':
        final product = ref.read(productsProvider).where((p) => p.name == r.s('product')).firstOrNull;
        if (product == null) return;
        _write(ref, (d) async {
          await d.stock.adjust(productId: product.id, qtyMilli: r.i('qty'), reason: r.s('reason'), at: (r.f['date'] as DateTime?) ?? ref.read(clockProvider));
          await ref.read(productsProvider.notifier).reload([product.id]);
        });
      case 'purchases' || 'salesReturns' || 'purchaseReturns' || 'orders':
        final (prefix, width) = switch (kind) { 'purchases' => ('PUR', 5), 'salesReturns' => ('SRT', 4), 'orders' => ('PO', 4), _ => ('PRT', 4) };
        _write(ref, (d) async {
          final saved = await d.records.putNumbered(kind, r, prefix: prefix, width: width);
          state = [for (final x in state) x.id == saved.id ? saved : x]; // now it has its real number
        });
      default:
        _write(ref, (d) => d.records.put(kind, r, create: true));
    }
  }

  /// Shows a record that was already written elsewhere (nothing is saved here).
  void showOnly(Rec r) => state = [r, ...state];

  /// Reads this kind again from the database (after a record came back from the Trash).
  Future<void> reload() async {
    if (kind == 'dealers' || kind == 'categories' || kind == 'adjustments') return;
    state = await ref.read(appDataProvider).records.list(kind);
  }

  void replace(Rec r) {
    state = [for (final x in state) x.id == r.id ? r : x];
    switch (kind) {
      case 'dealers':
        _write(ref, (d) => d.catalog.saveDealer(r, create: false));
      case 'categories' || 'adjustments':
        break; // a category name or a stock change is not edited
      default:
        _write(ref, (d) => d.records.put(kind, r, create: false));
    }
  }

  void remove(String id) {
    state = [for (final x in state) if (x.id != id) x];
    if (kind != 'dealers' && kind != 'categories' && kind != 'adjustments') _write(ref, (d) => d.records.remove(id));
  }

  /// A dealer's balance changed (a purchase on credit, a payment): keeps the dealer list in step.
  void setBalance(String id, int balancePaise) {
    state = [for (final x in state) x.id == id ? x.with_({'balance': balancePaise}) : x];
  }
}

final recsProvider = NotifierProvider.family<RecsNotifier, List<Rec>, String>(RecsNotifier.new);

// ---------------- settings (per device; never synced) ----------------
enum PaperSize { a4, a5, mm80, mm58 }

/// How big the printed bill and estimate text is. Small is the default.
enum PrintTextSize { smaller, small, normal }

enum SyncState { synced, syncing, offline, attention, paused }

/// How roll bills reach a thermal receipt printer: the normal way (a PDF through the printer's driver), or straight in the printer's own
/// language (ESC/POS) to the bill printer Windows knows, or to a network printer by its address.
enum ThermalLink { off, windows, network }

/// What to do when a bill would take a customer over their credit limit (the owner chooses in Settings).
enum CreditLimitMode { off, warn, block }

/// Everything in here is remembered on THIS device only (see DeviceStore). Shop details are demo data in the prototype.
/// Parts of the program that can be switched off on one computer (Settings > Features). Everything is on by default; a switched-off part is hidden, nothing in
/// the data changes.
enum AppFeature { counterLink, excelFill, brandSwitch }

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
    this.printerName = '',
    this.labelPrinterName = '',
    this.printViaDialog = false,
    this.printAfterSave = true,
    this.printAsPicture = false,
    this.thermal = ThermalLink.off,
    this.thermalAddress = '',
    this.thermalChars = 0,
    this.thermalCut = true,
    this.thermalDrawer = false,
    this.featuresOff = const {},
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

  /// The printer this computer prints bills on (as Windows names it); empty = the computer's default printer.
  final String printerName;

  /// The printer for barcode stickers (a label printer); empty = the same printer as the bills.
  final String labelPrinterName;

  /// Print through the Windows print window (for printers whose driver refuses direct jobs), and print at once after Save and print.
  final bool printViaDialog, printAfterSave;

  /// Send each page as one picture (for printer drivers that take the bill but print nothing). Slower; the same look on paper.
  final bool printAsPicture;

  /// Thermal receipt printer, direct (used only when the paper is 80 mm or 58 mm): how it is reached, the network printer's address
  /// (192.168.1.50:9100), letters per line (0 = by the paper: 48 on 80 mm, 32 on 58 mm), cut the paper, open the cash drawer for cash bills.
  final ThermalLink thermal;
  final String thermalAddress;
  final int thermalChars;
  final bool thermalCut, thermalDrawer;

  /// Features switched off on this computer (see [AppFeature]); empty = everything on.
  final Set<String> featuresOff;

  bool featureOn(AppFeature f) => !featuresOff.contains(f.name);
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
    String? printerName,
    String? labelPrinterName,
    bool? printViaDialog,
    bool? printAfterSave,
    bool? printAsPicture,
    ThermalLink? thermal,
    String? thermalAddress,
    int? thermalChars,
    bool? thermalCut,
    bool? thermalDrawer,
    Set<String>? featuresOff,
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
        printerName: printerName ?? this.printerName,
        labelPrinterName: labelPrinterName ?? this.labelPrinterName,
        printViaDialog: printViaDialog ?? this.printViaDialog,
        printAfterSave: printAfterSave ?? this.printAfterSave,
        printAsPicture: printAsPicture ?? this.printAsPicture,
        thermal: thermal ?? this.thermal,
        thermalAddress: thermalAddress ?? this.thermalAddress,
        thermalChars: thermalChars ?? this.thermalChars,
        thermalCut: thermalCut ?? this.thermalCut,
        thermalDrawer: thermalDrawer ?? this.thermalDrawer,
        featuresOff: featuresOff ?? this.featuresOff,
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
        'printerName': printerName,
        'labelPrinterName': labelPrinterName,
        'printViaDialog': printViaDialog,
        'printAfterSave': printAfterSave,
        'printAsPicture': printAsPicture,
        'thermal': thermal.name,
        'thermalAddress': thermalAddress,
        'thermalChars': thermalChars,
        'thermalCut': thermalCut,
        'thermalDrawer': thermalDrawer,
        'featuresOff': featuresOff.toList()..sort(),
      };

  /// SECURITY: tolerant and strict at once. Unknown keys are ignored; wrong types, unknown names and out-of-range or non-finite numbers
  /// fall back to the defaults. Nothing about permissions or trust is read from here (see docs/threat-model.md).
  static AppSettings fromJson(Map<String, Object?> j) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) => values.firstWhere((v) => v.name == name, orElse: () => fallback);
    double num_(Object? v, double min, double max, double fallback) => v is num && v.isFinite && v >= min && v <= max ? v.toDouble() : fallback; // out of range or not a number: the default
    bool bool_(Object? v, bool fallback) => v is bool ? v : fallback;
    String name_(Object? v, String fallback) {
      if (v is! String) return fallback;
      final t = cleanText(v); // no control characters, no line breaks
      return t.length > 120 ? t.substring(0, 120) : t;
    }
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
      printerName: name_(j['printerName'], d.printerName),
      labelPrinterName: name_(j['labelPrinterName'], d.labelPrinterName),
      printViaDialog: bool_(j['printViaDialog'], d.printViaDialog),
      printAfterSave: bool_(j['printAfterSave'], d.printAfterSave),
      printAsPicture: bool_(j['printAsPicture'], d.printAsPicture),
      thermal: pick(ThermalLink.values, j['thermal'], d.thermal),
      thermalAddress: name_(j['thermalAddress'], d.thermalAddress),
      thermalChars: const [0, 32, 42, 48].contains(j['thermalChars']) ? j['thermalChars'] as int : d.thermalChars,
      thermalCut: bool_(j['thermalCut'], d.thermalCut),
      thermalDrawer: bool_(j['thermalDrawer'], d.thermalDrawer),
      featuresOff: {for (final x in (j['featuresOff'] is List ? j['featuresOff'] as List : const [])) if (x is String && AppFeature.values.any((f) => f.name == x)) x},
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

/// Set when Save and print just saved a document and opened the Print page: the page prints it once, at once (see [AppSettings.printAfterSave]).
class AutoPrintNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final autoPrintProvider = NotifierProvider<AutoPrintNotifier, bool>(AutoPrintNotifier.new);
