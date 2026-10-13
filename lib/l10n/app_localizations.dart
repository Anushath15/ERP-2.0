import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ta'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Senthil Enterprises'**
  String get appName;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addNew.
  ///
  /// In en, this message translates to:
  /// **'Add new'**
  String get addNew;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Make a copy'**
  String get duplicate;

  /// No description provided for @duplicated.
  ///
  /// In en, this message translates to:
  /// **'A copy was made'**
  String get duplicated;

  /// No description provided for @print.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get print;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill this in'**
  String get fieldRequired;

  /// No description provided for @searchHere.
  ///
  /// In en, this message translates to:
  /// **'Search here'**
  String get searchHere;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortBy;

  /// No description provided for @sortDefault.
  ///
  /// In en, this message translates to:
  /// **'Normal order'**
  String get sortDefault;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @nothingFoundHelp.
  ///
  /// In en, this message translates to:
  /// **'Try a shorter word, or clear the filter.'**
  String get nothingFoundHelp;

  /// No description provided for @nothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHere;

  /// No description provided for @resultCount.
  ///
  /// In en, this message translates to:
  /// **'{count} shown'**
  String resultCount(String count);

  /// No description provided for @demoOnly.
  ///
  /// In en, this message translates to:
  /// **'This is a preview. This part does not work yet.'**
  String get demoOnly;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get chooseFile;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langTamil.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get langTamil;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navDashboard;

  /// No description provided for @navNewBill.
  ///
  /// In en, this message translates to:
  /// **'New bill'**
  String get navNewBill;

  /// No description provided for @navNewEstimate.
  ///
  /// In en, this message translates to:
  /// **'New estimate'**
  String get navNewEstimate;

  /// No description provided for @navSavedEstimates.
  ///
  /// In en, this message translates to:
  /// **'Saved estimates'**
  String get navSavedEstimates;

  /// No description provided for @navSalesRegister.
  ///
  /// In en, this message translates to:
  /// **'Sales register'**
  String get navSalesRegister;

  /// No description provided for @navSalesReturns.
  ///
  /// In en, this message translates to:
  /// **'Sales returns'**
  String get navSalesReturns;

  /// No description provided for @navDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get navDelivery;

  /// No description provided for @navProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get navProducts;

  /// No description provided for @navCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get navCategories;

  /// No description provided for @navInventory.
  ///
  /// In en, this message translates to:
  /// **'Stock left'**
  String get navInventory;

  /// No description provided for @navPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get navPurchases;

  /// No description provided for @navPurchaseReturns.
  ///
  /// In en, this message translates to:
  /// **'Purchase returns'**
  String get navPurchaseReturns;

  /// No description provided for @navAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Stock changes'**
  String get navAdjustments;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @navDealers.
  ///
  /// In en, this message translates to:
  /// **'Dealers'**
  String get navDealers;

  /// No description provided for @navCredit.
  ///
  /// In en, this message translates to:
  /// **'Money to collect'**
  String get navCredit;

  /// No description provided for @navStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get navStaff;

  /// No description provided for @navExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get navExpenses;

  /// No description provided for @navClosing.
  ///
  /// In en, this message translates to:
  /// **'Daily closing'**
  String get navClosing;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get navExport;

  /// No description provided for @navWarranty.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get navWarranty;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'House projects'**
  String get navProjects;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @navImport.
  ///
  /// In en, this message translates to:
  /// **'Import old data'**
  String get navImport;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navHealth.
  ///
  /// In en, this message translates to:
  /// **'Database health'**
  String get navHealth;

  /// No description provided for @navHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get navHelp;

  /// No description provided for @navAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get navAbout;

  /// No description provided for @navBill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get navBill;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @groupSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get groupSales;

  /// No description provided for @groupStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get groupStock;

  /// No description provided for @groupPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get groupPeople;

  /// No description provided for @groupMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get groupMoney;

  /// No description provided for @groupMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get groupMore;

  /// No description provided for @syncSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncSynced;

  /// No description provided for @syncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncSyncing;

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline - saved on this PC'**
  String get syncOffline;

  /// No description provided for @syncAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention ({count})'**
  String syncAttention(String count);

  /// No description provided for @lastSyncedAt.
  ///
  /// In en, this message translates to:
  /// **'Last synced at {time}'**
  String lastSyncedAt(String time);

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @colProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get colProduct;

  /// No description provided for @colItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get colItem;

  /// No description provided for @colPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get colPrice;

  /// No description provided for @colStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get colStock;

  /// No description provided for @colQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get colQty;

  /// No description provided for @colRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get colRate;

  /// No description provided for @colAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get colAmount;

  /// No description provided for @colDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get colDate;

  /// No description provided for @colNo.
  ///
  /// In en, this message translates to:
  /// **'No.'**
  String get colNo;

  /// No description provided for @colBillNo.
  ///
  /// In en, this message translates to:
  /// **'Bill no.'**
  String get colBillNo;

  /// No description provided for @colEstNo.
  ///
  /// In en, this message translates to:
  /// **'Estimate no.'**
  String get colEstNo;

  /// No description provided for @colCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get colCustomer;

  /// No description provided for @colStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get colStatus;

  /// No description provided for @colPayMode.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get colPayMode;

  /// No description provided for @colCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get colCategory;

  /// No description provided for @colCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get colCost;

  /// No description provided for @colValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get colValue;

  /// No description provided for @colOwes.
  ///
  /// In en, this message translates to:
  /// **'Owes'**
  String get colOwes;

  /// No description provided for @colWeOwe.
  ///
  /// In en, this message translates to:
  /// **'We owe'**
  String get colWeOwe;

  /// No description provided for @colSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get colSpent;

  /// No description provided for @colWarrantyTill.
  ///
  /// In en, this message translates to:
  /// **'Valid till'**
  String get colWarrantyTill;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get fieldPhone;

  /// No description provided for @fieldCity.
  ///
  /// In en, this message translates to:
  /// **'Town'**
  String get fieldCity;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get fieldNote;

  /// No description provided for @fieldReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get fieldReason;

  /// No description provided for @fieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fieldAmount;

  /// No description provided for @fieldPayMode.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get fieldPayMode;

  /// No description provided for @fieldRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get fieldRole;

  /// No description provided for @fieldProductName.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get fieldProductName;

  /// No description provided for @fieldSellPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price'**
  String get fieldSellPrice;

  /// No description provided for @fieldCostPrice.
  ///
  /// In en, this message translates to:
  /// **'Cost price'**
  String get fieldCostPrice;

  /// No description provided for @fieldUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get fieldUnit;

  /// No description provided for @fieldGst.
  ///
  /// In en, this message translates to:
  /// **'GST'**
  String get fieldGst;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @fieldStockNow.
  ///
  /// In en, this message translates to:
  /// **'Stock now'**
  String get fieldStockNow;

  /// No description provided for @fieldBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get fieldBarcode;

  /// No description provided for @fieldCreditLimit.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get fieldCreditLimit;

  /// No description provided for @fieldDealerInvoice.
  ///
  /// In en, this message translates to:
  /// **'Dealer invoice no.'**
  String get fieldDealerInvoice;

  /// No description provided for @fieldSerial.
  ///
  /// In en, this message translates to:
  /// **'Serial no.'**
  String get fieldSerial;

  /// No description provided for @fieldBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get fieldBudget;

  /// No description provided for @fieldProjectName.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get fieldProjectName;

  /// No description provided for @productNameHint.
  ///
  /// In en, this message translates to:
  /// **'Type the name exactly as you want it'**
  String get productNameHint;

  /// No description provided for @filterInStock.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get filterInStock;

  /// No description provided for @filterLow.
  ///
  /// In en, this message translates to:
  /// **'Almost finished'**
  String get filterLow;

  /// No description provided for @filterOut.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get filterOut;

  /// No description provided for @filterOwing.
  ///
  /// In en, this message translates to:
  /// **'Owes money'**
  String get filterOwing;

  /// No description provided for @filterClear.
  ///
  /// In en, this message translates to:
  /// **'Nothing owed'**
  String get filterClear;

  /// No description provided for @filterWeOwe.
  ///
  /// In en, this message translates to:
  /// **'We owe'**
  String get filterWeOwe;

  /// No description provided for @statusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// No description provided for @statusPartly.
  ///
  /// In en, this message translates to:
  /// **'Part paid'**
  String get statusPartly;

  /// No description provided for @statusDue.
  ///
  /// In en, this message translates to:
  /// **'Not paid'**
  String get statusDue;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusConverted.
  ///
  /// In en, this message translates to:
  /// **'Made into bill'**
  String get statusConverted;

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get statusOpen;

  /// No description provided for @statusEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get statusEdited;

  /// No description provided for @statusReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get statusReceived;

  /// No description provided for @deliveryPending.
  ///
  /// In en, this message translates to:
  /// **'To send'**
  String get deliveryPending;

  /// No description provided for @deliveryOut.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get deliveryOut;

  /// No description provided for @sortPriceHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: high to low'**
  String get sortPriceHigh;

  /// No description provided for @sortStockLow.
  ///
  /// In en, this message translates to:
  /// **'Stock: low to high'**
  String get sortStockLow;

  /// No description provided for @sortValueHigh.
  ///
  /// In en, this message translates to:
  /// **'Value: high to low'**
  String get sortValueHigh;

  /// No description provided for @sortOwedHigh.
  ///
  /// In en, this message translates to:
  /// **'Owes most first'**
  String get sortOwedHigh;

  /// No description provided for @sortAmountHigh.
  ///
  /// In en, this message translates to:
  /// **'Amount: high to low'**
  String get sortAmountHigh;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Almost finished'**
  String get lowStock;

  /// No description provided for @inBillQty.
  ///
  /// In en, this message translates to:
  /// **'In bill: {qty}'**
  String inBillQty(String qty);

  /// No description provided for @searchProductHint.
  ///
  /// In en, this message translates to:
  /// **'Type name or scan barcode'**
  String get searchProductHint;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProduct;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Change product'**
  String get editProduct;

  /// No description provided for @addProductShortcut.
  ///
  /// In en, this message translates to:
  /// **'Add a new product (Ctrl+Shift+N)'**
  String get addProductShortcut;

  /// No description provided for @noProductFound.
  ///
  /// In en, this message translates to:
  /// **'No product found.'**
  String get noProductFound;

  /// No description provided for @addNamed.
  ///
  /// In en, this message translates to:
  /// **'+ Add {name}'**
  String addNamed(String name);

  /// No description provided for @saveAndAddToBill.
  ///
  /// In en, this message translates to:
  /// **'Save and add to bill'**
  String get saveAndAddToBill;

  /// No description provided for @productAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} was added'**
  String productAdded(String name);

  /// No description provided for @productsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} products'**
  String productsSubtitle(String count);

  /// No description provided for @noProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get noProductsYet;

  /// No description provided for @noProductsHelp.
  ///
  /// In en, this message translates to:
  /// **'Add your first product, or import your old list from Excel.'**
  String get noProductsHelp;

  /// No description provided for @inventorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How much of each item is left, and what it is worth'**
  String get inventorySubtitle;

  /// No description provided for @statStockValue.
  ///
  /// In en, this message translates to:
  /// **'Stock worth'**
  String get statStockValue;

  /// No description provided for @valuationRule.
  ///
  /// In en, this message translates to:
  /// **'At average cost price'**
  String get valuationRule;

  /// No description provided for @statItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get statItems;

  /// No description provided for @statLow.
  ///
  /// In en, this message translates to:
  /// **'Almost finished'**
  String get statLow;

  /// No description provided for @statOut.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get statOut;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @addAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Change stock'**
  String get addAdjustment;

  /// No description provided for @adjustmentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fix the stock when what you count is different'**
  String get adjustmentsSubtitle;

  /// No description provided for @adjustmentNote.
  ///
  /// In en, this message translates to:
  /// **'Use this when you count the shelf and find a different number. The reason is kept for your records.'**
  String get adjustmentNote;

  /// No description provided for @adjustKind.
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get adjustKind;

  /// No description provided for @adjustMinus.
  ///
  /// In en, this message translates to:
  /// **'Less than the computer shows'**
  String get adjustMinus;

  /// No description provided for @adjustPlus.
  ///
  /// In en, this message translates to:
  /// **'More than the computer shows'**
  String get adjustPlus;

  /// No description provided for @searchBillHint.
  ///
  /// In en, this message translates to:
  /// **'Search bill number or customer'**
  String get searchBillHint;

  /// No description provided for @walkInCustomer.
  ///
  /// In en, this message translates to:
  /// **'Walk-in customer'**
  String get walkInCustomer;

  /// No description provided for @chooseCustomer.
  ///
  /// In en, this message translates to:
  /// **'Choose customer'**
  String get chooseCustomer;

  /// No description provided for @searchCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Search name or phone'**
  String get searchCustomerHint;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get addCustomer;

  /// No description provided for @customerOwes.
  ///
  /// In en, this message translates to:
  /// **'Owes {amount}'**
  String customerOwes(String amount);

  /// No description provided for @editingKeeps.
  ///
  /// In en, this message translates to:
  /// **'Editing {number} dated {date}. The number and date stay the same.'**
  String editingKeeps(String number, String date);

  /// No description provided for @billEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No items in the bill'**
  String get billEmptyTitle;

  /// No description provided for @billEmptyText.
  ///
  /// In en, this message translates to:
  /// **'Search a product or scan a barcode, then press Enter to add it.'**
  String get billEmptyText;

  /// No description provided for @lessQty.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get lessQty;

  /// No description provided for @moreQty.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreQty;

  /// No description provided for @removeLine.
  ///
  /// In en, this message translates to:
  /// **'Remove this item'**
  String get removeLine;

  /// No description provided for @changeQty.
  ///
  /// In en, this message translates to:
  /// **'Change quantity'**
  String get changeQty;

  /// No description provided for @changeRate.
  ///
  /// In en, this message translates to:
  /// **'Change price'**
  String get changeRate;

  /// No description provided for @discountPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount %'**
  String get discountPercentLabel;

  /// No description provided for @discountPercent.
  ///
  /// In en, this message translates to:
  /// **'Discount {percent}%'**
  String discountPercent(String percent);

  /// No description provided for @warnNoStock.
  ///
  /// In en, this message translates to:
  /// **'Stock is 0, selling anyway'**
  String get warnNoStock;

  /// No description provided for @warnLowStock.
  ///
  /// In en, this message translates to:
  /// **'Only {qty} {unit} in stock'**
  String warnLowStock(String qty, String unit);

  /// No description provided for @warnNoStockToast.
  ///
  /// In en, this message translates to:
  /// **'{name} is out of stock. You can still sell it.'**
  String warnNoStockToast(String name);

  /// No description provided for @warnLowStockToast.
  ///
  /// In en, this message translates to:
  /// **'{name}: only {qty} in stock. You can still sell it.'**
  String warnLowStockToast(String name, String qty);

  /// No description provided for @tabProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get tabProducts;

  /// No description provided for @tabBill.
  ///
  /// In en, this message translates to:
  /// **'Bill ({count})'**
  String tabBill(String count);

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemsCount(String count);

  /// No description provided for @taxable.
  ///
  /// In en, this message translates to:
  /// **'Before tax'**
  String get taxable;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @roundOff.
  ///
  /// In en, this message translates to:
  /// **'Round off'**
  String get roundOff;

  /// No description provided for @grandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand total'**
  String get grandTotal;

  /// No description provided for @payCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get payCash;

  /// No description provided for @payUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get payUpi;

  /// No description provided for @payCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get payCard;

  /// No description provided for @payCredit.
  ///
  /// In en, this message translates to:
  /// **'On credit'**
  String get payCredit;

  /// No description provided for @estimateNoStock.
  ///
  /// In en, this message translates to:
  /// **'An estimate does not change your stock.'**
  String get estimateNoStock;

  /// No description provided for @saveBill.
  ///
  /// In en, this message translates to:
  /// **'Save bill'**
  String get saveBill;

  /// No description provided for @saveEstimate.
  ///
  /// In en, this message translates to:
  /// **'Save estimate'**
  String get saveEstimate;

  /// No description provided for @saveAndPrint.
  ///
  /// In en, this message translates to:
  /// **'Save and print'**
  String get saveAndPrint;

  /// No description provided for @clearBill.
  ///
  /// In en, this message translates to:
  /// **'Clear bill'**
  String get clearBill;

  /// No description provided for @clearBillTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear this bill?'**
  String get clearBillTitle;

  /// No description provided for @clearBillText.
  ///
  /// In en, this message translates to:
  /// **'All items in this bill will be removed.'**
  String get clearBillText;

  /// No description provided for @billSaved.
  ///
  /// In en, this message translates to:
  /// **'Bill {number} saved'**
  String billSaved(String number);

  /// No description provided for @estimateSaved.
  ///
  /// In en, this message translates to:
  /// **'Estimate {number} saved'**
  String estimateSaved(String number);

  /// No description provided for @printPreview.
  ///
  /// In en, this message translates to:
  /// **'Print preview'**
  String get printPreview;

  /// No description provided for @previewInvoiceHint.
  ///
  /// In en, this message translates to:
  /// **'This is how the bill will look on paper'**
  String get previewInvoiceHint;

  /// No description provided for @previewEstimateHint.
  ///
  /// In en, this message translates to:
  /// **'This is how the estimate will look on paper'**
  String get previewEstimateHint;

  /// No description provided for @paperA4.
  ///
  /// In en, this message translates to:
  /// **'A4'**
  String get paperA4;

  /// No description provided for @paper80.
  ///
  /// In en, this message translates to:
  /// **'80 mm'**
  String get paper80;

  /// No description provided for @paper58.
  ///
  /// In en, this message translates to:
  /// **'58 mm'**
  String get paper58;

  /// No description provided for @printNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Printing is not connected in this preview.'**
  String get printNotConnected;

  /// No description provided for @pdfNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Saving a PDF is not connected in this preview.'**
  String get pdfNotConnected;

  /// No description provided for @saveAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Save as PDF'**
  String get saveAsPdf;

  /// No description provided for @rcTaxInvoice.
  ///
  /// In en, this message translates to:
  /// **'TAX INVOICE'**
  String get rcTaxInvoice;

  /// No description provided for @rcEstimate.
  ///
  /// In en, this message translates to:
  /// **'ESTIMATE'**
  String get rcEstimate;

  /// No description provided for @rcGstin.
  ///
  /// In en, this message translates to:
  /// **'GSTIN'**
  String get rcGstin;

  /// No description provided for @rcCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get rcCustomer;

  /// No description provided for @rcPaidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get rcPaidBy;

  /// No description provided for @rcBillNo.
  ///
  /// In en, this message translates to:
  /// **'Bill no'**
  String get rcBillNo;

  /// No description provided for @rcEstNo.
  ///
  /// In en, this message translates to:
  /// **'Estimate no'**
  String get rcEstNo;

  /// No description provided for @rcDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get rcDate;

  /// No description provided for @rcEditedOn.
  ///
  /// In en, this message translates to:
  /// **'Edited on'**
  String get rcEditedOn;

  /// No description provided for @rcItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get rcItem;

  /// No description provided for @rcQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get rcQty;

  /// No description provided for @rcRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rcRate;

  /// No description provided for @rcAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get rcAmount;

  /// No description provided for @rcTaxable.
  ///
  /// In en, this message translates to:
  /// **'Before tax'**
  String get rcTaxable;

  /// No description provided for @rcRoundOff.
  ///
  /// In en, this message translates to:
  /// **'Round off'**
  String get rcRoundOff;

  /// No description provided for @rcGrandTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get rcGrandTotal;

  /// No description provided for @rcThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Please visit again.'**
  String get rcThanks;

  /// No description provided for @rcEstimateNote.
  ///
  /// In en, this message translates to:
  /// **'This is an estimate, not a bill. Prices may change.'**
  String get rcEstimateNote;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get greeting;

  /// No description provided for @todayIs.
  ///
  /// In en, this message translates to:
  /// **'Today is {date}'**
  String todayIs(String date);

  /// No description provided for @statTodaySales.
  ///
  /// In en, this message translates to:
  /// **'Sales today'**
  String get statTodaySales;

  /// No description provided for @statToCollect.
  ///
  /// In en, this message translates to:
  /// **'Money to collect'**
  String get statToCollect;

  /// No description provided for @statCashToday.
  ///
  /// In en, this message translates to:
  /// **'Cash in hand today'**
  String get statCashToday;

  /// No description provided for @cashEstimate.
  ///
  /// In en, this message translates to:
  /// **'Cash sales less expenses (estimate)'**
  String get cashEstimate;

  /// No description provided for @billsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} bills'**
  String billsCount(String count);

  /// No description provided for @customersOwing.
  ///
  /// In en, this message translates to:
  /// **'{count} customers'**
  String customersOwing(String count);

  /// No description provided for @needReorder.
  ///
  /// In en, this message translates to:
  /// **'Need to order again'**
  String get needReorder;

  /// No description provided for @salesLast7.
  ///
  /// In en, this message translates to:
  /// **'Sales in the last 7 days'**
  String get salesLast7;

  /// No description provided for @recentBills.
  ///
  /// In en, this message translates to:
  /// **'Latest bills'**
  String get recentBills;

  /// No description provided for @lowStockTitle.
  ///
  /// In en, this message translates to:
  /// **'Almost finished'**
  String get lowStockTitle;

  /// No description provided for @allStockOk.
  ///
  /// In en, this message translates to:
  /// **'All items have enough stock.'**
  String get allStockOk;

  /// No description provided for @salesRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All {count} bills'**
  String salesRegisterSubtitle(String count);

  /// No description provided for @statBillsToday.
  ///
  /// In en, this message translates to:
  /// **'Bills today'**
  String get statBillsToday;

  /// No description provided for @cancelledNote.
  ///
  /// In en, this message translates to:
  /// **'This bill was cancelled. It is kept for your records and the stock was put back.'**
  String get cancelledNote;

  /// No description provided for @printAgain.
  ///
  /// In en, this message translates to:
  /// **'Print again'**
  String get printAgain;

  /// No description provided for @returnItems.
  ///
  /// In en, this message translates to:
  /// **'Return items'**
  String get returnItems;

  /// No description provided for @cancelBill.
  ///
  /// In en, this message translates to:
  /// **'Cancel bill'**
  String get cancelBill;

  /// No description provided for @cancelBillTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel bill {number}'**
  String cancelBillTitle(String number);

  /// No description provided for @cancelBillOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can cancel a bill. The bill stays in your records.'**
  String get cancelBillOwnerOnly;

  /// No description provided for @cancelBillConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this bill for sure?'**
  String get cancelBillConfirmTitle;

  /// No description provided for @cancelBillConfirmText.
  ///
  /// In en, this message translates to:
  /// **'Bill {number} for {amount} will be cancelled and its stock put back. This cannot be undone.'**
  String cancelBillConfirmText(String number, String amount);

  /// No description provided for @billCancelled.
  ///
  /// In en, this message translates to:
  /// **'Bill {number} was cancelled'**
  String billCancelled(String number);

  /// No description provided for @estimatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Estimates you saved. You can change them, copy them or make them into bills.'**
  String get estimatesSubtitle;

  /// No description provided for @searchEstimateHint.
  ///
  /// In en, this message translates to:
  /// **'Search estimate number or customer'**
  String get searchEstimateHint;

  /// No description provided for @noEstimates.
  ///
  /// In en, this message translates to:
  /// **'No saved estimates'**
  String get noEstimates;

  /// No description provided for @noEstimatesHelp.
  ///
  /// In en, this message translates to:
  /// **'Make a new estimate and save it. It will appear here.'**
  String get noEstimatesHelp;

  /// No description provided for @convertedTo.
  ///
  /// In en, this message translates to:
  /// **'Made into bill {number}'**
  String convertedTo(String number);

  /// No description provided for @convertToInvoice.
  ///
  /// In en, this message translates to:
  /// **'Make into bill'**
  String get convertToInvoice;

  /// No description provided for @convertTitle.
  ///
  /// In en, this message translates to:
  /// **'Make this estimate a bill?'**
  String get convertTitle;

  /// No description provided for @convertText.
  ///
  /// In en, this message translates to:
  /// **'Estimate {estimate} will become bill {bill} and the stock will go down. An estimate can be made into a bill only once.'**
  String convertText(String estimate, String bill);

  /// No description provided for @convertedToast.
  ///
  /// In en, this message translates to:
  /// **'{estimate} is now bill {bill}'**
  String convertedToast(String estimate, String bill);

  /// No description provided for @deleteEstimateTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete estimate {number}'**
  String deleteEstimateTitle(String number);

  /// No description provided for @deleteEstimateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this estimate?'**
  String get deleteEstimateConfirmTitle;

  /// No description provided for @deleteEstimateConfirmText.
  ///
  /// In en, this message translates to:
  /// **'Estimate {number} for {amount} will be deleted.'**
  String deleteEstimateConfirmText(String number, String amount);

  /// No description provided for @salesReturnsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Items customers gave back'**
  String get salesReturnsSubtitle;

  /// No description provided for @addReturn.
  ///
  /// In en, this message translates to:
  /// **'Add return'**
  String get addReturn;

  /// No description provided for @returnSaved.
  ///
  /// In en, this message translates to:
  /// **'Return saved'**
  String get returnSaved;

  /// No description provided for @purchaseReturnsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Items you sent back to dealers'**
  String get purchaseReturnsSubtitle;

  /// No description provided for @deliverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bills that must be sent to the customer'**
  String get deliverySubtitle;

  /// No description provided for @markOut.
  ///
  /// In en, this message translates to:
  /// **'Sent out'**
  String get markOut;

  /// No description provided for @markDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get markDelivered;

  /// No description provided for @customersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{total} customers, {owing} owe money'**
  String customersSubtitle(String total, String owing);

  /// No description provided for @receivePayment.
  ///
  /// In en, this message translates to:
  /// **'Receive payment'**
  String get receivePayment;

  /// No description provided for @savePayment.
  ///
  /// In en, this message translates to:
  /// **'Save payment'**
  String get savePayment;

  /// No description provided for @paymentFrom.
  ///
  /// In en, this message translates to:
  /// **'Payment from {name}'**
  String paymentFrom(String name);

  /// No description provided for @paymentSaved.
  ///
  /// In en, this message translates to:
  /// **'Payment of {amount} saved'**
  String paymentSaved(String amount);

  /// No description provided for @creditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customers who still have to pay you'**
  String get creditSubtitle;

  /// No description provided for @statCustomersOwing.
  ///
  /// In en, this message translates to:
  /// **'Customers who owe'**
  String get statCustomersOwing;

  /// No description provided for @statWeOwe.
  ///
  /// In en, this message translates to:
  /// **'We have to pay'**
  String get statWeOwe;

  /// No description provided for @toDealers.
  ///
  /// In en, this message translates to:
  /// **'To dealers'**
  String get toDealers;

  /// No description provided for @nobodyOwes.
  ///
  /// In en, this message translates to:
  /// **'Nobody owes you money'**
  String get nobodyOwes;

  /// No description provided for @dealersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The people you buy from'**
  String get dealersSubtitle;

  /// No description provided for @addDealer.
  ///
  /// In en, this message translates to:
  /// **'Add dealer'**
  String get addDealer;

  /// No description provided for @payDealer.
  ///
  /// In en, this message translates to:
  /// **'Pay dealer'**
  String get payDealer;

  /// No description provided for @staffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Who can use this shop on the computer and phone'**
  String get staffSubtitle;

  /// No description provided for @addStaff.
  ///
  /// In en, this message translates to:
  /// **'Add person'**
  String get addStaff;

  /// No description provided for @addStaffNote.
  ///
  /// In en, this message translates to:
  /// **'Type the email they will sign in with. They must confirm that email once.'**
  String get addStaffNote;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get roleCashier;

  /// No description provided for @roleOwnerHelp.
  ///
  /// In en, this message translates to:
  /// **'Can do everything, including cancelling bills'**
  String get roleOwnerHelp;

  /// No description provided for @roleManagerHelp.
  ///
  /// In en, this message translates to:
  /// **'Can bill, change products, see reports'**
  String get roleManagerHelp;

  /// No description provided for @roleCashierHelp.
  ///
  /// In en, this message translates to:
  /// **'Can make bills and receive payments only'**
  String get roleCashierHelp;

  /// No description provided for @canDo.
  ///
  /// In en, this message translates to:
  /// **'Can do'**
  String get canDo;

  /// No description provided for @removeAccess.
  ///
  /// In en, this message translates to:
  /// **'Remove access'**
  String get removeAccess;

  /// No description provided for @removeAccessConfirm.
  ///
  /// In en, this message translates to:
  /// **'{name} will not be able to open this shop any more.'**
  String removeAccessConfirm(String name);

  /// No description provided for @removeAccessHelp.
  ///
  /// In en, this message translates to:
  /// **'If a phone or computer is lost, remove the person here and change the account password.'**
  String get removeAccessHelp;

  /// No description provided for @purchasesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Goods you bought from dealers'**
  String get purchasesSubtitle;

  /// No description provided for @addPurchase.
  ///
  /// In en, this message translates to:
  /// **'Add purchase'**
  String get addPurchase;

  /// No description provided for @pendingNoStock.
  ///
  /// In en, this message translates to:
  /// **'A pending purchase does not add stock until you mark it received.'**
  String get pendingNoStock;

  /// No description provided for @markReceived.
  ///
  /// In en, this message translates to:
  /// **'Mark received'**
  String get markReceived;

  /// No description provided for @markedReceived.
  ///
  /// In en, this message translates to:
  /// **'Marked as received and stock added'**
  String get markedReceived;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpense;

  /// No description provided for @expensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Money the shop spent'**
  String get expensesSubtitle;

  /// No description provided for @statExpToday.
  ///
  /// In en, this message translates to:
  /// **'Spent today'**
  String get statExpToday;

  /// No description provided for @statExpMonth.
  ///
  /// In en, this message translates to:
  /// **'Spent this month'**
  String get statExpMonth;

  /// No description provided for @warrantySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Items sold with a warranty'**
  String get warrantySubtitle;

  /// No description provided for @searchWarrantyHint.
  ///
  /// In en, this message translates to:
  /// **'Search customer, item or serial no.'**
  String get searchWarrantyHint;

  /// No description provided for @warrantyActive.
  ///
  /// In en, this message translates to:
  /// **'Under warranty'**
  String get warrantyActive;

  /// No description provided for @warrantyEnded.
  ///
  /// In en, this message translates to:
  /// **'Warranty over'**
  String get warrantyEnded;

  /// No description provided for @projectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Big jobs for a house or building, with budget and spending'**
  String get projectsSubtitle;

  /// No description provided for @addProject.
  ///
  /// In en, this message translates to:
  /// **'Add project'**
  String get addProject;

  /// No description provided for @projRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get projRunning;

  /// No description provided for @projDone.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get projDone;

  /// No description provided for @projPlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get projPlanning;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Things that need your attention'**
  String get notificationsSubtitle;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @noNotificationsHelp.
  ///
  /// In en, this message translates to:
  /// **'When something needs you, it will show here.'**
  String get noNotificationsHelp;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @closingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Count the cash in the drawer and close the day'**
  String get closingSubtitle;

  /// No description provided for @closingSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary for {date}'**
  String closingSummary(String date);

  /// No description provided for @closingCashSales.
  ///
  /// In en, this message translates to:
  /// **'Cash received'**
  String get closingCashSales;

  /// No description provided for @closingCreditGiven.
  ///
  /// In en, this message translates to:
  /// **'Given on credit'**
  String get closingCreditGiven;

  /// No description provided for @closingOpening.
  ///
  /// In en, this message translates to:
  /// **'Cash at start of day'**
  String get closingOpening;

  /// No description provided for @closingExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses paid in cash'**
  String get closingExpenses;

  /// No description provided for @closingExpected.
  ///
  /// In en, this message translates to:
  /// **'Cash that should be in the drawer'**
  String get closingExpected;

  /// No description provided for @closingCount.
  ///
  /// In en, this message translates to:
  /// **'Count the cash'**
  String get closingCount;

  /// No description provided for @closingCountHelp.
  ///
  /// In en, this message translates to:
  /// **'Count the notes and coins in the drawer and type the total.'**
  String get closingCountHelp;

  /// No description provided for @closingCounted.
  ///
  /// In en, this message translates to:
  /// **'Cash counted'**
  String get closingCounted;

  /// No description provided for @closingTally.
  ///
  /// In en, this message translates to:
  /// **'It matches. Well done.'**
  String get closingTally;

  /// No description provided for @closingExtra.
  ///
  /// In en, this message translates to:
  /// **'{amount} extra'**
  String closingExtra(String amount);

  /// No description provided for @closingShort.
  ///
  /// In en, this message translates to:
  /// **'{amount} less'**
  String closingShort(String amount);

  /// No description provided for @closeDay.
  ///
  /// In en, this message translates to:
  /// **'Close the day'**
  String get closeDay;

  /// No description provided for @dayClosed.
  ///
  /// In en, this message translates to:
  /// **'Day closed'**
  String get dayClosed;

  /// No description provided for @closingConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Close the day?'**
  String get closingConfirmTitle;

  /// No description provided for @closingConfirmText.
  ///
  /// In en, this message translates to:
  /// **'Closing {date} saves the cash count.'**
  String closingConfirmText(String date);

  /// No description provided for @closingDone.
  ///
  /// In en, this message translates to:
  /// **'The day is closed'**
  String get closingDone;

  /// No description provided for @reportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How the shop is doing'**
  String get reportsSubtitle;

  /// No description provided for @range7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get range7;

  /// No description provided for @range30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get range30;

  /// No description provided for @range12m.
  ///
  /// In en, this message translates to:
  /// **'12 months'**
  String get range12m;

  /// No description provided for @statSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get statSales;

  /// No description provided for @statBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get statBills;

  /// No description provided for @statAvgBill.
  ///
  /// In en, this message translates to:
  /// **'Average bill'**
  String get statAvgBill;

  /// No description provided for @statProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get statProfit;

  /// No description provided for @profitEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate from cost prices'**
  String get profitEstimate;

  /// No description provided for @salesOverTime.
  ///
  /// In en, this message translates to:
  /// **'Sales over time'**
  String get salesOverTime;

  /// No description provided for @byPayMode.
  ///
  /// In en, this message translates to:
  /// **'How customers paid'**
  String get byPayMode;

  /// No description provided for @topProducts.
  ///
  /// In en, this message translates to:
  /// **'Best selling products'**
  String get topProducts;

  /// No description provided for @exportedDemo.
  ///
  /// In en, this message translates to:
  /// **'Report saved (preview only)'**
  String get exportedDemo;

  /// No description provided for @exportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your data as Excel, CSV or PDF'**
  String get exportSubtitle;

  /// No description provided for @exportedDemoFile.
  ///
  /// In en, this message translates to:
  /// **'{format} file saved (preview only)'**
  String exportedDemoFile(String format);

  /// No description provided for @expSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get expSales;

  /// No description provided for @expSalesHelp.
  ///
  /// In en, this message translates to:
  /// **'Every bill with date, customer and amount'**
  String get expSalesHelp;

  /// No description provided for @expProducts.
  ///
  /// In en, this message translates to:
  /// **'Products and stock'**
  String get expProducts;

  /// No description provided for @expProductsHelp.
  ///
  /// In en, this message translates to:
  /// **'Name, price, stock and value'**
  String get expProductsHelp;

  /// No description provided for @expCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get expCustomers;

  /// No description provided for @expCustomersHelp.
  ///
  /// In en, this message translates to:
  /// **'Name, phone and balance'**
  String get expCustomersHelp;

  /// No description provided for @expDues.
  ///
  /// In en, this message translates to:
  /// **'Money to collect'**
  String get expDues;

  /// No description provided for @expDuesHelp.
  ///
  /// In en, this message translates to:
  /// **'Who owes how much'**
  String get expDuesHelp;

  /// No description provided for @expExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expExpenses;

  /// No description provided for @expExpensesHelp.
  ///
  /// In en, this message translates to:
  /// **'Every expense by date'**
  String get expExpensesHelp;

  /// No description provided for @expGst.
  ///
  /// In en, this message translates to:
  /// **'GST summary'**
  String get expGst;

  /// No description provided for @expGstHelp.
  ///
  /// In en, this message translates to:
  /// **'Tax collected, by rate'**
  String get expGstHelp;

  /// No description provided for @importSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bring your data from the old ERP 1.0 program'**
  String get importSubtitle;

  /// No description provided for @importStep1.
  ///
  /// In en, this message translates to:
  /// **'Step 1: choose the backup file'**
  String get importStep1;

  /// No description provided for @importHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose the backup file you saved from the old program. First we only check it and show you what we found. Nothing is changed yet.'**
  String get importHelp;

  /// No description provided for @chooseBackupFile.
  ///
  /// In en, this message translates to:
  /// **'Choose backup file'**
  String get chooseBackupFile;

  /// No description provided for @importSafe.
  ///
  /// In en, this message translates to:
  /// **'Your old file is only read. It is never changed.'**
  String get importSafe;

  /// No description provided for @importReport.
  ///
  /// In en, this message translates to:
  /// **'What we found'**
  String get importReport;

  /// No description provided for @importWarnings.
  ///
  /// In en, this message translates to:
  /// **'Please look at these'**
  String get importWarnings;

  /// No description provided for @warnNegStock.
  ///
  /// In en, this message translates to:
  /// **'{count} items have less than zero stock'**
  String warnNegStock(String count);

  /// No description provided for @warnNoCost.
  ///
  /// In en, this message translates to:
  /// **'{count} items have no cost price'**
  String warnNoCost(String count);

  /// No description provided for @warnDupNames.
  ///
  /// In en, this message translates to:
  /// **'{count} products have the same name'**
  String warnDupNames(String count);

  /// No description provided for @warnBadDates.
  ///
  /// In en, this message translates to:
  /// **'{count} bills have a wrong date'**
  String warnBadDates(String count);

  /// No description provided for @importWarnHelp.
  ///
  /// In en, this message translates to:
  /// **'These do not stop the import. You can fix them later.'**
  String get importWarnHelp;

  /// No description provided for @importNow.
  ///
  /// In en, this message translates to:
  /// **'Import now'**
  String get importNow;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Import finished'**
  String get importDone;

  /// No description provided for @importProof.
  ///
  /// In en, this message translates to:
  /// **'We checked that nothing was lost:'**
  String get importProof;

  /// No description provided for @proofProducts.
  ///
  /// In en, this message translates to:
  /// **'Number of products is the same'**
  String get proofProducts;

  /// No description provided for @proofStock.
  ///
  /// In en, this message translates to:
  /// **'Stock of every product is the same'**
  String get proofStock;

  /// No description provided for @proofBalances.
  ///
  /// In en, this message translates to:
  /// **'What customers and dealers owe is the same'**
  String get proofBalances;

  /// No description provided for @proofBills.
  ///
  /// In en, this message translates to:
  /// **'Bills and totals are the same'**
  String get proofBills;

  /// No description provided for @importAgain.
  ///
  /// In en, this message translates to:
  /// **'Import another file'**
  String get importAgain;

  /// No description provided for @setShop.
  ///
  /// In en, this message translates to:
  /// **'Shop details'**
  String get setShop;

  /// No description provided for @setShopName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get setShopName;

  /// No description provided for @setLogo.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get setLogo;

  /// No description provided for @setLogoHelp.
  ///
  /// In en, this message translates to:
  /// **'Printed at the top of your bills'**
  String get setLogoHelp;

  /// No description provided for @setTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get setTax;

  /// No description provided for @setPricesIncludeGst.
  ///
  /// In en, this message translates to:
  /// **'Prices already include GST'**
  String get setPricesIncludeGst;

  /// No description provided for @setPricesIncludeGstHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn off if GST is added on top of the price'**
  String get setPricesIncludeGstHelp;

  /// No description provided for @setRoundOff.
  ///
  /// In en, this message translates to:
  /// **'Round the bill to whole rupees'**
  String get setRoundOff;

  /// No description provided for @setRoundOffHelp.
  ///
  /// In en, this message translates to:
  /// **'The small difference is shown as Round off'**
  String get setRoundOffHelp;

  /// No description provided for @setPrinting.
  ///
  /// In en, this message translates to:
  /// **'Printing'**
  String get setPrinting;

  /// No description provided for @setPaper.
  ///
  /// In en, this message translates to:
  /// **'Paper size'**
  String get setPaper;

  /// No description provided for @setPaperHelp.
  ///
  /// In en, this message translates to:
  /// **'Saved only on this computer'**
  String get setPaperHelp;

  /// No description provided for @setReceiptTamil.
  ///
  /// In en, this message translates to:
  /// **'Print receipts in Tamil'**
  String get setReceiptTamil;

  /// No description provided for @setReceiptTamilHelp.
  ///
  /// In en, this message translates to:
  /// **'Product names are always printed as you typed them'**
  String get setReceiptTamilHelp;

  /// No description provided for @setPrinter.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get setPrinter;

  /// No description provided for @setPrinterHelp.
  ///
  /// In en, this message translates to:
  /// **'Check how your paper will look'**
  String get setPrinterHelp;

  /// No description provided for @setLook.
  ///
  /// In en, this message translates to:
  /// **'How it looks'**
  String get setLook;

  /// No description provided for @setLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get setLanguage;

  /// No description provided for @setTheme.
  ///
  /// In en, this message translates to:
  /// **'Colours'**
  String get setTheme;

  /// No description provided for @setTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get setTextSize;

  /// No description provided for @setTextSizeHelp.
  ///
  /// In en, this message translates to:
  /// **'Make writing bigger if it is hard to read'**
  String get setTextSizeHelp;

  /// No description provided for @sizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get sizeSmall;

  /// No description provided for @sizeNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get sizeNormal;

  /// No description provided for @sizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get sizeLarge;

  /// No description provided for @sizeHuge.
  ///
  /// In en, this message translates to:
  /// **'Very large'**
  String get sizeHuge;

  /// No description provided for @textSample.
  ///
  /// In en, this message translates to:
  /// **'This is how your text will look.'**
  String get textSample;

  /// No description provided for @deviceOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Language, colours, text size and printer are saved only on this device.'**
  String get deviceOnlyNote;

  /// No description provided for @setBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get setBackup;

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup'**
  String get lastBackup;

  /// No description provided for @lastBackupValue.
  ///
  /// In en, this message translates to:
  /// **'{time}'**
  String lastBackupValue(String time);

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupNow;

  /// No description provided for @backupDone.
  ///
  /// In en, this message translates to:
  /// **'Backup saved and checked'**
  String get backupDone;

  /// No description provided for @backupsKept.
  ///
  /// In en, this message translates to:
  /// **'The last {count} backups are kept'**
  String backupsKept(String count);

  /// No description provided for @autoBackup.
  ///
  /// In en, this message translates to:
  /// **'Back up by itself'**
  String get autoBackup;

  /// No description provided for @autoBackupHelp.
  ///
  /// In en, this message translates to:
  /// **'Once a day when you open the program, and when you close it'**
  String get autoBackupHelp;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get restore;

  /// No description provided for @restoreHelp.
  ///
  /// In en, this message translates to:
  /// **'Use this if you must go back to an earlier day'**
  String get restoreHelp;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmText.
  ///
  /// In en, this message translates to:
  /// **'Your current data is saved first, then replaced by the backup.'**
  String get restoreConfirmText;

  /// No description provided for @setSync.
  ///
  /// In en, this message translates to:
  /// **'Online copy'**
  String get setSync;

  /// No description provided for @syncStatusNow.
  ///
  /// In en, this message translates to:
  /// **'Status now'**
  String get syncStatusNow;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Copy now'**
  String get syncNow;

  /// No description provided for @quotaTitle.
  ///
  /// In en, this message translates to:
  /// **'Free online space used today'**
  String get quotaTitle;

  /// No description provided for @quotaHelp.
  ///
  /// In en, this message translates to:
  /// **'If it gets full, the program keeps working and copies again tomorrow.'**
  String get quotaHelp;

  /// No description provided for @quotaValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String quotaValue(String percent);

  /// No description provided for @demoControls.
  ///
  /// In en, this message translates to:
  /// **'Preview only: try each state'**
  String get demoControls;

  /// No description provided for @setSecurity.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get setSecurity;

  /// No description provided for @setPin.
  ///
  /// In en, this message translates to:
  /// **'Lock the program with a PIN'**
  String get setPin;

  /// No description provided for @setPinHelp.
  ///
  /// In en, this message translates to:
  /// **'Asks for the PIN when the program opens'**
  String get setPinHelp;

  /// No description provided for @signOutEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Sign out on all devices'**
  String get signOutEverywhere;

  /// No description provided for @signOutEverywhereHelp.
  ///
  /// In en, this message translates to:
  /// **'Change the password. Every device must sign in again within an hour.'**
  String get signOutEverywhereHelp;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @healthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A quick look to see that your data is safe'**
  String get healthSubtitle;

  /// No description provided for @healthIntegrity.
  ///
  /// In en, this message translates to:
  /// **'Data check'**
  String get healthIntegrity;

  /// No description provided for @healthOk.
  ///
  /// In en, this message translates to:
  /// **'Everything is fine'**
  String get healthOk;

  /// No description provided for @healthIntegrityHelp.
  ///
  /// In en, this message translates to:
  /// **'Checked on {time}'**
  String healthIntegrityHelp(String time);

  /// No description provided for @checkNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get checkNow;

  /// No description provided for @healthChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked. Everything is fine.'**
  String get healthChecked;

  /// No description provided for @freeDisk.
  ///
  /// In en, this message translates to:
  /// **'Free space on this computer'**
  String get freeDisk;

  /// No description provided for @freeDiskHelp.
  ///
  /// In en, this message translates to:
  /// **'The program needs at least 500 MB free'**
  String get freeDiskHelp;

  /// No description provided for @syncBacklog.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be copied online'**
  String get syncBacklog;

  /// No description provided for @syncBacklogValue.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String syncBacklogValue(String count);

  /// No description provided for @syncBacklogHelp.
  ///
  /// In en, this message translates to:
  /// **'Everything is safe on this computer meanwhile'**
  String get syncBacklogHelp;

  /// No description provided for @healthTotals.
  ///
  /// In en, this message translates to:
  /// **'Stock and balances'**
  String get healthTotals;

  /// No description provided for @healthTotalsOk.
  ///
  /// In en, this message translates to:
  /// **'They match your records'**
  String get healthTotalsOk;

  /// No description provided for @healthTotalsHelp.
  ///
  /// In en, this message translates to:
  /// **'Checked every night'**
  String get healthTotalsHelp;

  /// No description provided for @rebuildTotals.
  ///
  /// In en, this message translates to:
  /// **'Recalculate'**
  String get rebuildTotals;

  /// No description provided for @databaseSize.
  ///
  /// In en, this message translates to:
  /// **'Size of your data'**
  String get databaseSize;

  /// No description provided for @databaseSizeHelp.
  ///
  /// In en, this message translates to:
  /// **'Works smoothly even with {count} bills'**
  String databaseSizeHelp(String count);

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @nothingNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs your attention.'**
  String get nothingNeedsAttention;

  /// No description provided for @attentionItem.
  ///
  /// In en, this message translates to:
  /// **'1 bill could not be copied online'**
  String get attentionItem;

  /// No description provided for @attentionHelp.
  ///
  /// In en, this message translates to:
  /// **'Your bill is safe on this computer. We will try again by ourselves. You can also press Try again.'**
  String get attentionHelp;

  /// No description provided for @sendLog.
  ///
  /// In en, this message translates to:
  /// **'Send a note to the helper'**
  String get sendLog;

  /// No description provided for @helpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Short answers to common questions'**
  String get helpSubtitle;

  /// No description provided for @helpQuickStart.
  ///
  /// In en, this message translates to:
  /// **'Make your first bill'**
  String get helpQuickStart;

  /// No description provided for @helpStep1.
  ///
  /// In en, this message translates to:
  /// **'Press F2 or tap New bill.'**
  String get helpStep1;

  /// No description provided for @helpStep2.
  ///
  /// In en, this message translates to:
  /// **'Type a product name or scan its barcode, then press Enter.'**
  String get helpStep2;

  /// No description provided for @helpStep3.
  ///
  /// In en, this message translates to:
  /// **'Choose how the customer paid.'**
  String get helpStep3;

  /// No description provided for @helpStep4.
  ///
  /// In en, this message translates to:
  /// **'Press Save and print.'**
  String get helpStep4;

  /// No description provided for @helpShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get helpShortcuts;

  /// No description provided for @keyNewBill.
  ///
  /// In en, this message translates to:
  /// **'New bill'**
  String get keyNewBill;

  /// No description provided for @keyNewEstimate.
  ///
  /// In en, this message translates to:
  /// **'New estimate'**
  String get keyNewEstimate;

  /// No description provided for @keySave.
  ///
  /// In en, this message translates to:
  /// **'Save what you are making'**
  String get keySave;

  /// No description provided for @keyNewProduct.
  ///
  /// In en, this message translates to:
  /// **'Add a new product'**
  String get keyNewProduct;

  /// No description provided for @keyCancel.
  ///
  /// In en, this message translates to:
  /// **'Close or cancel'**
  String get keyCancel;

  /// No description provided for @keyPick.
  ///
  /// In en, this message translates to:
  /// **'Choose a product and add it'**
  String get keyPick;

  /// No description provided for @helpFaq.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get helpFaq;

  /// No description provided for @faq1q.
  ///
  /// In en, this message translates to:
  /// **'What if the internet stops?'**
  String get faq1q;

  /// No description provided for @faq1a.
  ///
  /// In en, this message translates to:
  /// **'Nothing changes. You can keep billing. Everything is saved on this computer and is copied online later.'**
  String get faq1a;

  /// No description provided for @faq2q.
  ///
  /// In en, this message translates to:
  /// **'I sold something that shows zero stock. Is that a problem?'**
  String get faq2q;

  /// No description provided for @faq2a.
  ///
  /// In en, this message translates to:
  /// **'No. The program shows a warning but lets you sell. Fix the stock later in Stock changes.'**
  String get faq2a;

  /// No description provided for @faq3q.
  ///
  /// In en, this message translates to:
  /// **'How do I cancel a bill?'**
  String get faq3q;

  /// No description provided for @faq3a.
  ///
  /// In en, this message translates to:
  /// **'Open the bill in Sales register and press Cancel bill. Only the owner can do this. The bill stays in your records.'**
  String get faq3a;

  /// No description provided for @faq4q.
  ///
  /// In en, this message translates to:
  /// **'How do I change a saved estimate?'**
  String get faq4q;

  /// No description provided for @faq4a.
  ///
  /// In en, this message translates to:
  /// **'Open Saved estimates, tap the estimate and press Edit. Its number and date stay the same.'**
  String get faq4a;

  /// No description provided for @faq5q.
  ///
  /// In en, this message translates to:
  /// **'How do I take a backup?'**
  String get faq5q;

  /// No description provided for @faq5a.
  ///
  /// In en, this message translates to:
  /// **'Open Settings, then Backup, then press Back up now. You can copy the file to a USB drive.'**
  String get faq5a;

  /// No description provided for @helpWrong.
  ///
  /// In en, this message translates to:
  /// **'If something looks wrong'**
  String get helpWrong;

  /// No description provided for @helpWrongText.
  ///
  /// In en, this message translates to:
  /// **'Do not worry. Your bills are saved. Open Database health to check. Then tell your helper what you see on the screen.'**
  String get helpWrongText;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'A fast shop program for billing, estimates, stock, purchases, customers and reports. It works without internet.'**
  String get aboutText;

  /// No description provided for @aboutPrototype.
  ///
  /// In en, this message translates to:
  /// **'Preview with sample data. Nothing you type is saved.'**
  String get aboutPrototype;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get aboutPrivacy;

  /// No description provided for @aboutPrivacyText.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on your computer. The only copy that goes online is your own backup in your own free account.'**
  String get aboutPrivacyText;

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licences'**
  String get aboutLicenses;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the account you made for the shop'**
  String get signInHelp;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Make your shop account'**
  String get createAccountTitle;

  /// No description provided for @createAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'The first account becomes the owner'**
  String get createAccountHelp;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @orWithEmail.
  ///
  /// In en, this message translates to:
  /// **'or use email'**
  String get orWithEmail;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Make account'**
  String get createAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPassword;

  /// No description provided for @firstTimeCreate.
  ///
  /// In en, this message translates to:
  /// **'First time? Make the shop account'**
  String get firstTimeCreate;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get haveAccount;

  /// No description provided for @staySignedNote.
  ///
  /// In en, this message translates to:
  /// **'You stay signed in until you press Sign out. The program opens even without internet.'**
  String get staySignedNote;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @errEmail.
  ///
  /// In en, this message translates to:
  /// **'Please type a correct email, like name@gmail.com'**
  String get errEmail;

  /// No description provided for @errPassword.
  ///
  /// In en, this message translates to:
  /// **'The password needs at least 6 letters or numbers'**
  String get errPassword;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Get a new password'**
  String get forgotTitle;

  /// No description provided for @forgotHelp.
  ///
  /// In en, this message translates to:
  /// **'We will send a link to your email'**
  String get forgotHelp;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send the link'**
  String get sendResetLink;

  /// No description provided for @resetSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to {email}'**
  String resetSent(String email);

  /// No description provided for @resetSentHelp.
  ///
  /// In en, this message translates to:
  /// **'Open that email and tap the link. Look in Spam too.'**
  String get resetSentHelp;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @wizStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String wizStepOf(String step, String total);

  /// No description provided for @wizWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get wizWelcome;

  /// No description provided for @wizWelcomeText.
  ///
  /// In en, this message translates to:
  /// **'Let us set up your shop. It takes about two minutes. You can change everything later.'**
  String get wizWelcomeText;

  /// No description provided for @wizShop.
  ///
  /// In en, this message translates to:
  /// **'Your shop'**
  String get wizShop;

  /// No description provided for @wizGst.
  ///
  /// In en, this message translates to:
  /// **'GST'**
  String get wizGst;

  /// No description provided for @wizGstHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave it empty if you do not have a GST number.'**
  String get wizGstHelp;

  /// No description provided for @wizLogo.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get wizLogo;

  /// No description provided for @wizLogoHelp.
  ///
  /// In en, this message translates to:
  /// **'You can skip this and add it later.'**
  String get wizLogoHelp;

  /// No description provided for @wizPrinter.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get wizPrinter;

  /// No description provided for @wizPrinterHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose the paper your printer uses. You can change it in Settings.'**
  String get wizPrinterHelp;

  /// No description provided for @wizStock.
  ///
  /// In en, this message translates to:
  /// **'Your stock'**
  String get wizStock;

  /// No description provided for @wizStockText.
  ///
  /// In en, this message translates to:
  /// **'How do you want to put in your products?'**
  String get wizStockText;

  /// No description provided for @wizStockLater.
  ///
  /// In en, this message translates to:
  /// **'Later, I will do it myself'**
  String get wizStockLater;

  /// No description provided for @wizStockExcel.
  ///
  /// In en, this message translates to:
  /// **'From an Excel file'**
  String get wizStockExcel;

  /// No description provided for @wizStockHand.
  ///
  /// In en, this message translates to:
  /// **'Type them in now'**
  String get wizStockHand;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
