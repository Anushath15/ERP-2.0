import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/src/pdf/font/ttf_parser.dart';

void main(List<String> args) {
  for (final f in args) {
    final b = File(f).readAsBytesSync();


    final map = TtfParser(ByteData.view(b.buffer)).charToGlyphIndexMap;
    final need = {'rupee': 0x20B9, 'A': 0x41, 'z': 0x7A, '9': 0x39, 'amp': 0x26, 'slash': 0x2F, 'percent': 0x25, 'quote': 0x22, 'apos': 0x27, 'paren': 0x28, 'plus': 0x2B, 'minus': 0x2D, 'times': 0xD7, 'bullet': 0x2022, 'middot': 0xB7, 'ndash': 0x2013, 'at': 0x40, 'hash': 0x23};
    print('$f: ${need.entries.map((e) => '${e.key}=${map.containsKey(e.value) ? "ok" : "MISSING"}').join(' ')}');
  }
}
