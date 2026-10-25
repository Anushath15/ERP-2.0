import 'context.dart';
import 'db/app_database.dart';
import 'repo/bill_repo.dart';
import 'repo/catalog_repo.dart';
import 'repo/ledger_repo.dart';
import 'repo/outbox_repo.dart';
import 'repo/records_repo.dart';
import 'repo/purchase_repo.dart';
import 'repo/purchase_return_repo.dart';
import 'repo/gst_return_repo.dart';
import 'repo/report_repo.dart';
import 'repo/return_repo.dart';

/// The repositories of one open shop database, bundled. The app makes one of these at start-up (providers read it); tests make one
/// over an in-memory database.
class AppData {
  AppData(this.cx)
      : catalog = CatalogRepo(cx),
        ledger = LedgerRepo(cx),
        records = RecordsRepo(cx),
        estimations = EstimationRepo(cx),
        reminders = ReminderRepo(cx),
        stock = StockRepo(cx),
        settings = SettingsRepo(cx),
        reports = ReportRepo(cx),
        gst = GstReturnRepo(cx),
        outbox = OutboxRepo(cx) {
    bills = BillRepo(cx, ledger);
    returns = ReturnRepo(cx, ledger);
    purchases = PurchaseRepo(cx, ledger);
    purchaseReturns = PurchaseReturnRepo(cx, ledger);
  }

  final DataContext cx;
  final CatalogRepo catalog;
  final LedgerRepo ledger;
  final RecordsRepo records;
  final EstimationRepo estimations;
  final ReminderRepo reminders;
  final StockRepo stock;
  final SettingsRepo settings;
  final ReportRepo reports;
  final GstReturnRepo gst;
  final OutboxRepo outbox;
  late final BillRepo bills;
  late final ReturnRepo returns;
  late final PurchaseRepo purchases;
  late final PurchaseReturnRepo purchaseReturns;

  AppDatabase get db => cx.db;

  Future<void> close() => db.close();
}
