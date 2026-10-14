import 'package:sqlite3/common.dart' show SqliteException;
import '../strings.dart';

/// What went wrong, in words a shop owner understands. Never shows a code, a file path or a stack.
String plainError(Object e) {
  const l = Strings();
  if (e is DiskFullException) return e.message;
  if (e is SqliteException) {
    final code = e.resultCode & 0xff;
    return switch (code) {
      5 || 6 => l.errBusy,
      8 => l.errReadOnly,
      10 => l.errIo,
      11 => l.errCorrupt,
      13 => l.errDiskFullSave,
      _ => l.errOtherSql('the computer refused the write'),
    };
  }
  if (e is StateError) return e.message;
  if (e is ArgumentError) return '${e.message ?? l.errSaveGeneric}';
  return l.errSaveGeneric;
}

/// Raised before a save when the disk has too little room left (under 100 MB).
class DiskFullException implements Exception {
  const DiskFullException(this.freeBytes);
  final int freeBytes;
  String get message => const Strings().errDiskGuard((freeBytes / (1024 * 1024)).floor().toString());
}
