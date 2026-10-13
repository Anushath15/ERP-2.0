import 'dart:typed_data';
import 'dart:ui' as ui;

/// Draws a piece of text (for example a Tamil product name) with Flutter's own text engine and returns a PNG.
/// The PDF package cannot shape Tamil vowel signs (spike S3), so printed documents place these images instead of
/// text, for the strings that need it. Results are cached by text + size so a repeated name is drawn only once.
class TextImageRenderer {
  TextImageRenderer({this.cacheSize = 256});
  final int cacheSize;
  final _cache = <String, Uint8List>{};
  int renders = 0;

  /// True when [s] has letters the PDF package cannot shape (anything outside Latin, digits, punctuation).
  static bool needsImage(String s) => s.runes.any((r) => r > 0x024F && r != 0x20B9);

  Future<Uint8List> render(String text, {double fontSize = 14, double maxWidth = 400, bool bold = false, double scale = 3}) async {
    final key = '$text|$fontSize|$maxWidth|$bold|$scale';
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit; // most recently used goes last
      return hit;
    }
    renders++;
    final weight = bold ? ui.FontWeight.w700 : ui.FontWeight.w400;
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'NotoSansTamil', fontSize: fontSize * scale, fontWeight: weight, height: 1.3))
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF000000), fontFamily: 'NotoSansTamil', fontFamilyFallback: const ['NotoSans'], fontWeight: weight))
      ..addText(text);
    final p = builder.build()..layout(ui.ParagraphConstraints(width: maxWidth * scale));
    final w = p.longestLine.ceil().clamp(1, 100000);
    final h = p.height.ceil().clamp(1, 100000);
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    canvas.drawParagraph(p, ui.Offset.zero);
    final img = await rec.endRecording().toImage(w, h);
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    img.dispose();
    _cache[key] = bytes;
    while (_cache.length > cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    return bytes;
  }
}
