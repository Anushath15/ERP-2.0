import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'fake/store.dart';
import 'features/auth/auth_screens.dart';
import 'features/billing/billing_screen.dart';
import 'features/billing/cart.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/money/money_screens.dart';
import 'features/people/people_screens.dart';
import 'features/print/print_preview.dart';
import 'features/reports/reports_screens.dart';
import 'features/sales/sales_screens.dart';
import 'features/stock/stock_screens.dart';
import 'features/system/system_screens.dart';
import 'shell.dart';

Page<void> _p(Widget w, {LocalKey? key}) => NoTransitionPage<void>(key: key, child: w);

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
          GoRoute(path: '/', pageBuilder: (c, s) => _p(const DashboardScreen())),
          GoRoute(path: '/bill', pageBuilder: (c, s) => _p(const BillingScreen(mode: DocMode.invoice))),
          GoRoute(path: '/estimate', pageBuilder: (c, s) => _p(const BillingScreen(mode: DocMode.estimation))),
          GoRoute(path: '/estimates', pageBuilder: (c, s) => _p(const EstimationsScreen())),
          GoRoute(path: '/sales', pageBuilder: (c, s) => _p(const SalesRegisterScreen())),
          GoRoute(path: '/sales-returns', pageBuilder: (c, s) => _p(const SalesReturnsScreen())),
          GoRoute(path: '/delivery', pageBuilder: (c, s) => _p(const DeliveryScreen())),
          GoRoute(path: '/products', pageBuilder: (c, s) => _p(ProductsScreen(autoAdd: s.uri.queryParameters['add'] == '1'), key: ValueKey(s.uri.toString()))),
          GoRoute(path: '/categories', pageBuilder: (c, s) => _p(const CategoriesScreen())),
          GoRoute(path: '/inventory', pageBuilder: (c, s) => _p(const InventoryScreen())),
          GoRoute(path: '/purchases', pageBuilder: (c, s) => _p(const PurchasesScreen())),
          GoRoute(path: '/purchase-returns', pageBuilder: (c, s) => _p(const PurchaseReturnsScreen())),
          GoRoute(path: '/adjustments', pageBuilder: (c, s) => _p(const AdjustmentsScreen())),
          GoRoute(path: '/customers', pageBuilder: (c, s) => _p(const CustomersScreen())),
          GoRoute(path: '/dealers', pageBuilder: (c, s) => _p(const DealersScreen())),
          GoRoute(path: '/credit', pageBuilder: (c, s) => _p(const CreditScreen())),
          GoRoute(path: '/staff', pageBuilder: (c, s) => _p(const StaffScreen())),
          GoRoute(path: '/expenses', pageBuilder: (c, s) => _p(const ExpensesScreen())),
          GoRoute(path: '/closing', pageBuilder: (c, s) => _p(const ClosingScreen())),
          GoRoute(path: '/reports', pageBuilder: (c, s) => _p(const ReportsScreen())),
          GoRoute(path: '/export', pageBuilder: (c, s) => _p(const ExportScreen())),
          GoRoute(path: '/import', pageBuilder: (c, s) => _p(const ImportScreen())),
          GoRoute(path: '/warranty', pageBuilder: (c, s) => _p(const WarrantyScreen())),
          GoRoute(path: '/projects', pageBuilder: (c, s) => _p(const ProjectsScreen())),
          GoRoute(path: '/notifications', pageBuilder: (c, s) => _p(const NotificationsScreen())),
          GoRoute(path: '/settings', pageBuilder: (c, s) => _p(const SettingsScreen())),
          GoRoute(path: '/health', pageBuilder: (c, s) => _p(const HealthScreen())),
          GoRoute(path: '/help', pageBuilder: (c, s) => _p(const HelpScreen())),
          GoRoute(path: '/about', pageBuilder: (c, s) => _p(const AboutScreen())),
          GoRoute(path: '/more', pageBuilder: (c, s) => _p(const MoreScreen())),
          GoRoute(path: '/print', pageBuilder: (c, s) => _p(const PrintPreviewScreen())),
          GoRoute(path: '/preview/a4', pageBuilder: (c, s) => _p(const PrintPreviewScreen(initialPaper: PaperSize.a4, sampleMode: DocMode.invoice))),
          GoRoute(path: '/preview/80', pageBuilder: (c, s) => _p(const PrintPreviewScreen(initialPaper: PaperSize.mm80, sampleMode: DocMode.invoice))),
          GoRoute(path: '/preview/58', pageBuilder: (c, s) => _p(const PrintPreviewScreen(initialPaper: PaperSize.mm58, sampleMode: DocMode.invoice))),
          GoRoute(path: '/preview/estimate', pageBuilder: (c, s) => _p(const PrintPreviewScreen(initialPaper: PaperSize.a4, sampleMode: DocMode.estimation))),
        ],
      ),
    ],
  );
}
