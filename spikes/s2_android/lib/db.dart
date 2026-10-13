import 'package:drift/drift.dart';

part 'db.g.dart';

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable()();
  IntColumn get pricePaise => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get number => text()();
  TextColumn get customerId => text().nullable()();
  IntColumn get totalPaise => integer()();
  IntColumn get billedAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get idemKey => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class BillLines extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text()();
  TextColumn get productId => text()();
  IntColumn get qtyMilli => integer()();
  IntColumn get amountPaise => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  IntColumn get qtyMilli => integer()();
  TextColumn get kind => text()();
  IntColumn get at => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class LedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  IntColumn get amountPaise => integer()();
  IntColumn get at => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class Outbox extends Table {
  TextColumn get recordId => text()();
  TextColumn get kind => text()();
  IntColumn get at => integer()();
  @override
  Set<Column> get primaryKey => {recordId};
}

@DriftDatabase(tables: [
  Products,
  Customers,
  Bills,
  BillLines,
  StockMovements,
  LedgerEntries,
  Outbox
])
class PerfDb extends _$PerfDb {
  PerfDb(super.e, {this.sync = 'FULL'});
  final String sync;
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (d) async {
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA synchronous=$sync');
          await customStatement('PRAGMA foreign_keys=ON');
        },
        onCreate: (m) async {
          await m.createAll();
          await customStatement('CREATE INDEX idx_bills_at ON bills(billed_at DESC)');
          await customStatement('CREATE UNIQUE INDEX idx_bills_idem ON bills(idem_key)');
          await customStatement('CREATE INDEX idx_lines_bill ON bill_lines(bill_id)');
          await customStatement('CREATE INDEX idx_lines_prod ON bill_lines(product_id)');
          await customStatement('CREATE INDEX idx_mov_prod ON stock_movements(product_id)');
          await customStatement('CREATE INDEX idx_led_cust ON ledger_entries(customer_id)');
          await customStatement('CREATE INDEX idx_cust_name ON customers(name COLLATE NOCASE)');
          await customStatement(
              "CREATE VIRTUAL TABLE product_fts USING fts5(name, barcode, content='products', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2', prefix='2 3')");
        },
      );
}
