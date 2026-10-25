import 'package:drift/drift.dart';
import '../../domain/stock_value.dart';
import '../context.dart';
import '../db/app_database.dart';

class ShopCounts {
  const ShopCounts({required this.products, required this.customers, required this.dealers, required this.bills, this.lastBill, this.importedFromErp1});
  final int products, customers, dealers, bills;
  final DateTime? lastBill, importedFromErp1;
}

class DayTotals {
  const DayTotals({required this.day, this.bills = 0, this.sales = 0, this.taxable = 0, this.cost = 0, this.tax = 0, this.cash = 0, this.upi = 0, this.card = 0, this.credit = 0, this.cancelledBills = 0, this.cancelledPaise = 0});
  final String day;
  final int bills, sales, taxable, cost, tax, cash, upi, card, credit, cancelledBills, cancelledPaise;

  /// Sales before tax minus what the goods cost (zero cost counts as unknown, so profit is then an upper estimate).
  int get profit => taxable - cost;

  static DayTotals sum(String label, Iterable<DayTotals> days) => DayTotals(
        day: label,
        bills: days.fold(0, (s, d) => s + d.bills),
        sales: days.fold(0, (s, d) => s + d.sales),
        taxable: days.fold(0, (s, d) => s + d.taxable),
        cost: days.fold(0, (s, d) => s + d.cost),
        tax: days.fold(0, (s, d) => s + d.tax),
        cash: days.fold(0, (s, d) => s + d.cash),
        upi: days.fold(0, (s, d) => s + d.upi),
        card: days.fold(0, (s, d) => s + d.card),
        credit: days.fold(0, (s, d) => s + d.credit),
        cancelledBills: days.fold(0, (s, d) => s + d.cancelledBills),
        cancelledPaise: days.fold(0, (s, d) => s + d.cancelledPaise),
      );
}

/// The cash of one day. [expected] is what should be in the drawer: the opening cash plus the cash that came in, minus the cash that went out.
class CashBook {
  const CashBook({required this.day, this.salesCash = 0, this.receivedFromCustomers = 0, this.paidToDealersLater = 0, this.paidWithPurchases = 0, this.refundedByDealers = 0});
  final String day;
  final int salesCash, receivedFromCustomers, paidToDealersLater, paidWithPurchases, refundedByDealers;

  int get cashIn => salesCash + receivedFromCustomers + refundedByDealers;
  int get cashOutBeforeExpenses => paidToDealersLater + paidWithPurchases;
  int expected({required int opening, required int expenses}) => opening + cashIn - cashOutBeforeExpenses - expenses;
}

/// Everything the Home page, the day closing and the reports show comes from the summary tables (written with each bill), so a
/// year of sales by day costs a fraction of a millisecond whatever the number of bills.
class ReportRepo {
  ReportRepo(this.cx);
  final DataContext cx;
  AppDatabase get _db => cx.db;

  static DayTotals _row(QueryRow r) => DayTotals(
        day: r.read<String>('day'),
        bills: r.read<int>('bills'),
        sales: r.read<int>('sales_paise'),
        taxable: r.read<int>('taxable_paise'),
        cost: r.read<int>('cost_paise'),
        tax: r.read<int>('tax_paise'),
        cash: r.read<int>('cash_paise'),
        upi: r.read<int>('upi_paise'),
        card: r.read<int>('card_paise'),
        credit: r.read<int>('credit_paise'),
        cancelledBills: r.read<int>('cancelled_bills'),
        cancelledPaise: r.read<int>('cancelled_paise'),
      );

  Future<DayTotals> day(DateTime d) async {
    final key = DataContext.dayOf(d);
    final r = await _db.row('SELECT * FROM day_totals WHERE day = ?', [key]);
    return r == null ? DayTotals(day: key) : _row(r);
  }

  /// The cash book of one day (what Tally's Cash Book and Zoho's cash account show): every rupee of cash that came in or went out, not only the cash
  /// sales. Cash in: cash sales (after cash refunds to customers), cash received from customers against credit, cash refunded by a dealer. Cash out:
  /// cash paid to dealers (with a purchase or later), expenses (the caller adds them: they are not in the database tables). Reversed payments do not count.
  Future<CashBook> cashBook(DateTime d) async {
    final key = DataContext.dayOf(d);
    final from = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    final to = DateTime(d.year, d.month, d.day + 1).millisecondsSinceEpoch;
    Future<int> cashEntries(String party) => _db.scalarInt(
        "SELECT COALESCE(SUM(-e.amount_paise), 0) FROM ledger_entries e WHERE e.party_kind = ? AND e.kind IN ('payment','advance') AND e.mode = 'cash' AND e.reverses IS NULL "
        'AND e.at >= ? AND e.at < ? AND NOT EXISTS (SELECT 1 FROM ledger_entries r WHERE r.reverses = e.id)',
        [party, from, to]);
    return CashBook(
      day: key,
      salesCash: (await day(d)).cash,
      receivedFromCustomers: await cashEntries('customer'),
      paidToDealersLater: await cashEntries('dealer'),
      paidWithPurchases: await _db.scalarInt('SELECT COALESCE(SUM(paid_paise), 0) FROM purchases WHERE status = 1 AND day = ?', [key]),
      refundedByDealers: await _db.scalarInt('SELECT COALESCE(SUM(refunded_paise), 0) FROM purchase_returns WHERE refund_mode = 0 AND day = ?', [key]),
    );
  }

