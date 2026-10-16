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
    final small = (decoded.width > _maxSide || decoded.height > _maxSide)
        ? img.copyResize(decoded, width: decoded.width >= decoded.height ? _maxSide : null, height: decoded.height > decoded.width ? _maxSide : null, interpolation: img.Interpolation.average)
        : decoded;
    final png = img.encodePng(small);
    if (png.length > _maxOutputBytes) return null;
    return base64Encode(png);
  } catch (_) {
    return null;
  }
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
