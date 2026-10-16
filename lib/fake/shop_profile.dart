/// The shop's own details: one profile for the whole shop. In Phase 2 it syncs between the shop's devices (settingsShared);
/// per-device preferences (text size, theme, printer...) live in AppSettings and never sync.
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/credit/reminder.dart';
import 'data_providers.dart';
import 'store.dart' show CreditLimitMode;

/// What the shop chooses to print on an ESTIMATE. All off by default: an estimate is a rough price for the customer.
class EstimateShows {
  const EstimateShows({this.shopName = false, this.address = false, this.gstin = false, this.phone = false, this.number = false, this.taxLines = false});
  final bool shopName, address, gstin, phone, number, taxLines;

  Map<String, Object?> toJson() => {'shopName': shopName, 'address': address, 'gstin': gstin, 'phone': phone, 'number': number, 'taxLines': taxLines};

  static EstimateShows fromJson(Object? j) {
    final m = j is Map ? j : const {};
    bool b(String k) => m[k] == true;
    return EstimateShows(shopName: b('shopName'), address: b('address'), gstin: b('gstin'), phone: b('phone'), number: b('number'), taxLines: b('taxLines'));
  }

  EstimateShows copyWith({bool? shopName, bool? address, bool? gstin, bool? phone, bool? number, bool? taxLines}) => EstimateShows(
        shopName: shopName ?? this.shopName,
        address: address ?? this.address,
        gstin: gstin ?? this.gstin,
        phone: phone ?? this.phone,
        number: number ?? this.number,
        taxLines: taxLines ?? this.taxLines,
      );
}

class ShopProfile {
  const ShopProfile({
    this.name = '',
    this.ownerName = '',
    this.address = '',
    this.phone = '',
    this.gstin = '',
    this.upiId = '',
    this.bankDetails = '',
    this.billFooter = 'Thank you. Visit again.',
    this.invoicePrefix = '',
    this.pricesIncludeGst = true,
    this.roundOff = true,
    this.logoPng = '',
    this.estimate = const EstimateShows(),
    this.creditLimitMode = CreditLimitMode.warn,
    this.reminderTone = ReminderTone.friendly,
    this.templateFriendly = defaultFriendlyTemplate,
    this.templateFirm = defaultFirmTemplate,
    this.guardHours = 24,
    this.countryCode = '91',
    this.openingCashPaise = 0,
  });

  /// The made-up shop of the demo mode (never used for a real shop, whose profile starts empty and is filled in by the set-up).
  static const sample = ShopProfile(
    name: 'Senthil Enterprises',
    ownerName: 'Senthil Kumar',
    address: '12 Market Street, Coimbatore - 641001',
    phone: '98765 43210',
    gstin: '33AAAAA0000A1Z5',
    upiId: 'senthil@okbank',
    bankDetails: 'Sample Bank, A/c 0000000000, IFSC SAMP0000000',
    openingCashPaise: 500000,
  );

  final String name, ownerName, address, phone, gstin, upiId, bankDetails, billFooter, invoicePrefix;
  final bool pricesIncludeGst;

  /// Round each bill total to the nearest rupee (the difference is printed as Round off). Off: the exact total.
  final bool roundOff;

  /// The shop's own logo as a small PNG in base64 (empty = the program's logo). Made by `prepareLogo`.
  final String logoPng;
  final EstimateShows estimate;
  final CreditLimitMode creditLimitMode;
  final ReminderTone reminderTone;
  final String templateFriendly, templateFirm, countryCode;
  final int guardHours;

  /// Cash in the drawer at the start of each day (the day closing starts from it).
  final int openingCashPaise;

  Map<String, Object?> toJson() => {
        'name': name,
        'ownerName': ownerName,
        'address': address,
        'phone': phone,
        'gstin': gstin,
        'upiId': upiId,
        'bankDetails': bankDetails,
        'billFooter': billFooter,
        'invoicePrefix': invoicePrefix,
        'pricesIncludeGst': pricesIncludeGst,
        'roundOff': roundOff,
        'logoPng': logoPng,
        'estimate': estimate.toJson(),
        'creditLimitMode': creditLimitMode.name,
        'reminderTone': reminderTone.name,
        'templateFriendly': templateFriendly,
        'templateFirm': templateFirm,
        'guardHours': guardHours,
        'countryCode': countryCode,
        'openingCashPaise': openingCashPaise,
      };