  /// Day totals from [from] to [to], both included (local days), oldest first. Days without bills are missing.
  Future<List<DayTotals>> days(DateTime from, DateTime to) async {
    final r = await _db.rows('SELECT * FROM day_totals WHERE day >= ? AND day <= ? ORDER BY day', [DataContext.dayOf(from), DataContext.dayOf(to)]);
    return [for (final x in r) _row(x)];
  }

  /// The best-selling products: by line for a short range, by the monthly summary for a long one.
  Future<List<({String name, int amount})>> topProducts(DateTime from, DateTime to, {int limit = 8}) async {
    final long = to.difference(from).inDays > 40;
    final r = long
        ? await _db.rows('SELECT p.name AS name, t.amount AS amount FROM (SELECT product_id, SUM(amount_paise) AS amount FROM product_month WHERE month >= ? AND month <= ? GROUP BY product_id ORDER BY amount DESC LIMIT ?) t JOIN products p ON p.id = t.product_id ORDER BY t.amount DESC', [DataContext.monthOf(from), DataContext.monthOf(to), limit])
        : await _db.rows('SELECT l.name AS name, SUM(l.total_paise) AS amount FROM bill_lines l JOIN bills b ON b.id = l.bill_id WHERE b.billed_at >= ? AND b.billed_at < ? AND b.cancelled = 0 GROUP BY l.product_id ORDER BY amount DESC LIMIT ?', [from.millisecondsSinceEpoch, to.add(const Duration(days: 1)).millisecondsSinceEpoch, limit]);
    return [for (final x in r) (name: x.read<String>('name'), amount: x.read<int>('amount'))];
  }

  Future<int> lowStockCount() => _db.scalarInt('SELECT COUNT(*) FROM products p LEFT JOIN stock_cache s ON s.product_id = p.id WHERE p.deleted_at IS NULL AND COALESCE(s.qty_milli, 0) <= p.min_stock_milli');

  /// Money other people owe us, and how many people.
  Future<({int total, int people})> toCollect() async {
    final r = await _db.row("SELECT COALESCE(SUM(balance_paise), 0) AS t, COUNT(*) AS n FROM party_balance WHERE party_kind = 'customer' AND balance_paise > 0");
    return (total: r?.read<int>('t') ?? 0, people: r?.read<int>('n') ?? 0);
  }

  /// What one customer has bought, and what the shop made on it: bills that count (not cancelled) minus what they gave back.
  /// Profit is worked out like the day totals do: the value before tax minus the buying cost of what was sold (an estimate:
  /// a product with no buying price counts as cost 0).
  Future<CustomerSummary> customerSummary(String customerId) async {
    final b = await _db.row('SELECT COUNT(*) AS n, COALESCE(SUM(total_paise), 0) AS total, COALESCE(SUM(taxable_paise), 0) AS taxable, MAX(billed_at) AS last FROM bills WHERE customer_id = ? AND cancelled = 0', [customerId]);
    final cost = await _db.scalarInt('SELECT COALESCE(SUM((l.cost_paise * l.qty_milli * 2 + 1000) / 2000), 0) FROM bill_lines l JOIN bills b ON b.id = l.bill_id WHERE b.customer_id = ? AND b.cancelled = 0', [customerId]);
    final r = await _db.row('SELECT COUNT(*) AS n, COALESCE(SUM(total_paise), 0) AS total, COALESCE(SUM(taxable_paise), 0) AS taxable, COALESCE(SUM(cost_paise), 0) AS cost FROM sales_returns WHERE customer_id = ?', [customerId]);
    final cancelled = await _db.scalarInt('SELECT COUNT(*) FROM bills WHERE customer_id = ? AND cancelled = 1', [customerId]);
    final billTotal = b?.read<int>('total') ?? 0, retTotal = r?.read<int>('total') ?? 0;
    final profit = ((b?.read<int>('taxable') ?? 0) - cost) - ((r?.read<int>('taxable') ?? 0) - (r?.read<int>('cost') ?? 0));
    final last = b?.readNullable<int>('last');
    return CustomerSummary(
      bills: b?.read<int>('n') ?? 0,
      cancelledBills: cancelled,
      boughtPaise: billTotal - retTotal,
      grossPaise: billTotal,
      returnedPaise: retTotal,
      returns: r?.read<int>('n') ?? 0,
      profitPaise: profit,
      lastBillAt: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
    );
  }

