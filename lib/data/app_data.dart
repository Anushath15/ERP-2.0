import 'context.dart';
import 'db/app_database.dart';
import 'repo/bill_repo.dart';
import 'repo/catalog_repo.dart';
import 'repo/ledger_repo.dart';

/// The repositories of one open shop database, bundled. The app makes one of these at start-up (providers read it); tests make one
/// over an in-memory database.
class AppData {
  AppData(this.cx)
      : catalog = CatalogRepo(cx),
        ledger = LedgerRepo(cx) {
    bills = BillRepo(cx, ledger);
  }

  final DataContext cx;
  final CatalogRepo catalog;
  final LedgerRepo ledger;
  late final BillRepo bills;

  AppDatabase get db => cx.db;

  Future<void> close() => db.close();
}
