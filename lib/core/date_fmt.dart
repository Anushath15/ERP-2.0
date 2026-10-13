String two(int n) => n.toString().padLeft(2, '0');

/// DD/MM/YYYY (the shop's format).
String formatDate(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${two(d.minute)} ${d.hour < 12 ? 'am' : 'pm'}';
}

String formatDateTime(DateTime d) => '${formatDate(d)}  ${formatTime(d)}';

/// Reads DD/MM/YYYY (what [formatDate] writes). Returns null when it is not a real date.
DateTime? parseDmy(String s) {
  final m = RegExp(r'^\s*(\d{1,2})/(\d{1,2})/(\d{4})\s*$').firstMatch(s);
  if (m == null) return null;
  final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), y = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  return dt.year == y && dt.month == mo && dt.day == d ? dt : null;
}
