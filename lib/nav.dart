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
    NavItem('/', Icons.space_dashboard_outlined, (l) => l.navDashboard),
    NavItem('/bill', Icons.point_of_sale, (l) => l.navNewBill),
    NavItem('/estimate', Icons.request_quote_outlined, (l) => l.navNewEstimate),
    NavItem('/estimates', Icons.folder_open_outlined, (l) => l.navSavedEstimates),
    NavItem('/sales', Icons.receipt_long_outlined, (l) => l.navSalesRegister),
    NavItem('/sales-returns', Icons.assignment_return_outlined, (l) => l.navSalesReturns),
    NavItem('/delivery', Icons.local_shipping_outlined, (l) => l.navDelivery),
  ]),
  NavGroup((l) => l.groupStock, [
    NavItem('/products', Icons.inventory_2_outlined, (l) => l.navProducts),
    NavItem('/categories', Icons.category_outlined, (l) => l.navCategories),
    NavItem('/inventory', Icons.warehouse_outlined, (l) => l.navInventory),
    NavItem('/purchases', Icons.shopping_cart_checkout, (l) => l.navPurchases),
    NavItem('/purchase-returns', Icons.undo, (l) => l.navPurchaseReturns),
    NavItem('/adjustments', Icons.tune, (l) => l.navAdjustments),
  ]),
  NavGroup((l) => l.groupPeople, [
    NavItem('/customers', Icons.people_outline, (l) => l.navCustomers),
    NavItem('/dealers', Icons.store_outlined, (l) => l.navDealers),
    NavItem('/credit', Icons.account_balance_wallet_outlined, (l) => l.navCredit),
    NavItem('/staff', Icons.badge_outlined, (l) => l.navStaff),
  ]),
  NavGroup((l) => l.groupMoney, [
    NavItem('/expenses', Icons.payments_outlined, (l) => l.navExpenses),
    NavItem('/closing', Icons.event_available_outlined, (l) => l.navClosing),
    NavItem('/reports', Icons.bar_chart, (l) => l.navReports),
    NavItem('/export', Icons.ios_share, (l) => l.navExport),
  ]),
  NavGroup((l) => l.groupMore, [
    NavItem('/warranty', Icons.verified_user_outlined, (l) => l.navWarranty),
    NavItem('/notifications', Icons.notifications_none, (l) => l.navNotifications),
    NavItem('/import', Icons.upload_file_outlined, (l) => l.navImport),
    NavItem('/shop', Icons.storefront_outlined, (l) => l.navShop),
    NavItem('/settings', Icons.settings_outlined, (l) => l.navSettings),
    NavItem('/backups', Icons.save_alt, (l) => l.navBackups),
    NavItem('/health', Icons.health_and_safety_outlined, (l) => l.navHealth),
    NavItem('/help', Icons.help_outline, (l) => l.navHelp),
    NavItem('/about', Icons.info_outline, (l) => l.navAbout),
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
