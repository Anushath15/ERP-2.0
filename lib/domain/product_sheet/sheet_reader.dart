/// Reads a table from an .xlsx file (the first sheet) or from CSV text, as plain text cells. Pure Dart (zip through `archive`), no spreadsheet package.
/// What Excel, LibreOffice, Google Sheets and our own export write: shared strings, inline strings, numbers; formulas give their last value.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

class SheetReadException implements Exception {
  const SheetReadException(this.message);
  final String message;
  @override
  String toString() => message;
}

String _unescape(String s) => s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos);'), (m) {
      final g = m.group(1)!;
      switch (g) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
      }
      final code = g.startsWith('#x') ? int.tryParse(g.substring(2), radix: 16) : int.tryParse(g.substring(1));
      return code == null || code <= 0 || code > 0x10FFFF ? '' : String.fromCharCode(code);
    });

/// The text of every `t` element inside [xml] (a shared string may be made of several rich-text runs).
String _texts(String xml) => [for (final m in RegExp(r'<t(?:\s[^>]*)?>([\s\S]*?)</t>').allMatches(xml)) _unescape(m.group(1)!)].join();

int _colIndex(String ref) {
  var n = 0;
  for (final c in ref.codeUnits) {
    if (c >= 65 && c <= 90) {
      n = n * 26 + (c - 64);
    } else if (c >= 97 && c <= 122) {
      n = n * 26 + (c - 96);
    } else {
      break;
    }
  }
  return n - 1;
}

String? _file(Archive a, String path) {
  final f = a.findFile(path);
  if (f == null) return null;
  return utf8.decode(f.content as List<int>, allowMalformed: true);
}

/// The cells of the first sheet, row by row (missing cells are empty text, trailing empty cells and empty rows are dropped).
List<List<String>> readXlsxRows(Uint8List bytes, {int maxRows = 200000}) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const SheetReadException('This is not an Excel (.xlsx) file.');
  }
  final workbook = _file(zip, 'xl/workbook.xml');
  if (workbook == null) throw const SheetReadException('This is not an Excel (.xlsx) file.');
  // the first sheet: workbook -> relationship id -> target
  String sheetPath = 'xl/worksheets/sheet1.xml';
  final rid = RegExp(r'<sheet\b[^>]*\br:id="([^"]+)"').firstMatch(workbook)?.group(1);
  final rels = _file(zip, 'xl/_rels/workbook.xml.rels');
  if (rid != null && rels != null) {
    for (final m in RegExp(r'<Relationship\b[^>]*>').allMatches(rels)) {
      final tag = m.group(0)!;
      if (RegExp('Id="${RegExp.escape(rid)}"').hasMatch(tag)) {
        final target = RegExp(r'Target="([^"]+)"').firstMatch(tag)?.group(1);
        if (target != null) sheetPath = target.startsWith('/') ? target.substring(1) : 'xl/$target';
      }
    }
  }
  final sheet = _file(zip, sheetPath);
  if (sheet == null) throw const SheetReadException('The first sheet of this Excel file could not be read.');

  final shared = <String>[];
  final sst = _file(zip, 'xl/sharedStrings.xml');
  if (sst != null) {
    for (final m in RegExp(r'<si\b[^>]*>([\s\S]*?)</si>|<si\b[^>]*/>').allMatches(sst)) {
      shared.add(m.group(1) == null ? '' : _texts(m.group(1)!));
    }
  }

  final out = <List<String>>[];
  for (final rm in RegExp(r'<row\b[^>]*?(?:/>|>([\s\S]*?)</row>)').allMatches(sheet)) {
    final body = rm.group(1);
    if (body == null) continue;
    if (out.length >= maxRows) break;
    final cells = <int, String>{};
    var next = 0;
    for (final cm in RegExp(r'<c\b([^>]*?)(?:/>|>([\s\S]*?)</c>)').allMatches(body)) {
      final attrs = cm.group(1)!;
      final inner = cm.group(2) ?? '';
      final ref = RegExp(r'\br="([A-Za-z]+)[0-9]*"').firstMatch(attrs)?.group(1);
      final col = ref == null ? next : _colIndex(ref);
      next = col + 1;
      final type = RegExp(r'\bt="([^"]+)"').firstMatch(attrs)?.group(1) ?? 'n';
      String value;
      if (type == 'inlineStr') {
        value = _texts(inner);
      } else {
        final v = RegExp(r'<v>([\s\S]*?)</v>').firstMatch(inner)?.group(1);
        if (v == null) {
          value = '';
        } else if (type == 's') {
          final i = int.tryParse(v.trim());
          value = i != null && i >= 0 && i < shared.length ? shared[i] : '';
        } else if (type == 'b') {
          value = v.trim() == '1' ? 'TRUE' : 'FALSE';
        } else {
          value = _unescape(v);
        }
      }
      if (value.isNotEmpty) cells[col] = value;
    }
    if (cells.isEmpty) {
      out.add(const []);
      continue;
    }
    final width = cells.keys.reduce((a, b) => a > b ? a : b) + 1;
    out.add([for (var i = 0; i < width; i++) cells[i] ?? '']);
  }
  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
  }
  return out;
}

/// CSV text (comma or semicolon or tab separated, quotes allowed) as rows of text cells.
List<List<String>> readCsvRows(String text) {
  var t = text.startsWith(String.fromCharCode(0xFEFF)) ? text.substring(1) : text;
  final firstLine = t.split(RegExp(r'\r?\n')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  final sep = [',', ';', '\t'].map((s) => (s, s.allMatches(firstLine).length)).reduce((a, b) => b.$2 > a.$2 ? b : a).$1;
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false, any = false;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (any || row.any((c) => c.isNotEmpty)) rows.add(row);
    row = <String>[];
    any = false;
  }

  for (var i = 0; i < t.length; i++) {
    final c = t[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < t.length && t[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"' && cell.isEmpty) {
      quoted = true;
      any = true;
    } else if (c == sep) {
      endCell();
      any = true;
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < t.length && t[i + 1] == '\n') i++;
      endRow();
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  for (final r in rows) {
    while (r.isNotEmpty && r.last.isEmpty) {
      r.removeLast();
    }
  }
  while (rows.isNotEmpty && rows.last.isEmpty) {
    rows.removeLast();
  }
  return rows;
}
