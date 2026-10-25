import 'package:flutter/material.dart';
import 'strings.dart';

class NavItem {
  const NavItem(this.path, this.icon, this.label, {this.key});
  final String path;
  final IconData icon;
  final String Function(Strings) label;
  final String? key;
}

class NavGroup {
  const NavGroup(this.label, this.items);
  final String Function(Strings) label;
  final List<NavItem> items;
}

final navGroups = <NavGroup>[
  NavGroup((l) => l.groupSales, [
    NavItem('/', Icons.home_rounded, (l) => l.navDashboard),
    NavItem('/bill', Icons.receipt_long_rounded, (l) => l.navNewBill),
    NavItem('/estimate', Icons.request_quote_rounded, (l) => l.navNewEstimate),
    NavItem('/estimates', Icons.folder_open_rounded, (l) => l.navSavedEstimates),
    NavItem('/sales', Icons.list_alt_rounded, (l) => l.navSalesRegister),
    NavItem('/sales-returns', Icons.keyboard_return_rounded, (l) => l.navSalesReturns),
  ]),
  NavGroup((l) => l.groupStock, [
    NavItem('/products', Icons.inventory_2_rounded, (l) => l.navProducts),
    NavItem('/labels', Icons.sell_rounded, (l) => l.navLabels),
    NavItem('/categories', Icons.category_rounded, (l) => l.navCategories),
    NavItem('/inventory', Icons.inventory_rounded, (l) => l.navInventory),
    NavItem('/orders', Icons.shopping_basket_rounded, (l) => l.navOrders),
    NavItem('/purchases', Icons.shopping_cart_rounded, (l) => l.navPurchases),
    NavItem('/purchase-returns', Icons.undo_rounded, (l) => l.navPurchaseReturns),
    NavItem('/adjustments', Icons.edit_note_rounded, (l) => l.navAdjustments),
  ]),
  NavGroup((l) => l.groupPeople, [
    NavItem('/customers', Icons.people_rounded, (l) => l.navCustomers),
    NavItem('/dealers', Icons.business_rounded, (l) => l.navDealers),
    NavItem('/credit', Icons.currency_rupee_rounded, (l) => l.navCredit),
    NavItem('/staff', Icons.badge_rounded, (l) => l.navStaff),
  ]),
  NavGroup((l) => l.groupMoney, [
    NavItem('/expenses', Icons.payments_rounded, (l) => l.navExpenses),
    NavItem('/closing', Icons.today_rounded, (l) => l.navClosing),
    NavItem('/reports', Icons.bar_chart_rounded, (l) => l.navReports),
    NavItem('/export', Icons.file_download_rounded, (l) => l.navExport),
  ]),
  NavGroup((l) => l.groupMore, [
    NavItem('/warranty', Icons.verified_user_rounded, (l) => l.navWarranty),
    NavItem('/notifications', Icons.notifications_rounded, (l) => l.navNotifications),
    NavItem('/import', Icons.upload_file_rounded, (l) => l.navImport),
    NavItem('/shop', Icons.storefront_rounded, (l) => l.navShop),
    NavItem('/settings', Icons.settings_rounded, (l) => l.navSettings),
    NavItem('/backups', Icons.cloud_upload_rounded, (l) => l.navBackups),
    NavItem('/health', Icons.monitor_heart_rounded, (l) => l.navHealth),
    NavItem('/help', Icons.help_rounded, (l) => l.navHelp),
    NavItem('/about', Icons.info_rounded, (l) => l.navAbout),
  ]),
];

/// Bottom bar on phones: the four most used screens plus "More".
const phoneTabs = <String>['/', '/bill', '/products', '/customers'];

NavItem? navFor(String location) {
  for (final g in navGroups) {
    for (final i in g.items) {
      if (i.path == location) return i;
    }
  }
  return null;
}
