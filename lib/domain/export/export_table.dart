/// One table of the shop's data written as CSV or a real Excel (.xlsx) file. Pure Dart: no Flutter, no network.
/// SECURITY: text is never a formula. CSV uses the same defence as `csv_safe.dart`; in Excel every text cell is stored as
/// plain text (an inline string), so a name like =HYPERLINK(...) stays text.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../core/csv_safe.dart';

/// An amount of money in paise: written as rupees with two decimals (a real number in Excel).
class Rupees {
  const Rupees(this.paise);
  final int paise;

  String get text {
    final neg = paise < 0;
    final a = paise.abs();
    return '${neg ? '-' : ''}${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
  }
}

/// A quantity kept in thousandths (1500 = 1.5), written with up to three decimals.
class Qty {
  const Qty(this.milli);
  final int milli;

  String get text {
    final neg = milli < 0;
    final a = milli.abs();
    final frac = (a % 1000).toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '');
    return '${neg ? '-' : ''}${a ~/ 1000}${frac.isEmpty ? '' : '.$frac'}';
  }
}

class ExportTable {
  const ExportTable({required this.name, required this.headers, required this.rows});

  /// Used for the file name and the Excel sheet name.
  final String name;
  final List<String> headers;
  final List<List<Object?>> rows;
}

/// Excel's own limit (one row is the header).
const maxExcelRows = 1048575;

String plainCell(Object? v) => switch (v) {
      null => '',
      Rupees r => r.text,
      Qty q => q.text,
      DateTime d => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      _ => v.toString(),
    };

/// CSV with a byte-order mark so Excel reads the rupee sign and any non-English name correctly. Money and quantities are
/// written as plain numbers (a negative amount must stay a number); every text cell goes through the formula defence.
Uint8List encodeCsv(ExportTable t) {
  String cell(Object? c) => (c is Rupees || c is Qty) ? plainCell(c) : (c is DateTime ? plainCell(c) : csvCell(c));
  final lines = <String>[
    csvRow(t.headers),
    for (final r in t.rows) r.map(cell).join(','),
  ];
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('${lines.join('\r\n')}\r\n')]);
}

final _badXml = RegExp('[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F\\uFFFE\\uFFFF]');

String _esc(String s) => s.replaceAll(_badXml, '').replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _colName(int i) {
  var n = i;
  var s = '';
  do {
    s = String.fromCharCode(65 + n % 26) + s;
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return s;
}

String _cell(int col, int row, Object? v, {bool bold = false}) {
  final ref = '${_colName(col)}$row';
  final style = bold ? ' s="1"' : '';
  if (v == null) return '';
  if (v is Rupees) return '<c r="$ref"$style><v>${v.text}</v></c>';
  if (v is Qty) return '<c r="$ref"$style><v>${v.text}</v></c>';
  if (v is int) return '<c r="$ref"$style><v>$v</v></c>';
  if (v is double && v.isFinite) return '<c r="$ref"$style><v>$v</v></c>';
  final text = _esc(plainCell(v));
  return '<c r="$ref"$style t="inlineStr"><is><t xml:space="preserve">$text</t></is></c>';
}

String _sheetName(String n) {
  final clean = n.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  return clean.isEmpty ? 'Sheet1' : (clean.length > 31 ? clean.substring(0, 31) : clean);
}

const _xmlHead = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

/// A real .xlsx file (opens in Excel, LibreOffice and Google Sheets).
Uint8List encodeXlsx(ExportTable t) {
  final sb = StringBuffer('$_xmlHead<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><sheetData>');
  sb.write('<row r="1">');
  for (var c = 0; c < t.headers.length; c++) {
    sb.write(_cell(c, 1, t.headers[c], bold: true));
  }
  sb.write('</row>');
  final rows = t.rows.length > maxExcelRows ? t.rows.sublist(0, maxExcelRows) : t.rows;
  for (var r = 0; r < rows.length; r++) {
    sb.write('<row r="${r + 2}">');
    for (var c = 0; c < rows[r].length && c < 16384; c++) {
      sb.write(_cell(c, r + 2, rows[r][c]));
    }
    sb.write('</row>');
  }
  sb.write('</sheetData></worksheet>');

  const rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  final files = <String, String>{
    '[Content_Types].xml': '$_xmlHead<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '</Types>',
    '_rels/.rels': '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="$rel/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml': '$_xmlHead<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="$rel">'
        '<sheets><sheet name="${_esc(_sheetName(t.name))}" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels': '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="$rel/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="$rel/styles" Target="styles.xml"/></Relationships>',
    'xl/styles.xml': '$_xmlHead<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs></styleSheet>',
    'xl/worksheets/sheet1.xml': sb.toString(),
  };
  final a = Archive();
  files.forEach((name, text) {
    final data = utf8.encode(text);
    a.addFile(ArchiveFile(name, data.length, data));
  });
  return Uint8List.fromList(ZipEncoder().encode(a));
}
