import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Load the bundled fonts so tests (and screenshots) show real text instead of boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
    }
    await loader.load();
  }

  final root = Platform.environment['FLUTTER_ROOT'] ?? 'D:/dev/flutter';
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await load('MaterialIcons', [icons.path]);
  await load('Inter', ['assets/fonts/Inter-Variable.ttf']);
  await load('AtkinsonHyperlegibleNext', ['assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf']);
  await testMain();
}
