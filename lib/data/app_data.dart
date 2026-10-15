import 'context.dart';
import 'db/app_database.dart';
import 'repo/bill_repo.dart';
import 'repo/catalog_repo.dart';
import 'repo/ledger_repo.dart';
import 'repo/outbox_repo.dart';
import 'repo/records_repo.dart';
import 'repo/report_repo.dart';

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
        outbox = OutboxRepo(cx) {
    bills = BillRepo(cx, ledger);
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
  final OutboxRepo outbox;
  late final BillRepo bills;

  AppDatabase get db => cx.db;

  Future<void> close() => db.close();
}
