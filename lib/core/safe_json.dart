/// SECURITY: reading a file somebody else made (an ERP 1 export, a restored backup). Such a file may be damaged, enormous or built to
/// hurt: a huge size, a million nested brackets. It is read with limits, and every problem becomes one plain exception that the
/// screen can explain, never a crash.
library;

import 'dart:convert';

class SafeJsonException implements Exception {
  SafeJsonException(this.message);
  final String message;
  @override
  String toString() => 'SafeJsonException: $message';
}

/// Largest file we read: 50 MB of text (a whole ERP 1 export is far smaller).
const maxJsonChars = 50 * 1024 * 1024;

/// Most nested levels allowed (real data is 4 or 5 deep).
const maxJsonDepth = 40;

/// Most values (objects, lists, strings, numbers) allowed in one file.
const maxJsonNodes = 5000000;

Object? readSafeJson(String text, {int maxChars = maxJsonChars, int maxDepth = maxJsonDepth, int maxNodes = maxJsonNodes}) {
  if (text.length > maxChars) throw SafeJsonException('The file is too big to read (more than $maxChars characters).');
  // depth is checked BEFORE decoding, so a file of a million "[" cannot exhaust the program's stack
  var depth = 0;
  var inString = false;
  var escape = false;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (inString) {
      if (escape) {
        escape = false;
      } else if (c == 0x5C) {
        escape = true;
      } else if (c == 0x22) {
        inString = false;
      }
      continue;
    }
    if (c == 0x22) {
      inString = true;
    } else if (c == 0x5B || c == 0x7B) {
      if (++depth > maxDepth) throw SafeJsonException('The file is nested too deeply to be a real export.');
    } else if (c == 0x5D || c == 0x7D) {
      depth--;
    }
  }
  final Object? data;
  try {
    data = jsonDecode(text);
  } on FormatException catch (e) {
    throw SafeJsonException('The file is damaged or is not an export file (${e.message}).');
  }
  var nodes = 0;
  final stack = <Object?>[data];
  while (stack.isNotEmpty) {
    final v = stack.removeLast();
    if (++nodes > maxNodes) throw SafeJsonException('The file holds too many values to be a real export.');
    if (v is List) {
      stack.addAll(v);
    } else if (v is Map) {
      stack.addAll(v.values);
    }
  }
  return data;
}
