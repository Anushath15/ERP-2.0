/// What the owner sees before anything is written, and after the new file is made. Plain data only (strings, numbers, lists), so it can travel
/// between the isolate that does the heavy reading and the screen.
library;

import '../../domain/stock_value.dart';
import 'checksum.dart';
import 'plan.dart';
import 'report.dart';

class ImportPreview {
  ImportPreview({
    required this.ok,
    this.error = '',
    this.fileName = '',
    this.checksum = 'notPresent',
    this.counts = const {},
    this.bills = 0,
    this.salesPaise = 0,
    this.owedOnBillsPaise = 0,
    this.thisMonth = '',
    this.thisMonthSalesPaise = 0,
    this.customersOwing = 0,
    this.customersOwedPaise = 0,
    this.stockQtyMilli = 0,
    this.valueAverage = 0,
    this.valueBuying = 0,
    this.valueSelling = 0,
    this.unpricedProducts = 0,
    this.unpricedQtyMilli = 0,
    this.negatives = const [],
    this.rejected = 0,
    this.repaired = 0,
    this.corrections = const [],
    this.decisions = const [],
    this.reportText = '',
  });

  /// False when the file is not an ERP 1 backup (or is damaged beyond reading); [error] says why in plain words.
  final bool ok;
  final String error, fileName, checksum;
  final Map<String, int> counts; // "products" -> 800, ...
  final int bills, salesPaise, owedOnBillsPaise, thisMonthSalesPaise, customersOwing, customersOwedPaise, stockQtyMilli;
  final String thisMonth;
  final int valueAverage, valueBuying, valueSelling, unpricedProducts, unpricedQtyMilli, rejected, repaired;
  final List<String> negatives, corrections, decisions;
  final String reportText;

  bool get checksumBad => checksum == ChecksumResult.mismatch.name;
  bool get canImport => ok && !checksumBad;

  static ImportPreview failed(String message, String fileName) => ImportPreview(ok: false, error: message, fileName: fileName);

  static ImportPreview fromPlan(Erp1Plan p, String fileName) {
    final r = Recon(p);
    final v = r.valuation;
    final bm = _month(p);
    final counts = <String, int>{
      'products': p.imported['products'] ?? 0,
      'categories': p.categories.length,
      'customers': p.imported['customers'] ?? 0,
      'dealers': p.imported['dealers'] ?? 0,
      'bills': p.imported['bills'] ?? 0,
      'estimates': p.imported['estimates'] ?? 0,
      'purchases': p.imported['purchases'] ?? 0,
      'customer payments': p.imported['customer payments'] ?? 0,
      'dealer payments': p.imported['dealer payments'] ?? 0,
      'expenses': p.imported['expenses'] ?? 0,
    };
    return ImportPreview(
      ok: true,
      fileName: fileName,
      checksum: p.checksum.name,
      counts: counts,
      bills: r.bills,
      salesPaise: r.salesPaise,
      owedOnBillsPaise: r.creditOnBillsPaise,
      thisMonth: bm,
      thisMonthSalesPaise: bm.isEmpty ? 0 : (r.salesByMonth[bm] ?? 0),
      customersOwing: r.customersOwing,
      customersOwedPaise: r.customerOwedPaise,
      stockQtyMilli: r.stockMilli,
      valueAverage: v.total(ValuationRule.average),
      valueBuying: v.total(ValuationRule.buying),
      valueSelling: v.total(ValuationRule.selling),
      unpricedProducts: v.unpricedProducts,
      unpricedQtyMilli: v.unpricedQtyMilli,
      negatives: [for (final n in v.negatives.take(30)) '${n.name}: ${qty(n.stockMilli)}'],
      rejected: p.issues.count(IssueKind.rejected),
      repaired: p.issues.count(IssueKind.repaired),
      corrections: [for (final c in p.corrections) c.auditText],
      decisions: [for (final d in p.decisions) '${d.customer}: ${d.bills.join('; ')}; difference ${rupees(d.differencePaise)}'],
      reportText: buildReport(p, fileName: fileName),
    );
  }

  static String _month(Erp1Plan p) {
    final s = p.backupStamp;
    if (s == null || s.length < 7) return '';
    final m = RegExp(r'^(\d{4})-(\d{2})').firstMatch(s);
    return m == null ? '' : '${m[1]}-${m[2]}';
  }
}

/// Reads a backup's text and builds the preview. Never throws: a file that is not an ERP 1 backup comes back as a failed preview.
ImportPreview previewFromText(String text, String fileName) {
  try {
    return ImportPreview.fromPlan(Erp1Plan.parse(text), fileName);
  } on ImportInputError catch (e) {
    return ImportPreview.failed(e.message, fileName);
  } catch (e) {
    return ImportPreview.failed('This file could not be read as an ERP 1 backup. Nothing was changed.', fileName);
  }
}
