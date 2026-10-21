import 'dart:collection';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'diag_sink_stub.dart' if (dart.library.io) 'diag_sink_io.dart' as impl;

/// Where diagnostic lines are kept: a small rotating file on the computer (nothing is ever sent anywhere), or memory in tests and in the browser.
abstract class DiagSink {
  void write(String line);

  /// The newest [max] lines, oldest first.
  List<String> recent(int max);
}

class MemoryDiagSink implements DiagSink {
  final _lines = ListQueue<String>();
  @override
  void write(String line) {
    _lines.add(line);
    while (_lines.length > 2000) {
      _lines.removeFirst();
    }
  }

  @override
  List<String> recent(int max) => _lines.length <= max ? _lines.toList() : _lines.toList().sublist(_lines.length - max);
}

DiagSink createDiagSink(String folder, {int maxBytes = 400 * 1024}) => impl.createSink(folder, maxBytes);

/// What this computer is: the system and its version, the number of processors, the language.
Map<String, Object?> systemFacts() => impl.systemFacts();

/// The program's own diary: WHAT happened, how long it took and how it ended (print finished, sync round, backup, database opened, an error type),
/// never WHO or HOW MUCH. Customer names, phone numbers, e-mails, amounts and bill contents are never passed in, and anything that still looks
/// personal (an @ sign, a long number) is replaced before it is written. It is what makes a fault on the shop PC readable in one file.
class DiagLog {
  DiagLog(this.sink, {DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DiagSink sink;
  final DateTime Function() _now;

  /// A value as it may be written: numbers, booleans and short plain words; text with an @ or a run of 7 or more digits is hidden.
  static String clean(Object? v) {
    if (v == null) return '';
    if (v is num || v is bool) return '$v';
    var s = '$v'.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (s.contains('@') || RegExp(r'\d{7,}').hasMatch(s)) return '[hidden]';
    if (s.length > 60) s = '${s.substring(0, 60)}...';
    return s;
  }

  void event(String area, String what, [Map<String, Object?> data = const {}]) {
    try {
      final parts = <String>[_now().toIso8601String(), area, what];
      for (final e in data.entries) {
        parts.add('${e.key}=${clean(e.value)}');
      }
      sink.write(parts.join(' | '));
    } catch (_) {
      // a diary must never break the work
    }
  }

  /// An error: only its kind and a short cleaned first line (a message can carry what a person typed).
  void error(String area, Object error) => event(area, 'error', {'type': error.runtimeType.toString(), 'text': '$error'.split('\n').first});

  List<String> recent([int max = 300]) => sink.recent(max);
}

final diagSinkProvider = Provider<DiagSink>((ref) => MemoryDiagSink());
final diagProvider = Provider<DiagLog>((ref) => DiagLog(ref.watch(diagSinkProvider)));

/// Everything the "Save diagnostics file" button writes: facts about this computer and program and the last lines of the diary. Counts only (no names,
/// no amounts, no bill content), so the file can be sent to whoever helps without leaking the shop's customers.
String buildDiagnosticsText({required DateTime now, required Map<String, Object?> facts, required List<String> log}) {
  final b = StringBuffer('ASK ERP 2.0 - diagnostics\n');
  b.writeln('Made: ${now.toIso8601String()}');
  b.writeln('This file holds counts and settings only: no customer names, phone numbers, amounts or bill contents.');
  b.writeln();
  for (final e in facts.entries) {
    b.writeln('${e.key}: ${DiagLog.clean(e.value)}');
  }
  b.writeln();
  b.writeln('Last ${log.length} diary lines (newest at the bottom):');
  for (final l in log) {
    b.writeln(l);
  }
  return b.toString();
}

List<int> diagnosticsBytes(String text) => utf8.encode(text);
