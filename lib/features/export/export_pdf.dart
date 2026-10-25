/// An export table as a ready-to-print PDF report: the shop's logo, name and details, the report title and date, figure boxes (totals), a numbered table
/// whose header repeats on every page, a totals row, and "Page x of y" at the foot. A PDF is for reading and printing: it holds at most [maxPdfRows] rows;
/// Excel and CSV hold everything. The page turns sideways when the table is wide. [encodePdfBook] puts several tables (the parts of a GST return) in one PDF.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../domain/export/export_table.dart';
import '../../fake/shop_profile.dart';
import 'pdf_kit.dart';

const maxPdfRows = 5000;

bool _isNumber(Object? v) => v is Rupees || v is Qty || v is num;

/// What one cell shows on paper: money with Indian digit grouping, quantities without trailing zeros, dates as dd/mm/yyyy.
String pdfCell(Object? v) => switch (v) {
  null => '',
  Rupees r => formatPaise(r.paise),
  Qty q => formatQty(q.milli),
  int i => groupIndian(i),
  double d => d == d.roundToDouble() ? d.toInt().toString() : d.toString(),
  DateTime d => formatDate(d),
  _ => v.toString(),
};

/// A table made ready for paper: which columns are numbers, how wide each is, the totals row with its "Total" label, and whether it needs a sideways page.
class _Ready {
  _Ready(this.t) {
    shown = t.rows.length > maxPdfRows ? t.rows.sublist(0, maxPdfRows) : t.rows;
    final cols = t.headers.length;
    numeric = [
      for (var c = 0; c < cols; c++)
        shown.any((r) => c < r.length && _isNumber(r[c])) ||
            (t.totalsRow != null &&
                c < t.totalsRow!.length &&
                _isNumber(t.totalsRow![c])),
    ];
    final sample = shown.length > 300 ? shown.sublist(0, 300) : shown;
    chars = [
      for (var c = 0; c < cols; c++)
        () {
          var m = t.headers[c].length.toDouble();
          for (final r in sample) {
            if (c < r.length) {
              final n = pdfCell(r[c]).length.toDouble();
              if (n > m) m = n;
            }
          }
          if (t.totalsRow != null && c < t.totalsRow!.length) {
            final n = pdfCell(t.totalsRow![c]).length.toDouble();
            if (n > m) m = n;
          }
          return m.clamp(numeric[c] ? 7 : 4, numeric[c] ? 16 : 30).toDouble();
        }(),
    ];
    landscape = 34 + chars.fold<double>(0, (s, x) => s + x * 4.1 + 7) > 470;
    // the first text column of the totals row says "Total" (unless the report gave it its own words)
    totals = t.totalsRow;
    if (totals != null && !totals!.any((x) => x is String && x.isNotEmpty)) {
      final firstText = [
        for (var c = 0; c < cols; c++)
          if (!numeric[c]) c,
      ].firstOrNull;
      if (firstText != null && firstText < totals!.length)
        totals = [...totals!]..[firstText] = 'Total';
    }
  }

  final ExportTable t;
  late final List<List<Object?>> shown;
  late final List<bool> numeric;
  late final List<double> chars;
  late final bool landscape;
  late List<Object?>? totals;

  List<pw.Widget> widgets(PdfKit kit) {
    final cols = t.headers.length;
    return [
      if (t.summary.isNotEmpty) ...[
        kit.figures(t.summary),
        pw.SizedBox(height: 10),
      ],
      if (t.note.isNotEmpty) ...[
        pw.Text(t.note, style: kit.st(size: 8, color: pdfSoft)),
        pw.SizedBox(height: 6),
      ],
      if (t.rows.length > shown.length) ...[
        pw.Text(
          'Only the first $maxPdfRows of ${t.rows.length} rows are in this PDF. Excel or CSV holds all of them.',
          style: kit.st(size: 8, color: pdfSoft),
        ),
        pw.SizedBox(height: 6),
      ],
      if (t.rows.isEmpty)
        pw.Text(
          'Nothing to show for this period.',
          style: kit.st(size: 9, color: pdfSoft),
        )
      else
        kit.table(
          headers: t.headers,
          rows: [
            for (final r in shown)
              [
                for (var c = 0; c < cols; c++)
                  c < r.length ? pdfCell(r[c]) : '',
              ],
          ],
          right: numeric,
          widths: [for (final c in chars) c * 4.1 + 7],
          totals: totals == null
              ? null
              : [
                  for (var c = 0; c < cols; c++)
                    c < totals!.length ? pdfCell(totals![c]) : '',
                ],
          size: landscape ? 7.5 : 8.0,
        ),
    ];
  }
}

Future<Uint8List> encodePdf(
  ExportTable t, {
  required String shopName,
  required DateTime now,
  ShopProfile? shop,
}) => encodePdfBook(
  [t],
  title: '${t.name} report',
  shopName: shopName,
  now: now,
  shop: shop,
  sectionTitles: false,
);

/// Several tables in one PDF: the shop's details once at the top, then each table under its own heading (a table with a long name is a new section).
Future<Uint8List> encodePdfBook(
  List<ExportTable> tables, {
  required String title,
  required String shopName,
  required DateTime now,
  ShopProfile? shop,
  bool sectionTitles = true,
  List<String> headerLines = const [],
}) async {
  final kit = await PdfKit.load(shop: shop, shopName: shopName);
  final ready = [for (final t in tables) _Ready(t)];
  final landscape = ready.any((r) => r.landscape);
  final stamp = '${formatDate(now)}  ${formatTime(now)}';
  final rowsTotal = ready.fold<int>(0, (s, r) => s + r.shown.length);
  final doc = pw.Document(title: title, author: kit.name);
  doc.addPage(
    pw.MultiPage(
      pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
      maxPages: 600,
      margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 30),
      header: (c) => kit.pageHeader(c, title, now),
      footer: (c) => kit.footer(c, title),
      build: (_) => [
        kit.header(title, [
          ...headerLines,
          'Generated: $stamp',
          if (tables.length == 1)
            '$rowsTotal ${rowsTotal == 1 ? 'row' : 'rows'}${tables.first.rows.length > rowsTotal ? ' of ${tables.first.rows.length}' : ''}',
        ]),
        pw.SizedBox(height: 10),
        for (final r in ready) ...[
          if (sectionTitles) ...[
            pw.SizedBox(height: 8),
            pw.Text(r.t.name, style: kit.st(b: true, size: 12, color: pdfInk)),
            pw.SizedBox(height: 4),
          ],
          ...r.widgets(kit),
        ],
      ],
    ),
  );
  return doc.save();
}
