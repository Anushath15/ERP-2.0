import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/print/text_image.dart';

/// Tamil strings on printed documents are drawn by Flutter's text engine (the PDF package cannot shape Tamil vowel
/// signs). This test draws strings with every kind of vowel sign and compares them with a reference image.
void main() {
  const sample = 'கொடுக்கப்பட்ட கோப்பை கெட்டி கை கௌரவம் ஸ்ரீ க்ஷ';
  testWidgets('Tamil vowel signs render like the reference image', (tester) async {
    final r = TextImageRenderer();
    late Uint8List png;
    await tester.runAsync(() async {
      png = await r.render(sample, fontSize: 16, maxWidth: 500);
    });
    final image = MemoryImage(png);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(backgroundColor: Colors.white, body: Align(alignment: Alignment.topLeft, child: RepaintBoundary(child: Image(image: image, filterQuality: FilterQuality.none))))));
    await tester.runAsync(() async {
      await precacheImage(image, tester.element(find.byType(Image)));
    });
    await tester.pump();
    await expectLater(find.byType(Image), matchesGoldenFile('goldens/tamil_vowels.png'));
  });

  testWidgets('needsImage is true only for non-Latin text; results are cached', (tester) async {
    expect(TextImageRenderer.needsImage('HACKSAW BLADE 1/2"'), false);
    expect(TextImageRenderer.needsImage('₹ 1,200.00'), false);
    expect(TextImageRenderer.needsImage('PVC குழாய்'), true);
    final r = TextImageRenderer();
    await tester.runAsync(() async {
      final a = await r.render('நீர் குழாய்');
      final b = await r.render('நீர் குழாய்');
      expect(identical(a, b), true);
      expect(r.renders, 1);
    });
  });
}
