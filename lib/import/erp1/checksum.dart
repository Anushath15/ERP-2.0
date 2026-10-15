/// ERP 1 writes a SHA-256 checksum into every backup (`_metadata.checksum`, algorithm `sha256`): the hash of the text
/// `JSON.stringify(sortedKeys.map(k => [k, data[k]]))` (desktop/backupFormat.js). This re-computes it the same way, so a backup that was damaged or edited
/// after ERP 1 wrote it is caught before any of it is used. Numbers and strings are written the way JavaScript writes them.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

enum ChecksumResult { ok, mismatch, notPresent, unsupported }

String _jsNumber(num n) {
  if (n is int) return '$n';
  final d = n.toDouble();
  if (d == d.truncateToDouble() && d.abs() < 1e21) {
    return d == 0 ? '0' : d.toInt().toString();
  }
  return '$d';
}

void _write(StringBuffer b, Object? v) {
  if (v == null) {
    b.write('null');
  } else if (v is bool) {
    b.write(v ? 'true' : 'false');
  } else if (v is num) {
    b.write(v.isFinite ? _jsNumber(v) : 'null');
  } else if (v is String) {
    b.write(jsonEncode(v));
  } else if (v is List) {
    b.write('[');
    for (var i = 0; i < v.length; i++) {
      if (i > 0) b.write(',');
      _write(b, v[i]);
    }
    b.write(']');
  } else if (v is Map) {
    b.write('{');
    var first = true;
    for (final e in v.entries) {
      if (!first) b.write(',');
      first = false;
      b.write(jsonEncode('${e.key}'));
      b.write(':');
      _write(b, e.value);
    }
    b.write('}');
  } else {
    b.write('null');
  }
}

/// The text ERP 1 takes its checksum over.
String canonicalText(Map<String, dynamic> data) {
  final b = StringBuffer('[');
  final keys = data.keys.toList()..sort();
  for (var i = 0; i < keys.length; i++) {
    if (i > 0) b.write(',');
    b.write('[');
    b.write(jsonEncode(keys[i]));
    b.write(',');
    _write(b, data[keys[i]]);
    b.write(']');
  }
  b.write(']');
  return b.toString();
}

String checksumOf(Map<String, dynamic> data) => sha256.convert(utf8.encode(canonicalText(data))).toString();

ChecksumResult verifyChecksum(Map<String, dynamic> data, Object? metadata) {
  if (metadata is! Map) return ChecksumResult.notPresent;
  final expected = metadata['checksum'];
  if (expected is! String || expected.isEmpty) return ChecksumResult.notPresent;
  final alg = metadata['checksumAlgorithm'];
  if (alg != null && alg != 'sha256') return ChecksumResult.unsupported;
  return checksumOf(data) == expected.toLowerCase() ? ChecksumResult.ok : ChecksumResult.mismatch;
}
