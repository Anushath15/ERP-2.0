/// The bill in a thermal printer's own language (ESC/POS, which almost every 58 mm and 80 mm receipt printer understands), from the same
/// [PrintLayout] the roll PDF uses, so both say the same. Plain text padded to the roll's letters per line; the shop name and the grand total
/// in tall letters; the UPI QR made by the printer itself; then the paper is cut and, for a cash bill, the cash drawer opens.
///
/// SECURITY: every piece of text (product names, the customer, the shop's footer) has its control bytes removed before it is sent, so text
/// typed into the program can never become a printer command (opening the drawer, cutting the paper, changing settings).
library;

import 'dart:convert';
import 'dart:typed_data';
import 'print_layout.dart';

/// Letters per line of an 80 mm roll and of a 58 mm roll (the printer's normal font).
const thermalChars80 = 48, thermalChars58 = 32;

/// What the encoder needs to know about the printer and the bill.
class EscPosOptions {
  const EscPosOptions({required this.chars, this.cut = true, this.drawer = false, this.qrSize = 6});

  /// Letters per line (32 for 58 mm, 48 for 80 mm, 42 for some 80 mm printers).
  final int chars;
  final bool cut;

  /// Open the cash drawer (plugged into the printer) after the bill.
  final bool drawer;

  /// QR code module size, 1 to 16 dots.
  final int qrSize;
}

/// Builds ESC/POS bytes, one command at a time.
class EscPos {
  final _b = BytesBuilder(copy: false);
  static const _esc = 0x1B, _gs = 0x1D, _lf = 0x0A;

  Uint8List get bytes => _b.toBytes();

  void _raw(List<int> v) => _b.add(v);

  /// ESC @ (start fresh) and the normal PC437 character table.
  void init() => _raw([_esc, 0x40, _esc, 0x74, 0x00]);

  /// 0 left, 1 centre, 2 right.
  void align(int a) => _raw([_esc, 0x61, a.clamp(0, 2)]);
  void bold(bool on) => _raw([_esc, 0x45, on ? 1 : 0]);

  /// Tall letters (double height, same width, so long names still fit); [wide] also doubles the width.
  void size({bool tall = false, bool wide = false}) => _raw([_gs, 0x21, (wide ? 0x10 : 0) | (tall ? 0x01 : 0)]);

  void line([String s = '']) {
    _raw(printableBytes(s));
    _raw([_lf]);
  }

  void feed(int lines) => _raw([_esc, 0x64, lines.clamp(0, 10)]);

  /// GS V 66 0: feed to the cutter and cut (a partial cut that keeps the slip hanging, on printers that have it).
  void cut() => _raw([_gs, 0x56, 0x42, 0x00]);

  /// ESC p: a short pulse on the drawer plug (pin 2), as the drawer makers ask.
  void openDrawer() => _raw([_esc, 0x70, 0x00, 0x19, 0xFA]);

  /// The printer draws the QR itself (GS ( k): model 2, size [module], error level M.
  void qr(String data, {int module = 6}) {
    final d = latin1.encode(data.replaceAll(RegExp(r'[^\x20-\x7E]'), ''));
    if (d.isEmpty || d.length > 700) return;
    final n = d.length + 3;
    _raw([_gs, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]); // model 2
    _raw([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, module.clamp(1, 16)]); // size
    _raw([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]); // error correction M
    _raw([_gs, 0x28, 0x6B, n & 0xFF, n >> 8, 0x31, 0x50, 0x30, ...d]); // store
    _raw([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]); // print
  }
}

/// Text the printer can show: the rupee sign as "Rs.", other letters outside plain English shown as "?", and NO control bytes
/// (tabs and line breaks become spaces; everything below 0x20 and 0x7F is dropped).
String printableText(String s) {
  final t = s.replaceAll('₹ ', 'Rs.').replaceAll('₹', 'Rs.').replaceAll(RegExp(r'[\t\r\n]'), ' ');
  final out = StringBuffer();
  for (final r in t.runes) {
    if (r >= 0x20 && r < 0x7F) {
      out.writeCharCode(r);
    } else if (r >= 0x80) {
      out.write('?');
    }
  }
  return out.toString();
}

List<int> printableBytes(String s) => ascii.encode(printableText(s));

/// Splits [s] into lines of at most [width] letters, at spaces where it can.
List<String> wrapText(String s, int width) {
  final t = printableText(s).trim();
  if (width < 1) return [t];
  if (t.isEmpty) return const [''];
  final out = <String>[];
  var cur = '';
  for (final word in t.split(RegExp(r' +'))) {
    var w = word;
    while (w.length > width) {
      if (cur.isNotEmpty) {
        out.add(cur);
        cur = '';
      }
      out.add(w.substring(0, width));
      w = w.substring(width);
    }
    if (cur.isEmpty) {
      cur = w;
    } else if (cur.length + 1 + w.length <= width) {
      cur = '$cur $w';
    } else {
      out.add(cur);
      cur = w;
    }
  }
  if (cur.isNotEmpty) out.add(cur);
  return out;
}

/// [left] and [right] on one line of [width] letters, the right one against the edge; when both do not fit, the left one gets its own
/// line(s) first.
List<String> twoCols(String left, String right, int width) {
  final l = printableText(left).trimRight(), r = printableText(right).trim(); // a left indent is kept
  if (r.isEmpty) return wrapText(l, width);
  if (l.length + 1 + r.length <= width) return ['$l${' ' * (width - l.length - r.length)}$r'];
  return [...wrapText(l, width), r.length >= width ? r.substring(0, width) : '${' ' * (width - r.length)}$r'];
}

