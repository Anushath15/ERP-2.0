String two(int n) => n.toString().padLeft(2, '0');

/// DD/MM/YYYY (the shop's format).
String formatDate(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${two(d.minute)} ${d.hour < 12 ? 'am' : 'pm'}';
}

String formatDateTime(DateTime d) => '${formatDate(d)}  ${formatTime(d)}';
