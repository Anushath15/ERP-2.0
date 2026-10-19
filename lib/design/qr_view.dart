import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// A QR code, drawn as it is printed: black squares on white with the quiet border scanners need, whatever the app theme.
/// [data] longer than a QR code can hold shows nothing (never a crash).
class QrView extends StatelessWidget {
  const QrView({super.key, required this.data, this.size = 120});
  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    QrImage? image;
    try {
      image = QrImage(QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M));
    } catch (_) {
      image = null;
    }
    if (image == null) return SizedBox(width: size, height: size);
    return Semantics(label: 'QR code', image: true, child: CustomPaint(size: Size.square(size), painter: _QrPainter(image)));
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);
  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    const quiet = 2; // modules of white around the code
    final n = image.moduleCount;
    final unit = size.width / (n + 2 * quiet);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final dark = Paint()..color = Colors.black;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (image.isDark(r, c)) canvas.drawRect(Rect.fromLTWH((c + quiet) * unit, (r + quiet) * unit, unit + 0.4, unit + 0.4), dark);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}
