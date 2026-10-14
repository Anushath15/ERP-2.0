// Frame-timing run of the billing flow with Full animations, in a REAL build (profile mode), not in a widget test.
//
//   flutter run -t tool/perf/frame_timing_main.dart -d windows --profile --dart-define=PERF_OUT=D:/path/result.json
//
// It drives the app by itself: adds 100 bill lines, types a search, flips through ten pages, twice:
//   1. "normal"    : the computer as it is
//   2. "contended" : the same flow while busy isolates keep half of the CPU threads 100% busy (a throttled, shared machine)
// and writes the average, 95th percentile and worst frame time (build + raster) of each run.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:erp2/app.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/fake/seed.dart';
import 'package:erp2/fake/store.dart';
import 'package:erp2/router.dart';

const outPath = String.fromEnvironment('PERF_OUT');

/// With --dart-define=PERF_PRODUCTS=50000 the catalogue has that many products and only the long-list test runs.
const bigProducts = int.fromEnvironment('PERF_PRODUCTS');

class _BigProducts extends ProductsNotifier {
  @override
  List<Product> build() => seedProducts(count: bigProducts);
}

class Stats {
  Stats(this.frames);
  final List<FrameTiming> frames;
  List<double> get total =>
      [for (final f in frames) f.totalSpan.inMicroseconds / 1000.0]..sort();
  double pct(double p) => total.isEmpty
      ? 0
      : total[(total.length * p).floor().clamp(0, total.length - 1)];
  Map<String, Object> toJson() => {
    'frames': frames.length,
    'avgMs': total.isEmpty
        ? 0
        : double.parse(
            (total.fold<double>(0, (a, b) => a + b) / total.length)
                .toStringAsFixed(2),
          ),
    'p50Ms': double.parse(pct(0.5).toStringAsFixed(2)),
    'p95Ms': double.parse(pct(0.95).toStringAsFixed(2)),
    'p99Ms': double.parse(pct(0.99).toStringAsFixed(2)),
    'worstMs': double.parse(
      (total.isEmpty ? 0 : total.last).toStringAsFixed(2),
    ),
    'over16ms': total.where((t) => t > 16.7).length,
    'over33ms': total.where((t) => t > 33.4).length,
    'worstBuildMs': double.parse(
      (frames.isEmpty
              ? 0
              : frames
                    .map((f) => f.buildDuration.inMicroseconds / 1000.0)
                    .reduce(math.max))
          .toStringAsFixed(2),
    ),
    'worstRasterMs': double.parse(
      (frames.isEmpty
              ? 0
              : frames
                    .map((f) => f.rasterDuration.inMicroseconds / 1000.0)
                    .reduce(math.max))
          .toStringAsFixed(2),
    ),
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [
      if (bigProducts > 0) productsProvider.overrideWith(_BigProducts.new),
    ],
  );
  container
      .read(settingsProvider.notifier)
      .set(
        (s) => s.copyWith(motion: MotionLevel.full, followSystemMotion: false),
      );
  final router = buildRouter(initialLocation: '/bill');
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: ErpApp(router: router),
    ),
  );
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
        ed.userUpdateTextEditingValue(
          TextEditingValue(
            text: q.substring(0, i),
            selection: TextSelection.collapsed(offset: i),
          ),
          SelectionChangedCause.keyboard,
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      ed.userUpdateTextEditingValue(
        const TextEditingValue(),
        SelectionChangedCause.keyboard,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    // 3. flip through pages (timed on its own: the page-switch frames)
    await Future<void>.delayed(
      const Duration(seconds: 1),
    ); // let the earlier timings arrive first
    final before = List.of(all);
    all.clear();
    for (final r in [
      '/sales',
      '/products',
      '/customers',
      '/reports',
      '/estimates',
      '/inventory',
      '/settings',
      '/',
      '/credit',
      '/bill',
    ]) {
      router.go(r);
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
    await frames(5);
    await Future<void>.delayed(
      const Duration(seconds: 1),
    ); // timings arrive a little later
    final pages = Stats(List.of(all));
    final s = Stats([...before, ...all]);
    final out = {...s.toJson(), 'pageSwitch': pages.toJson()};
    stdout.writeln('PERF $name ${jsonEncode(out)}');
    return out;
  }

  // Each page on its own: the worst frame while that page is opened (each route is left alone for 1.2 s so its timings can be told apart).
  Future<Map<String, Object>> perRoute() async {
    final out = <String, Object>{};
    router.go('/');
    await Future<void>.delayed(const Duration(seconds: 2));
    // two rounds: the first visit of each page, then the second visit (what is only paid once per session shows in the difference)
    for (final pass in [1, 2]) {
      for (final r in [
        '/sales',
        '/products',
        '/customers',
        '/reports',
        '/estimates',
        '/inventory',
        '/settings',
        '/',
        '/credit',
        '/bill',
        '/dealers',
        '/purchases',
        '/expenses',
      ]) {
        all.clear();
        router.go(r);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        final st = Stats(List.of(all));
        out[pass == 1 ? r : '$r (2nd visit)'] = {
          'worstMs': st.toJson()['worstMs']!,
          'p95Ms': st.toJson()['p95Ms']!,
          'frames': st.frames.length,
        };
      }
    }
    stdout.writeln('PERF_ROUTES ${jsonEncode(out)}');
    return out;
  }

  if (bigProducts > 0) {
    // New bill with a huge catalogue: scroll the product list (fast, deep), then type a search on it
    router.go('/bill');
    await Future<void>.delayed(const Duration(seconds: 3));
    ScrollPosition? findList() {
      ScrollPosition? best;
      void visit(Element e) {
        if (e is StatefulElement && e.state is ScrollableState) {
          final p = (e.state as ScrollableState).position;
          if (p.axis == Axis.vertical &&
              p.maxScrollExtent > 1000 &&
              (best == null || p.maxScrollExtent > best!.maxScrollExtent)) {
            best = p;
          }
        }
        e.visitChildren(visit);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(visit);
      return best;
    }

    final list = findList();
    final out = <String, Object>{
      'products': bigProducts,
      'listExtentPx': list?.maxScrollExtent ?? 0,
    };
    if (list != null) {
      all.clear();
      for (var i = 0; i < 600; i++) {
        list.jumpTo(
          (list.pixels + 900) % list.maxScrollExtent,
        ); // roughly 15 rows per frame, far faster than a person
        await WidgetsBinding.instance.endOfFrame;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      out['scroll'] = Stats(List.of(all)).toJson();
    }
    final ed = findEditable();
    if (ed != null) {
      all.clear();
      // warm-up typing of something rare (few matches), then the long search that starts with a very common letter
      for (final w
          in const bool.fromEnvironment('PERF_NOWARM')
              ? <String>[]
              : ['z', 'zq', '']) {
        ed.userUpdateTextEditingValue(
          TextEditingValue(
            text: w,
            selection: TextSelection.collapsed(offset: w.length),
          ),
          SelectionChangedCause.keyboard,
        );
        final t = Stopwatch()..start();
        await WidgetsBinding.instance.endOfFrame;
        stdout.writeln(
          'PERF_KEY warm-up "$w" took ${t.elapsedMilliseconds} ms',
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      const q = 'tower bolt 1 1/2';
      for (var i = 1; i <= q.length; i++) {
        final t = Stopwatch()..start();
        ed.userUpdateTextEditingValue(
          TextEditingValue(
            text: q.substring(0, i),
            selection: TextSelection.collapsed(offset: i),
          ),
          SelectionChangedCause.keyboard,
        );
        await WidgetsBinding.instance.endOfFrame;
        stdout.writeln(
          'PERF_KEY "${q.substring(0, i)}" took ${t.elapsedMilliseconds} ms until the next frame ended',
        );
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      out['typeSearch'] = Stats(List.of(all)).toJson();
    }
    final text = const JsonEncoder.withIndent('  ').convert(out);
    stdout.writeln('PERF_BIGLIST $text');
    if (outPath.isNotEmpty) File(outPath).writeAsStringSync(text);
    exit(0);
  }

  final result = <String, Object>{
    'machine': {
      'cpus': Platform.numberOfProcessors,
      'os': Platform.operatingSystem,
    },
    'mode': 'profile',
    'motion': 'full',
  };
  result['perRoute'] = await perRoute();
  result['normal'] = await flow('normal');

  // Contention: separate OS processes (not isolates, which share the VM and can freeze it) that each keep one CPU thread 100% busy.
  final busy = math.max(
    1,
    Platform.numberOfProcessors ~/ 2,
  ); // half of all CPU threads
  final burners = <Process>[];
  for (var i = 0; i < busy; i++) {
    burners.add(
      await Process.start('powershell', [
        '-NoProfile',
        '-Command',
        'while (1) { }',
      ]),
    );
  }
  await Future<void>.delayed(const Duration(seconds: 2));
  result['contendedBusyProcesses'] = busy;
  result['contended'] = await flow('contended');
  for (final p in burners) {
    p.kill();
  }

  final text = const JsonEncoder.withIndent('  ').convert(result);
  stdout.writeln('PERF_RESULT $text');
  if (outPath.isNotEmpty) File(outPath).writeAsStringSync(text);
  exit(0);
}
