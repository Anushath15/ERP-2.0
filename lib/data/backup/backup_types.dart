/// Local backups: what a backup file is called, what is known about it, and which ones to keep. Pure Dart, no files, so every rule can be tested.
library;

enum BackupKind { auto, manual, closing, safety, archive }

/// Why a backup (or a restore check) could not be done, in words the owner can act on. Never contains a code or a stack trace.
class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupInfo {
  BackupInfo({required this.path, required this.name, required this.at, required this.device, required this.appVersion, required this.kind, this.fy = '', this.bytes = 0});
  final String path, name, device, appVersion, fy;
  final DateTime at;
  final BackupKind kind;
  final int bytes;

  static final _re = RegExp(r'^ASKERP_(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})_([0-9a-f]{1,8})_v(.+?)_(auto|manual|closing|safety|archive)(?:-(FY\d{4}-\d{2}))?\.sqlite$');

  /// `ASKERP_20261016-143012_ab12cd34_v2.0.0-proto.3_auto.sqlite`: date, time, this computer, the program version, why it was made.
  static String fileName({required DateTime at, required String device, required String appVersion, required BackupKind kind, String fy = ''}) {
    String two(int n) => n.toString().padLeft(2, '0');
    final dev = device.replaceAll(RegExp(r'[^0-9a-f]'), '');
    final d8 = (dev.length >= 8 ? dev.substring(0, 8) : dev.padRight(8, '0'));
    final safeVer = appVersion.replaceAll(RegExp(r'[^0-9A-Za-z.\-]'), '');
    return 'ASKERP_${at.year.toString().padLeft(4, '0')}${two(at.month)}${two(at.day)}-${two(at.hour)}${two(at.minute)}${two(at.second)}_${d8}_v${safeVer}_${kind.name}${fy.isEmpty ? '' : '-$fy'}.sqlite';
  }

  /// null when the name is not one of ours (such a file is never offered as a backup and never deleted).
  static BackupInfo? fromName(String path, String name, {int bytes = 0}) {
    final m = _re.firstMatch(name);
    if (m == null) return null;
    final at = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), int.parse(m[4]!), int.parse(m[5]!), int.parse(m[6]!));
    return BackupInfo(path: path, name: name, at: at, device: m[7]!, appVersion: m[8]!, kind: BackupKind.values.firstWhere((k) => k.name == m[9]), fy: m[10] ?? '', bytes: bytes);
  }
}

/// What a backup file holds, read from inside it.
class BackupContents {
  const BackupContents({required this.products, required this.customers, required this.bills, this.lastBill, this.madeAt, this.device = '', this.appVersion = '', this.schema = 0, this.shopId = ''});
  final int products, customers, bills, schema;
  final DateTime? lastBill, madeAt;
  final String device, appVersion, shopId;
}

enum RestoreProblem { none, notDatabase, corrupt, tooNew, otherShop, unknownShop }

class BackupInspection {
  const BackupInspection(this.problem, {this.contents, this.detail = ''});
  final RestoreProblem problem;
  final BackupContents? contents;
  final String detail;
  bool get ok => problem == RestoreProblem.none;
}

/// Which backups to keep: the newest of each of the last 7 days that have one, of the last 4 weeks that have one, of the last 12 months that have one,
/// and always the newest of all. Only automatic, manual and closing backups take part; safety copies and yearly archives are never removed by this.
Set<String> backupsToKeep(List<BackupInfo> all, {int days = 7, int weeks = 4, int months = 12}) {
  final items = all.where((b) => b.kind == BackupKind.auto || b.kind == BackupKind.manual || b.kind == BackupKind.closing).toList()..sort((a, b) => b.at.compareTo(a.at));
  final keep = <String>{};
  if (items.isEmpty) return keep;
  keep.add(items.first.name);
  void pick(int count, String Function(DateTime) key) {
    final seen = <String>{};
    for (final b in items) {
      final k = key(b.at);
      if (seen.length >= count && !seen.contains(k)) break;
      if (seen.add(k)) keep.add(b.name); // items are newest first, so the first one seen for a period is its newest
    }
  }

  String two(int n) => n.toString().padLeft(2, '0');
  pick(days, (t) => '${t.year}-${two(t.month)}-${two(t.day)}');
  pick(weeks, (t) {
    // week = the Monday on or before the date
    final monday = DateTime(t.year, t.month, t.day).subtract(Duration(days: t.weekday - 1));
    return '${monday.year}-${two(monday.month)}-${two(monday.day)}';
  });
  pick(months, (t) => '${t.year}-${two(t.month)}');
  return keep;
}

/// The financial year (April to March) a date falls in, as `FY2025-26`.
String financialYearOf(DateTime t) {
  final start = t.month >= 4 ? t.year : t.year - 1;
  return 'FY$start-${((start + 1) % 100).toString().padLeft(2, '0')}';
}

/// The financial year before the one [t] is in.
String previousFinancialYear(DateTime t) {
  final start = (t.month >= 4 ? t.year : t.year - 1) - 1;
  return 'FY$start-${((start + 1) % 100).toString().padLeft(2, '0')}';
}

/// How old the last backup is, as the Home page colours it: fine, amber after 2 days, red after 7 (or when there has never been one).
enum BackupFreshness { fresh, amber, red }

BackupFreshness freshnessOf(DateTime? last, DateTime now) {
  if (last == null) return BackupFreshness.red;
  final age = now.difference(last);
  if (age >= const Duration(days: 7)) return BackupFreshness.red;
  if (age >= const Duration(days: 2)) return BackupFreshness.amber;
  return BackupFreshness.fresh;
}
