/// SECURITY: the ONE place that turns text into a file name. Anything a person typed (a customer name, a note) can end up in a
/// file name (a statement PDF, an export, a backup), so it is cleaned here and nowhere else:
///  * only letters A-Z a-z, digits, space, dash, underscore and dot are kept; everything else (path separators, colons, quotes,
///    control characters, the right-to-left override, other scripts) becomes an underscore;
///  * no "..", no leading dot or space, no trailing dots or spaces (Windows drops them silently), no drive letter;
///  * the Windows reserved names (CON, PRN, AUX, NUL, COM1-9, LPT1-9) are changed, with or without an extension;
///  * at most 80 characters before the extension; never empty.
library;

const _reserved = {'CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'};

String _clean(String s) {
  var out = s.replaceAll(RegExp(r'[^A-Za-z0-9 _.\-]'), '_');
  out = out.replaceAll(RegExp(r'\.{2,}'), '_'); // no ".."
  out = out.replaceAll(RegExp(r'_{2,}'), '_');
  return out;
}

/// Turns [input] into a safe file name. [fallback] is used when nothing usable is left.
String safeFileName(String input, {String fallback = 'file', int maxBase = 80}) {
  var text = input.replaceFirst(RegExp(r'^\s*[A-Za-z]:'), ''); // a drive letter ("C:") is dropped
  // The extension is the last ".xxx" of at most 10 letters or digits (".pdf", ".csv"); the rest is the name.
  String ext = '';
  final m = RegExp(r'\.([A-Za-z0-9]{1,10})\s*$').firstMatch(text);
  if (m != null) {
    ext = m.group(1)!.toLowerCase();
    text = text.substring(0, m.start);
  }
  var base = _clean(text);
  base = base.replaceAll(RegExp(r'^[ ._]+|[ ._]+$'), '');
  if (base.length > maxBase) base = base.substring(0, maxBase).replaceAll(RegExp(r'[ ._]+$'), '');
  if (base.isEmpty) base = _clean(fallback).replaceAll(RegExp(r'^[ ._]+|[ ._]+$'), '');
  if (base.isEmpty) base = 'file';
  // reserved device names: the part before the first dot decides (CON.tar.gz is as bad as CON)
  final stem = base.split('.').first.trim().toUpperCase();
  if (_reserved.contains(stem)) base = '_$base';
  return ext.isEmpty ? base : '$base.$ext';
}

/// True when [path] is a file INSIDE [folder] after resolving "." and ".." (a folder with the same start, or the folder itself,
/// is not inside). Works on Windows and POSIX style paths.
bool isInside(String folder, String path) {
  List<String> parts(String p) {
    final out = <String>[];
    for (final s in p.replaceAll('\\', '/').split('/')) {
      if (s.isEmpty || s == '.') continue;
      if (s == '..') {
        if (out.isNotEmpty) out.removeLast();
        continue;
      }
      out.add(s.toLowerCase());
    }
    return out;
  }

  final f = parts(folder), p = parts(path);
  if (p.length <= f.length) return false;
  for (var i = 0; i < f.length; i++) {
    if (f[i] != p[i]) return false;
  }
  return true;
}
