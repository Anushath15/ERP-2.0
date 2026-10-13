import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'design/motion.dart';
import 'fake/store.dart';
import 'features/auth/auth_screens.dart';
import 'features/billing/billing_screen.dart';
import 'features/billing/cart.dart';
import 'features/credit/credit_screens.dart';
import 'features/credit/profile_screen.dart';
import 'fake/credit_store.dart' show PartyKind;
import 'features/dashboard/dashboard_screen.dart';
import 'features/money/money_screens.dart';
import 'features/people/people_screens.dart';
import 'features/print/print_preview.dart';
import 'features/reports/reports_screens.dart';
import 'features/sales/sales_screens.dart';
import 'features/shop/shop_profile_screen.dart';
import 'features/stock/stock_screens.dart';
import 'features/system/system_screens.dart';
import 'shell.dart';

Page<void> _p(BuildContext c, GoRouterState s, Widget w, {LocalKey? key}) => motionPage(c, key ?? s.pageKey, w);

GoRouter buildRouter({String initialLocation = '/'}) {
  final shellKey = GlobalKey<NavigatorState>();
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/signin', builder: (c, s) => const SignInScreen()),
      GoRoute(path: '/forgot', builder: (c, s) => const ForgotScreen()),
      GoRoute(path: '/wizard', builder: (c, s) => const WizardScreen()),
      ShellRoute(
        navigatorKey: shellKey,
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (c, s) => _p(c, s, const DashboardScreen())),
          GoRoute(path: '/bill', pageBuilder: (c, s) => _p(c, s, const BillingScreen(mode: DocMode.invoice))),
          GoRoute(path: '/estimate', pageBuilder: (c, s) => _p(c, s, const BillingScreen(mode: DocMode.estimation))),
          GoRoute(path: '/estimates', pageBuilder: (c, s) => _p(c, s, const EstimationsScreen())),
          GoRoute(path: '/sales', pageBuilder: (c, s) => _p(c, s, const SalesRegisterScreen())),
          GoRoute(path: '/sales-returns', pageBuilder: (c, s) => _p(c, s, const SalesReturnsScreen())),
          GoRoute(path: '/delivery', pageBuilder: (c, s) => _p(c, s, const DeliveryScreen())),
          GoRoute(path: '/products', pageBuilder: (c, s) => _p(c, s, ProductsScreen(autoAdd: s.uri.queryParameters['add'] == '1'), key: ValueKey(s.uri.toString()))),
          GoRoute(path: '/categories', pageBuilder: (c, s) => _p(c, s, const CategoriesScreen())),
          GoRoute(path: '/inventory', pageBuilder: (c, s) => _p(c, s, const InventoryScreen())),
          GoRoute(path: '/purchases', pageBuilder: (c, s) => _p(c, s, const PurchasesScreen())),
          GoRoute(path: '/purchase-returns', pageBuilder: (c, s) => _p(c, s, const PurchaseReturnsScreen())),
          GoRoute(path: '/adjustments', pageBuilder: (c, s) => _p(c, s, const AdjustmentsScreen())),
          GoRoute(path: '/customers', pageBuilder: (c, s) => _p(c, s, const CustomersScreen())),
          GoRoute(path: '/customers/:id', pageBuilder: (c, s) => _p(c, s, ProfileScreen(partyId: s.pathParameters['id']!, kind: PartyKind.customer), key: ValueKey(s.uri.toString()))),
          GoRoute(path: '/customers/:id/statement', pageBuilder: (c, s) => _p(c, s, StatementScreen(customerId: s.pathParameters['id']!), key: ValueKey(s.uri.toString()))),
          GoRoute(path: '/dealers', pageBuilder: (c, s) => _p(c, s, const DealersScreen())),
          GoRoute(path: '/dealers/:id', pageBuilder: (c, s) => _p(c, s, ProfileScreen(partyId: s.pathParameters['id']!, kind: PartyKind.dealer), key: ValueKey(s.uri.toString()))),
          GoRoute(path: '/credit', pageBuilder: (c, s) => _p(c, s, const CreditScreen())),
          GoRoute(path: '/staff', pageBuilder: (c, s) => _p(c, s, const StaffScreen())),
          GoRoute(path: '/expenses', pageBuilder: (c, s) => _p(c, s, const ExpensesScreen())),
          GoRoute(path: '/closing', pageBuilder: (c, s) => _p(c, s, const ClosingScreen())),
          GoRoute(path: '/reports', pageBuilder: (c, s) => _p(c, s, const ReportsScreen())),
          GoRoute(path: '/export', pageBuilder: (c, s) => _p(c, s, const ExportScreen())),
          GoRoute(path: '/import', pageBuilder: (c, s) => _p(c, s, const ImportScreen())),
          GoRoute(path: '/warranty', pageBuilder: (c, s) => _p(c, s, const WarrantyScreen())),
          GoRoute(path: '/projects', pageBuilder: (c, s) => _p(c, s, const ProjectsScreen())),
          GoRoute(path: '/notifications', pageBuilder: (c, s) => _p(c, s, const NotificationsScreen())),
          GoRoute(path: '/shop', pageBuilder: (c, s) => _p(c, s, const ShopProfileScreen())),
          GoRoute(path: '/settings', pageBuilder: (c, s) => _p(c, s, const SettingsScreen())),
          GoRoute(path: '/health', pageBuilder: (c, s) => _p(c, s, const HealthScreen())),
          GoRoute(path: '/help', pageBuilder: (c, s) => _p(c, s, const HelpScreen())),
          GoRoute(path: '/about', pageBuilder: (c, s) => _p(c, s, const AboutScreen())),
          GoRoute(path: '/more', pageBuilder: (c, s) => _p(c, s, const MoreScreen())),
          GoRoute(path: '/print', pageBuilder: (c, s) => _p(c, s, const PrintPreviewScreen())),
          GoRoute(path: '/preview/payment', pageBuilder: (c, s) => _p(c, s, const PaymentReceiptScreen())),
          GoRoute(path: '/preview/a4', pageBuilder: (c, s) => _p(c, s, const PrintPreviewScreen(initialPaper: PaperSize.a4, sampleMode: DocMode.invoice))),
          GoRoute(path: '/preview/a5', pageBuilder: (c, s) => _p(c, s, const PrintPreviewScreen(initialPaper: PaperSize.a5, sampleMode: DocMode.invoice))),
          GoRoute(path: '/preview/80', pageBuilder: (c, s) => _p(c, s, const PrintPreviewScreen(initialPaper: PaperSize.mm80, sampleMode: DocMode.invoice))),
          GoRoute(path: '/preview/58', pageBuilder: (c, s) => _p(c, s, const PrintPreviewScreen(initialPaper: PaperSize.mm58, sampleMode: DocMode.invoice))),
          GoRoute(path: '/preview/estimate', pageBuilder: (c, s) => _p(c, s, const PrintPreviewScreen(initialPaper: PaperSize.a4, sampleMode: DocMode.estimation))),
        ],
      ),
    ],
  );
}
