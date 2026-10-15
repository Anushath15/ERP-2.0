import 'package:drift/drift.dart';
import '../../domain/stock_value.dart';
import '../context.dart';
import '../db/app_database.dart';

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

  Future<int> weOwe() async => _db.scalarInt("SELECT COALESCE(SUM(balance_paise), 0) FROM party_balance WHERE party_kind = 'dealer' AND balance_paise > 0");

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
