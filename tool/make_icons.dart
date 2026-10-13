// Builds every app icon from the one source picture (assets/branding/ask-logo.png, the same logo as ERP 1.0).
//   dart run tool/make_icons.dart
// Writes: Windows .ico, web favicon and PWA icons (normal and maskable), Android launcher icons, macOS icon set, and a
// small in-app copy (assets/branding/ask-logo-256.png).
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

img.Image resize(img.Image src, int size) => img.copyResize(src, width: size, height: size, interpolation: img.Interpolation.cubic);

void savePng(String path, img.Image im) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(im));
  stdout.writeln('wrote $path (${im.width}px)');
}

/// A square icon for "maskable" use: the logo at 72% on a solid navy field, so any mask shape keeps the logo whole.
img.Image maskable(img.Image src, int size) {
  final bg = img.Image(width: size, height: size, numChannels: 4);
  img.fill(bg, color: img.ColorRgba8(24, 39, 58, 255));
  final inner = (size * 0.72).round();
  img.compositeImage(bg, resize(src, inner), dstX: (size - inner) ~/ 2, dstY: (size - inner) ~/ 2);
  return bg;
}

/// An .ico file holding PNG pictures of several sizes (Windows Vista and later read PNG inside .ico).
Uint8List ico(img.Image src, List<int> sizes) {
  final pngs = [for (final s in sizes) img.encodePng(resize(src, s))];
  final header = ByteData(6 + 16 * sizes.length)
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, sizes.length, Endian.little);
  var offset = 6 + 16 * sizes.length;
  for (var i = 0; i < sizes.length; i++) {
    final s = sizes[i];
    final at = 6 + 16 * i;
    header
      ..setUint8(at, s >= 256 ? 0 : s)
      ..setUint8(at + 1, s >= 256 ? 0 : s)
      ..setUint8(at + 2, 0)
      ..setUint8(at + 3, 0)
      ..setUint16(at + 4, 1, Endian.little)
      ..setUint16(at + 6, 32, Endian.little)
      ..setUint32(at + 8, pngs[i].length, Endian.little)
      ..setUint32(at + 12, offset, Endian.little);
    offset += pngs[i].length;
  }
  final out = BytesBuilder()..add(header.buffer.asUint8List());
  for (final p in pngs) {
    out.add(p);
  }
  return out.toBytes();
}

void main() {
  final src = img.decodePng(File('assets/branding/ask-logo.png').readAsBytesSync())!;

  // in-app copy
  savePng('assets/branding/ask-logo-256.png', resize(src, 256));

  // Windows
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(ico(src, [16, 24, 32, 48, 64, 128, 256]));
  stdout.writeln('wrote windows/runner/resources/app_icon.ico');

  // Web
  savePng('web/favicon.png', resize(src, 64));
  savePng('web/icons/Icon-192.png', resize(src, 192));
  savePng('web/icons/Icon-512.png', resize(src, 512));
  savePng('web/icons/Icon-maskable-192.png', maskable(src, 192));
  savePng('web/icons/Icon-maskable-512.png', maskable(src, 512));

  // Android launcher icons
  const android = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
  android.forEach((d, s) => savePng('android/app/src/main/res/mipmap-$d/ic_launcher.png', resize(src, s)));

  // macOS
  for (final s in [16, 32, 64, 128, 256, 512, 1024]) {
    savePng('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$s.png', resize(src, s));
  }
}