  /// What each product has sold (bills that count, minus what came back): quantity, sales (with GST) and profit (the value before tax
  /// minus the buying cost). All time. A product that never sold is not in the map.
  Future<Map<String, ProductSales>> productSales() async {
    final sold = await _db.rows(
        'SELECT l.product_id AS pid, SUM(l.qty_milli) AS qty, SUM(l.total_paise) AS sales, SUM(l.taxable_paise - (l.cost_paise * l.qty_milli * 2 + 1000) / 2000) AS profit '
        'FROM bill_lines l JOIN bills b ON b.id = l.bill_id WHERE b.cancelled = 0 GROUP BY l.product_id');
    final back = await _db.rows('SELECT product_id AS pid, SUM(qty_milli) AS qty, SUM(amount_paise) AS sales, SUM(taxable_paise - cost_paise) AS profit FROM sales_return_lines GROUP BY product_id');
    final out = <String, ProductSales>{
      for (final r in sold) r.read<String>('pid'): ProductSales(qtyMilli: r.read<int>('qty'), salesPaise: r.read<int>('sales'), profitPaise: r.read<int>('profit')),
    };
    for (final r in back) {
      final id = r.read<String>('pid');
      final o = out[id] ?? const ProductSales(qtyMilli: 0, salesPaise: 0, profitPaise: 0);
      out[id] = ProductSales(qtyMilli: o.qtyMilli - r.read<int>('qty'), salesPaise: o.salesPaise - r.read<int>('sales'), profitPaise: o.profitPaise - r.read<int>('profit'));
    }
    return out;
  }

  Future<int> weOwe() async => _db.scalarInt("SELECT COALESCE(SUM(balance_paise), 0) FROM party_balance WHERE party_kind = 'dealer' AND balance_paise > 0");

  /// How much the shop's data holds right now (live rows) and when the last bill was made: the Health page shows it so the owner can see the real data is in use.
  Future<ShopCounts> shopCounts() async {
    final last = await _db.rows('SELECT MAX(billed_at) AS t FROM bills');
    final t = last.isEmpty ? null : last.first.readNullable<int>('t');
    final from = await _db.rows("SELECT value FROM kv WHERE name = 'import.erp1'");
    int? importedAt;
    if (from.isNotEmpty) {
      final m = RegExp(r'"at":(\d+)').firstMatch(from.first.read<String>('value'));
      if (m != null) importedAt = int.parse(m.group(1)!);
    }
    return ShopCounts(
      products: await _db.scalarInt('SELECT COUNT(*) FROM products WHERE deleted_at IS NULL'),
      customers: await _db.scalarInt('SELECT COUNT(*) FROM customers WHERE deleted_at IS NULL'),
      dealers: await _db.scalarInt('SELECT COUNT(*) FROM dealers WHERE deleted_at IS NULL'),
      bills: await _db.scalarInt('SELECT COUNT(*) FROM bills'),
      lastBill: t == null ? null : DateTime.fromMillisecondsSinceEpoch(t),
      importedFromErp1: importedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(importedAt),
    );
  }

  /// Every product that is not deleted, with its stock figure and its prices: the input of the ONE stock-value calculation ([StockValuation.compute]).
  Future<List<StockLine>> stockLines() async {
    final r = await _db.rows('SELECT p.id, p.name, p.active, p.price_paise, p.cost_paise, p.avg_cost_paise, COALESCE(s.qty_milli, 0) AS stock FROM products p LEFT JOIN stock_cache s ON s.product_id = p.id WHERE p.deleted_at IS NULL');
    return [
      for (final x in r) StockLine(id: x.read<String>('id'), name: x.read<String>('name'), active: x.read<int>('active') == 1, stockMilli: x.read<int>('stock'), sellPaise: x.read<int>('price_paise'), buyPaise: x.read<int>('cost_paise'), avgPaise: x.read<int>('avg_cost_paise')),
    ];
  }

  /// The stock value under every rule, with the shop's chosen rule (setting `valuation.rule`) if there is one.
  Future<StockValuation> stockValuation() async {
    final rule = await _db.rows("SELECT value FROM kv WHERE name = 'valuation.rule'");
    return StockValuation.compute(await stockLines(), chosen: ruleFromSetting(rule.isEmpty ? null : rule.first.read<String>('value')));
  }
}

/// What a customer's page shows first.
class CustomerSummary {
  const CustomerSummary({required this.bills, required this.cancelledBills, required this.boughtPaise, required this.grossPaise, required this.returnedPaise, required this.returns, required this.profitPaise, required this.lastBillAt});
  final int bills, cancelledBills, returns;

  /// Bought in total, after what they gave back.
  final int boughtPaise, grossPaise, returnedPaise;

  /// What the shop made on this customer (an estimate from the buying prices).
  final int profitPaise;
  final DateTime? lastBillAt;
}

/// What one product has sold and made (see [ReportRepo.productSales]).
class ProductSales {
  const ProductSales({required this.qtyMilli, required this.salesPaise, required this.profitPaise});
  final int qtyMilli, salesPaise, profitPaise;
}
