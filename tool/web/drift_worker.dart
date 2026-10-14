// The web worker that runs the database in the browser (shared between tabs, stored in the browser's own storage).
// Build:  dart compile js -O4 -o web/drift_worker.js tool/web/drift_worker.dart
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
