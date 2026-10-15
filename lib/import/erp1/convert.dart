/// Reading ERP 1 values safely. ERP 1 stored rupees and quantities as decimal numbers and dates as ISO text; nothing in a backup can be
/// trusted (it may be damaged or hand-edited), so every reader returns null for "cannot use this" and reports what it repaired.
library;

/// What a record's conversion found. Collected per record, then folded into the report.
class Findings {
  final repaired = <String>[];
  final notes = <String>[];
  String? rejected;
  void repair(String s) {
    if (!repaired.contains(s)) repaired.add(s);
  }

  void note(String s) {
    if (!notes.contains(s)) notes.add(s);
  }

  bool get ok => rejected == null;
}

const maxRupees = 1e9; // 100 crore: beyond this a number is a typing mistake, not a price
const maxQty = 1e7;

double? asNum(Object? v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) {
    final t = v.trim().replaceAll(',', '');
    if (t.isEmpty) return null;
    final d = double.tryParse(t);
    return d != null && d.isFinite ? d : null;
  }
  return null;
}

/// Rupees → paise. null when missing/unusable. Negative values are returned as they are (the caller decides if they are allowed).
int? paise(Object? v, Findings f, String what, {bool negativeOk = false, int? missing}) {
  if (v == null || (v is String && v.trim().isEmpty)) return missing;
  final d = asNum(v);
  if (d == null) {
    f.repair('$what is not a number (read as missing)');
    return missing;
  }
  if (d.abs() > maxRupees) {
    f.rejected = '$what is out of range';
    return missing;
  }
  if (d < 0 && !negativeOk) {
    f.repair('$what was negative (read as 0)');
    return 0;
  }
  final scaled = d * 100;
  final r = scaled.roundToDouble();
  if ((scaled - r).abs() > 1e-6) f.repair('$what had more than 2 decimals (rounded to paise)');
  return r.toInt();
}

int? milli(Object? v, Findings f, String what, {bool negativeOk = false, int? missing}) {
  if (v == null || (v is String && v.trim().isEmpty)) return missing;
  final d = asNum(v);
  if (d == null) {
    f.repair('$what is not a number (read as missing)');
    return missing;
  }
  if (d.abs() > maxQty) {
    f.rejected = '$what is out of range';
    return missing;
  }
  if (d < 0 && !negativeOk) {
    f.repair('$what was negative (read as 0)');
    return 0;
  }
  final scaled = d * 1000;
  final r = scaled.roundToDouble();
  if ((scaled - r).abs() > 1e-6) f.repair('$what had more than 3 decimals (rounded)');
  return r.toInt();
}

int percentBp(Object? v, Findings f, {int missing = 0}) {
  final d = asNum(v);
  if (d == null) return missing;
  if (d < 0 || d > 100) {
    f.repair('GST percent out of range (read as $missing)');
    return missing;
  }
  return (d * 100).round();
}

String text(Object? v, {int max = 200, Findings? f, String what = 'text'}) {
  if (v == null) return '';
  var s = v is String ? v : (v is num || v is bool ? '$v' : '');
  s = s.replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '').trim();
  if (s.length > max) {
    f?.repair('$what was longer than $max characters (cut)');
    s = s.substring(0, max);
  }
  return s;
}

bool truthy(Object? v, {bool otherwise = false}) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == 'yes' || s == '1' || s == 'active') return true;
    if (s == 'false' || s == 'no' || s == '0' || s == 'inactive') return false;
  }
  return otherwise;
}

/// A moment read from ERP 1 text. India time (UTC+5:30) is used when the text has no zone; a date alone is taken as noon.
class Moment {
  const Moment(this.ms, this.day);
  final int ms;
  final String day; // YYYY-MM-DD in India time
  String get month => day.substring(0, 7);
}

const _istMs = (5 * 60 + 30) * 60 * 1000;
final _isoRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?)?\s*(Z|[+-]\d{2}:?\d{2})?$');

Moment? moment(Object? v) {
  if (v is num && v.isFinite && v > 946684800000 && v < 4102444800000) return _fromUtcMs(v.toInt());
  if (v is! String) return null;
  final m = _isoRe.firstMatch(v.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final hasTime = m[4] != null;
  final h = hasTime ? int.parse(m[4]!) : 12, mi = hasTime ? int.parse(m[5]!) : 0, s = m[6] == null ? 0 : int.parse(m[6]!);
  if (y < 2000 || y > 2100 || mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || s > 59) return null;
  final probe = DateTime.utc(y, mo, d);
  if (probe.month != mo) return null; // 31 February
  var ms = DateTime.utc(y, mo, d, h, mi, s).millisecondsSinceEpoch;
  final z = m[7];
  if (z == null) {
    ms -= _istMs;
  } else if (z != 'Z') {
    final sign = z[0] == '-' ? -1 : 1;
    final digits = z.substring(1).replaceAll(':', '');
    ms -= sign * (int.parse(digits.substring(0, 2)) * 60 + int.parse(digits.substring(2))) * 60000;
  }
  return _fromUtcMs(ms);
}

Moment _fromUtcMs(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms + _istMs, isUtc: true);
  String two(int n) => n.toString().padLeft(2, '0');
  return Moment(ms, '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}');
}
