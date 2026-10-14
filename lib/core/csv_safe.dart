/// SECURITY: CSV for Excel and Google Sheets. A cell that STARTS with = + - @ (or a tab or carriage return) is run as a formula
/// when the file is opened, so a customer called "=HYPERLINK(...)" could steal data or run commands. Such text gets a leading
/// apostrophe (the usual defence), and every cell is quoted when it needs to be. Numbers are written as numbers.
library;

const _maxCell = 32000; // Excel's own limit

/// One safe CSV cell.
String csvCell(Object? value) {
  if (value == null) return '';
  if (value is num) return value.toString();
  if (value is bool) return value ? 'true' : 'false';
  var s = value.toString();
  if (s.length > _maxCell) s = s.substring(0, _maxCell);
  if (s.isNotEmpty && (s.startsWith('=') || s.startsWith('+') || s.startsWith('-') || s.startsWith('@') || s.startsWith('\t') || s.startsWith('\r'))) {
    s = "'$s";
  }
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
    s = '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String csvRow(List<Object?> cells) => cells.map(csvCell).join(',');

/// Rows joined with CRLF (what Excel expects).
String toCsv(List<List<Object?>> rows) => '${rows.map(csvRow).join('\r\n')}\r\n';