  /// Tolerant: anything missing or of the wrong type keeps the default (a damaged value never stops the program from starting).
  static ShopProfile fromJson(Object? j, {ShopProfile base = const ShopProfile()}) {
    final m = j is Map ? j : const {};
    String str(String k, String d) => m[k] is String ? m[k] as String : d;
    return ShopProfile(
      name: str('name', base.name),
      ownerName: str('ownerName', base.ownerName),
      address: str('address', base.address),
      phone: str('phone', base.phone),
      gstin: str('gstin', base.gstin),
      upiId: str('upiId', base.upiId),
      bankDetails: str('bankDetails', base.bankDetails),
      billFooter: str('billFooter', base.billFooter),
      invoicePrefix: str('invoicePrefix', base.invoicePrefix),
      pricesIncludeGst: m['pricesIncludeGst'] is bool ? m['pricesIncludeGst'] as bool : base.pricesIncludeGst,
      roundOff: m['roundOff'] is bool ? m['roundOff'] as bool : base.roundOff,
      logoPng: m['logoPng'] is String && (m['logoPng'] as String).length <= 300000 ? m['logoPng'] as String : base.logoPng,
      estimate: m.containsKey('estimate') ? EstimateShows.fromJson(m['estimate']) : base.estimate,
      creditLimitMode: CreditLimitMode.values.firstWhere((e) => e.name == m['creditLimitMode'], orElse: () => base.creditLimitMode),
      reminderTone: ReminderTone.values.firstWhere((e) => e.name == m['reminderTone'], orElse: () => base.reminderTone),
      templateFriendly: str('templateFriendly', base.templateFriendly),
      templateFirm: str('templateFirm', base.templateFirm),
      guardHours: m['guardHours'] is int && (m['guardHours'] as int) >= 0 && (m['guardHours'] as int) <= 720 ? m['guardHours'] as int : base.guardHours,
      countryCode: str('countryCode', base.countryCode),
      openingCashPaise: m['openingCashPaise'] is int && (m['openingCashPaise'] as int) >= 0 && (m['openingCashPaise'] as int) <= 100000000000 ? m['openingCashPaise'] as int : base.openingCashPaise,
    );
  }

  String toJsonText() => jsonEncode(toJson());

  ShopProfile copyWith({
    String? name,
    String? ownerName,
    String? address,
    String? phone,
    String? gstin,
    String? upiId,
    String? bankDetails,
    String? billFooter,
    String? invoicePrefix,
    bool? pricesIncludeGst,
    bool? roundOff,
    String? logoPng,
    EstimateShows? estimate,
    CreditLimitMode? creditLimitMode,
    ReminderTone? reminderTone,
    String? templateFriendly,
    String? templateFirm,
    int? guardHours,
    String? countryCode,
    int? openingCashPaise,
  }) =>
      ShopProfile(
        name: name ?? this.name,
        ownerName: ownerName ?? this.ownerName,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        gstin: gstin ?? this.gstin,
        upiId: upiId ?? this.upiId,
        bankDetails: bankDetails ?? this.bankDetails,
        billFooter: billFooter ?? this.billFooter,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        pricesIncludeGst: pricesIncludeGst ?? this.pricesIncludeGst,
        roundOff: roundOff ?? this.roundOff,
        logoPng: logoPng ?? this.logoPng,
        estimate: estimate ?? this.estimate,
        creditLimitMode: creditLimitMode ?? this.creditLimitMode,
        reminderTone: reminderTone ?? this.reminderTone,
        templateFriendly: templateFriendly ?? this.templateFriendly,
        templateFirm: templateFirm ?? this.templateFirm,
        guardHours: guardHours ?? this.guardHours,
        countryCode: countryCode ?? this.countryCode,
        openingCashPaise: openingCashPaise ?? this.openingCashPaise,
      );
}

class ShopNotifier extends Notifier<ShopProfile> {
  @override
  ShopProfile build() => ref.read(bootstrapProvider).shop;

  /// Changes the shop profile: the screen updates at once and the change is written (and queued to sync) right behind.
  void set(ShopProfile Function(ShopProfile) change) {
    state = change(state);
    final text = state.toJsonText();
    ref.read(writeQueueProvider).add(() => ref.read(appDataProvider).settings.put('shop.profile', text, upload: true));
  }
}

final shopProvider = NotifierProvider<ShopNotifier, ShopProfile>(ShopNotifier.new);
