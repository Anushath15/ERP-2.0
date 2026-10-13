// Frame-timing run of the billing flow with Full animations, in a REAL build (profile mode), not in a widget test.
//
//   flutter run -t tool/perf/frame_timing_main.dart -d windows --profile --dart-define=PERF_OUT=D:/path/result.json
//
// It drives the app by itself: adds 100 bill lines, types a search, flips through ten pages, twice:
//   1. "normal"    : the computer as it is
//   2. "contended" : the same flow while busy isolates keep most CPU cores 100% busy (a throttled, shared machine)
// and writes the average, 95th percentile and worst frame time (build + raster) of each run.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:erp2/app.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/router.dart';

const outPath = String.fromEnvironment('PERF_OUT');

Future<void> burn(SendPort port) async {
  // busy loop until the process ends
  final sw = Stopwatch()..start();
  var x = 0.0;
  while (true) {
    x += math.sqrt(sw.elapsedMicroseconds.toDouble());
    if (x > 1e18) x = 0;
  }
}

class Stats {
  Stats(this.frames);
  final List<FrameTiming> frames;
  List<double> get total => [for (final f in frames) f.totalSpan.inMicroseconds / 1000.0]..sort();
  double pct(double p) => total.isEmpty ? 0 : total[(total.length * p).floor().clamp(0, total.length - 1)];
  Map<String, Object> toJson() => {
        'frames': frames.length,
        'avgMs': total.isEmpty ? 0 : double.parse((total.fold<double>(0, (a, b) => a + b) / total.length).toStringAsFixed(2)),
        'p50Ms': double.parse(pct(0.5).toStringAsFixed(2)),
        'p95Ms': double.parse(pct(0.95).toStringAsFixed(2)),
        'p99Ms': double.parse(pct(0.99).toStringAsFixed(2)),
        'worstMs': double.parse((total.isEmpty ? 0 : total.last).toStringAsFixed(2)),
        'over16ms': total.where((t) => t > 16.7).length,
        'over33ms': total.where((t) => t > 33.4).length,
        'worstBuildMs': double.parse((frames.isEmpty ? 0 : frames.map((f) => f.buildDuration.inMicroseconds / 1000.0).reduce(math.max)).toStringAsFixed(2)),
        'worstRasterMs': double.parse((frames.isEmpty ? 0 : frames.map((f) => f.rasterDuration.inMicroseconds / 1000.0).reduce(math.max)).toStringAsFixed(2)),
      };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  container.read(settingsProvider.notifier).set((s) => s.copyWith(motion: MotionLevel.full, followSystemMotion: false));
  final router = buildRouter(initialLocation: '/bill');
  runApp(UncontrolledProviderScope(container: container, child: ErpApp(router: router)));
  await Future<void>.delayed(const Duration(seconds: 2));

  final all = <FrameTiming>[];
  SchedulerBinding.instance.addTimingsCallback(all.addAll);

  Future<void> frames(int n) async {
    for (var i = 0; i < n; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  EditableTextState? findEditable() {
    EditableTextState? found;
    void visit(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is EditableTextState) {
        found = e.state as EditableTextState;
        return;
      }
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return found;
  }

  Future<Map<String, Object>> flow(String name) async {
    all.clear();
    final cart = container.read(cartProvider(DocMode.invoice).notifier);
    final products = container.read(productsProvider);
    router.go('/bill');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    cart.clear();
    // 1. add 100 lines quickly (faster than a person)
    for (var i = 0; i < 100; i++) {
      cart.add(products[i * 3]);
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    // 2. type a search, character by character, then clear it
    final ed = findEditable();
    if (ed != null) {
      const q = 'tower bolt 1 1/2';
      for (var i = 1; i <= q.length; i++) {
        ed.userUpdateTextEditingValue(TextEditingValue(text: q.substring(0, i), selection: TextSelection.collapsed(offset: i)), SelectionChangedCause.keyboard);
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      ed.userUpdateTextEditingValue(const TextEditingValue(), SelectionChangedCause.keyboard);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    // 3. flip through pages
    for (final r in ['/sales', '/products', '/customers', '/reports', '/estimates', '/inventory', '/settings', '/', '/credit', '/bill']) {
      router.go(r);
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
    await frames(5);
    await Future<void>.delayed(const Duration(seconds: 1)); // timings arrive a little later
    final s = Stats(List.of(all));
    stdout.writeln('PERF $name ${jsonEncode(s.toJson())}');
    return s.toJson();
  }

  final result = <String, Object>{
    'machine': {'cpus': Platform.numberOfProcessors, 'os': Platform.operatingSystem},
    'mode': 'profile',
    'motion': 'full',
  };
  result['normal'] = await flow('normal');

  final burners = <Isolate>[];
  final busy = math.max(1, Platform.numberOfProcessors - 2);
  for (var i = 0; i < busy; i++) {
    final rp = ReceivePort();
    burners.add(await Isolate.spawn(burn, rp.sendPort));
  }
  await Future<void>.delayed(const Duration(seconds: 1));
  result['contendedBusyIsolates'] = busy;
  result['contended'] = await flow('contended');
  for (final b in burners) {
    b.kill(priority: Isolate.immediate);
  }

  final text = const JsonEncoder.withIndent('  ').convert(result);
  stdout.writeln('PERF_RESULT $text');
  if (outPath.isNotEmpty) File(outPath).writeAsStringSync(text);
  exit(0);
}
