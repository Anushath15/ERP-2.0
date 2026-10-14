/// SECURITY: ONE set of rules for every text a person types: names, phones, notes, towns, addresses, GSTIN, UPI ids and messages.
/// Length limits, no control characters, no bidirectional-override or zero-width characters (they can disguise text), trimmed.
/// Used by every form ([showFormSheet]), by the text boxes (through [safeInput]) and before anything is saved.
library;

import 'package:flutter/services.dart';
import '../domain/credit/reminder.dart' show normalizePhone;

enum TextKind { name, town, address, note, phone, gstin, upi, email, message }

enum TextProblem { tooLong, badChars, notGstin, notUpi, notPhone }

/// The longest text of each kind, and whether line breaks are allowed.
int maxLength(TextKind k) => switch (k) {
      TextKind.name => 80,
      TextKind.town => 60,
      TextKind.address => 200,
      TextKind.note => 500,
      TextKind.phone => 20,
      TextKind.gstin => 15,
      TextKind.upi => 100,
      TextKind.email => 120,
      TextKind.message => 1500,
    };

bool allowsLineBreaks(TextKind k) => k == TextKind.note || k == TextKind.message || k == TextKind.address;

// control characters (except tab and line feed, handled separately), the bidirectional controls U+200E-200F, U+202A-202E,
// U+2066-2069, the zero-width characters U+200B-200D, U+2060, U+FEFF, and the line/paragraph separators U+2028-2029
final _forbidden = RegExp(r'[\u0000-\u0008\u000B-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF\u2028\u2029]');

/// The text with everything forbidden removed, trimmed, and (for single-line text) with spaces and line breaks made into single spaces.
String cleanText(String s, {bool multiline = false}) {
  var t = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll(_forbidden, '');
  if (multiline) {
    t = t.split('\n').map((l) => l.replaceAll('\t', ' ').replaceAll(RegExp(r' {2,}'), ' ').trimRight()).join('\n');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return t.trim();
  }
  return t.replaceAll(RegExp(r'[\n\t ]+'), ' ').trim();
}

final _gstin = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');
final _upi = RegExp(r'^[A-Za-z0-9._\-]{2,64}@[A-Za-z0-9.\-]{2,64}$');

/// What is wrong with [raw] for this kind of text, or null when it is fine. Empty is always fine here ("required" is the form's job).
TextProblem? checkText(TextKind kind, String raw) {
  final multi = allowsLineBreaks(kind);
  final noBreaks = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (_forbidden.hasMatch(noBreaks)) return TextProblem.badChars;
  if (!multi && noBreaks.contains('\n')) return TextProblem.badChars;
  final t = cleanText(raw, multiline: multi);
  if (t.isEmpty) return null;
  // numbers and ids are judged by their shape first (a 16-character GSTIN is "not a GSTIN"); free text by its length
  if (t.length > maxLength(kind) && kind != TextKind.gstin && kind != TextKind.phone && kind != TextKind.upi) return TextProblem.tooLong;
  switch (kind) {
    case TextKind.gstin:
      return _gstin.hasMatch(t.toUpperCase()) ? null : TextProblem.notGstin;
    case TextKind.upi:
      return t.length <= maxLength(kind) && _upi.hasMatch(t) ? null : TextProblem.notUpi;
    case TextKind.phone:
      return normalizePhone(t) == null ? TextProblem.notPhone : null;
    case TextKind.email:
      return RegExp(r'^[^@\s]{1,64}@[^@\s]{1,64}\.[^@\s]{2,}$').hasMatch(t) ? null : TextProblem.badChars;
    default:
      return null;
  }
}

/// What to store: cleaned, and GSTIN in capitals.
String storeText(TextKind kind, String raw) {
  final t = cleanText(raw, multiline: allowsLineBreaks(kind));
  return kind == TextKind.gstin ? t.toUpperCase() : t;
}

/// For every text box: removes forbidden characters as they are typed and cuts the text at the limit.
TextInputFormatter safeInput(TextKind kind) => _SafeInput(kind);

class _SafeInput extends TextInputFormatter {
  _SafeInput(this.kind);
  final TextKind kind;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final multi = allowsLineBreaks(kind);
    var t = newValue.text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll(_forbidden, '');
    if (!multi) t = t.replaceAll('\n', ' ').replaceAll('\t', ' ');
    if (t.length > maxLength(kind)) t = t.substring(0, maxLength(kind));
    if (t == newValue.text) return newValue;
    final offset = newValue.selection.baseOffset.clamp(0, t.length);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: offset));
  }
}
