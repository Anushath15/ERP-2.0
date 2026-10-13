/// The shop's own details: one profile for the whole shop. In Phase 2 it syncs between the shop's devices (settingsShared);
/// per-device preferences (text size, theme, printer...) live in AppSettings and never sync.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/credit/reminder.dart';
import 'store.dart' show CreditLimitMode;

/// What the shop chooses to print on an ESTIMATE. All off by default: an estimate is a rough price for the customer.
class EstimateShows {
  const EstimateShows({this.shopName = false, this.address = false, this.gstin = false, this.phone = false, this.number = false, this.taxLines = false});
  final bool shopName, address, gstin, phone, number, taxLines;

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
    this.name = 'Senthil Enterprises',
    this.ownerName = 'Senthil Kumar',
    this.address = '12 Market Street, Coimbatore - 641001',
    this.phone = '98765 43210',
    this.gstin = '33AAAAA0000A1Z5',
    this.upiId = 'senthil@okbank',
    this.bankDetails = 'Sample Bank, A/c 0000000000, IFSC SAMP0000000',
    this.billFooter = 'Thank you. Visit again.',
    this.invoicePrefix = 'A-',
    this.pricesIncludeGst = true,
    this.estimate = const EstimateShows(),
    this.creditLimitMode = CreditLimitMode.warn,
    this.reminderTone = ReminderTone.friendly,
    this.templateFriendly = defaultFriendlyTemplate,
    this.templateFirm = defaultFirmTemplate,
    this.guardHours = 24,
    this.countryCode = '91',
  });

  final String name, ownerName, address, phone, gstin, upiId, bankDetails, billFooter, invoicePrefix;
  final bool pricesIncludeGst;
  final EstimateShows estimate;
  final CreditLimitMode creditLimitMode;
  final ReminderTone reminderTone;
  final String templateFriendly, templateFirm, countryCode;
  final int guardHours;

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
    EstimateShows? estimate,
    CreditLimitMode? creditLimitMode,
    ReminderTone? reminderTone,
    String? templateFriendly,
    String? templateFirm,
    int? guardHours,
    String? countryCode,
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
        estimate: estimate ?? this.estimate,
        creditLimitMode: creditLimitMode ?? this.creditLimitMode,
        reminderTone: reminderTone ?? this.reminderTone,
        templateFriendly: templateFriendly ?? this.templateFriendly,
        templateFirm: templateFirm ?? this.templateFirm,
        guardHours: guardHours ?? this.guardHours,
        countryCode: countryCode ?? this.countryCode,
      );
}

class ShopNotifier extends Notifier<ShopProfile> {
  @override
  ShopProfile build() => const ShopProfile();

  void set(ShopProfile Function(ShopProfile) change) => state = change(state);
}

final shopProvider = NotifierProvider<ShopNotifier, ShopProfile>(ShopNotifier.new);
