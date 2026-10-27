/// The shop's logo: any PNG or JPG the owner picks is shrunk to at most 256 pixels and kept as a small PNG, so a huge or
/// damaged picture can never slow down printing or the shop profile. Pure Dart.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

const maxLogoInputBytes = 4 * 1024 * 1024;
const _maxSide = 256;
const _maxOutputBytes = 150 * 1024;

/// The prepared logo as base64 text, or null when the file is not a usable picture.
String? prepareLogo(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > maxLogoInputBytes) return null;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width < 1 || decoded.height < 1) return null;
    if (decoded.width > 8000 || decoded.height > 8000) return null;
    // laid on white FIRST, then shrunk: shrinking a see-through picture mixes its hidden (often black) colour into the edges
    final flat = _onWhite(decoded);
    final small = (flat.width > _maxSide || flat.height > _maxSide)
        ? img.copyResize(flat, width: flat.width >= flat.height ? _maxSide : null, height: flat.height > flat.width ? _maxSide : null, interpolation: img.Interpolation.average)
        : flat;
    final png = img.encodePng(small);
    if (png.length > _maxOutputBytes) return null;
    return base64Encode(png);
  } catch (_) {
    return null;
  }
}

/// A picture with see-through parts laid on white (a solid picture comes back as it is). Printers that drop see-through parts would
/// otherwise print them black.
img.Image _onWhite(img.Image src) {
  if (!src.hasAlpha) return src;
  final out = img.Image(width: src.width, height: src.height, numChannels: 3);
  img.fill(out, color: img.ColorRgb8(255, 255, 255));
  return img.compositeImage(out, src);
}

String? _lastIn;
Uint8List? _lastOut;

/// The logo for a PDF: like [logoBytes], laid on white and as a JPEG. A PNG always goes into a PDF with a see-through layer (the pdf
/// package adds one), which printers can print black; a JPEG never has one. (A logo saved before this may still be see-through.)
Uint8List? pdfLogoBytes(String b64) {
  if (b64.isEmpty) return null;
  if (b64 == _lastIn) return _lastOut;
  final raw = logoBytes(b64);
  Uint8List? out = raw;
  if (raw != null) {
    try {
      final d = img.decodeImage(raw);
      if (d != null) out = img.encodeJpg(_onWhite(d), quality: 95);
    } catch (_) {
      out = raw;
    }
  }
  _lastIn = b64;
  _lastOut = out;
  return out;
}

/// The bytes of a stored logo, or null when there is none or the text is damaged.
Uint8List? logoBytes(String b64) {
  if (b64.isEmpty) return null;
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}
