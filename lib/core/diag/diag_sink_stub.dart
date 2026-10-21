import 'diag_log.dart';

DiagSink createSink(String folder, int maxBytes) => MemoryDiagSink();

Map<String, Object?> systemFacts() => const {'system': 'browser'};