/// The bill or estimate as ESC/POS bytes; [paidText] is the "Paid in full" words.
Uint8List encodeEscPosBill(PrintLayout p, EscPosOptions o, {String paidText = 'Paid in full'}) {
  final w = o.chars.clamp(24, 64);
  final e = EscPos()..init();
  final rule = '-' * w;

  // the shop: its name in tall bold letters, the rest centred
  e.align(1);
  for (var i = 0; i < p.header.length; i++) {
    if (i == 0) {
      e
        ..bold(true)
        ..size(tall: true);
      for (final s in wrapText(p.header[i].text, w)) {
        e.line(s);
      }
      e
        ..size()
        ..bold(false);
    } else {
      for (final s in wrapText(p.header[i].text, w)) {
        e.line(s);
      }
    }
  }
  if (p.header.isNotEmpty) e.line(rule);
  e
    ..bold(true)
    ..line(p.title)
    ..bold(false)
    ..align(0);

  // who and when: the left and right pieces side by side when they fit
  final rows = p.metaLeft.length > p.metaRight.length ? p.metaLeft.length : p.metaRight.length;
  for (var i = 0; i < rows; i++) {
    final l = i < p.metaLeft.length ? p.metaLeft[i].text : '';
    final r = i < p.metaRight.length ? p.metaRight[i].text : '';
    for (final s in twoCols(l, r, w)) {
      e.line(s);
    }
  }
  e.line(rule);

  // the items: the name (wrapped), then "qty x rate" and the amount against the right edge
  e.bold(true);
  for (final s in twoCols('${p.tableHead[1]}  (${p.tableHead[2]} x ${p.tableHead[3]})', p.tableHead[4], w)) {
    e.line(s);
  }
  e
    ..bold(false)
    ..line(rule);
  for (final it in p.items) {
    for (final s in wrapText('${it.number}. ${it.name}', w)) {
      e.line(s);
    }
    for (final s in twoCols('   ${it.qty} x ${it.rate}', it.amount, w)) {
      e.line(s);
    }
  }
  e.line(rule);

  // the totals; the grand total in tall bold letters
  for (final t in p.totals) {
    if (t.big) {
      e
        ..bold(true)
        ..size(tall: true);
    } else if (t.bold) {
      e.bold(true);
    }
    for (final s in twoCols(t.label, t.value, w)) {
      e.line(s);
    }
    e
      ..size()
      ..bold(false);
  }
  if (p.paidInFull) {
    e
      ..align(1)
      ..bold(true)
      ..line(paidText)
      ..bold(false)
      ..align(0);
  }

  // the QR for what is still due, made by the printer
  if (p.upiData.isNotEmpty) {
    e
      ..feed(1)
      ..align(1)
      ..qr(p.upiData, module: o.qrSize);
    for (final s in wrapText(p.upiLabel, w)) {
      e.line(s);
    }
    e.align(0);
  }

  e
    ..line(rule)
    ..align(1);
  for (final s in wrapText(p.note, w)) {
    e.line(s);
  }
  e
    ..align(0)
    ..feed(4);
  if (o.cut) e.cut();
  if (o.drawer) e.openDrawer();
  return e.bytes;
}

/// A short slip to try the printer: the shop name, a ruler as wide as the line (to check the letters per line), a small QR, then the cut.
Uint8List encodeEscPosTestSlip({required String shopName, required String title, required String message, required String when, required EscPosOptions o}) {
  final w = o.chars.clamp(24, 64);
  final ruler = StringBuffer();
  for (var i = 1; i <= w; i++) {
    ruler.write(i % 10);
  }
  final e = EscPos()
    ..init()
    ..align(1)
    ..bold(true)
    ..size(tall: true);
  for (final s in wrapText(shopName, w)) {
    e.line(s);
  }
  e
    ..size()
    ..line(title)
    ..bold(false)
    ..line(when)
    ..align(0)
    ..line(ruler.toString())
    ..line('-' * w);
  for (final s in wrapText(message, w)) {
    e.line(s);
  }
  e
    ..align(1)
    ..feed(1)
    ..qr('ASK ERP 2.0', module: o.qrSize)
    ..align(0)
    ..feed(4);
  if (o.cut) e.cut();
  if (o.drawer) e.openDrawer();
  return e.bytes;
}

/// A network printer's address: an IPv4 address in the shop's own network (or this computer), with the port (9100 when not given).
/// Null when it is not one: bills are never sent outside the shop.
({String host, int port})? parsePrinterAddress(String text) {
  final m = RegExp(r'^\s*(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?::(\d{1,5}))?\s*$').firstMatch(text);
  if (m == null) return null;
  final o = [for (var i = 1; i <= 4; i++) int.parse(m.group(i)!)];
  if (o.any((x) => x > 255)) return null;
  final port = m.group(5) == null ? 9100 : int.parse(m.group(5)!);
  if (port < 1 || port > 65535) return null;
  final local = o[0] == 10 || o[0] == 127 || (o[0] == 172 && o[1] >= 16 && o[1] <= 31) || (o[0] == 192 && o[1] == 168) || (o[0] == 169 && o[1] == 254);
  if (!local) return null;
  return (host: o.join('.'), port: port);
}
