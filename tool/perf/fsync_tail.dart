// Raw disk test with no database at all: append 16 KB and flush to disk (what a safe commit must wait for), N times, and print the tail.
// If this shows the same rare 100+ ms stalls, the stalls come from the disk / operating system, not from the program or SQLite.
//   dart run tool/perf/fsync_tail.dart [count=6000] [file=build/fsync_probe.bin]
import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) {
  final n = args.isNotEmpty ? int.parse(args[0]) : 6000;
  final path = args.length > 1 ? args[1] : 'build/fsync_probe.bin';
  final f = File(path)..createSync(recursive: true);
  final h = f.openSync(mode: FileMode.write);
  final buf = Uint8List(16384);
  final lat = <double>[];
  for (var i = 0; i < n; i++) {
    final sw = Stopwatch()..start();
    h.writeFromSync(buf);
    h.flushSync();
    lat.add(sw.elapsedMicroseconds / 1000.0);
  }
  h.closeSync();
  f.deleteSync();
  final s = [...lat]..sort();
  double q(double p) => s[(s.length * p).floor().clamp(0, s.length - 1)];
  stdout.writeln('flush of 16 KB x $n: p50=${q(.5).toStringAsFixed(2)} p95=${q(.95).toStringAsFixed(2)} p99=${q(.99).toStringAsFixed(2)} p99.9=${q(.999).toStringAsFixed(2)} max=${s.last.toStringAsFixed(1)} ms; over 50 ms: ${s.where((x) => x > 50).length}');
}
