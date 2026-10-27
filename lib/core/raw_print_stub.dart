import 'dart:typed_data';

/// No direct printer access in a browser: the caller prints the normal way.
Future<bool> rawToWindowsPrinter(String printerName, Uint8List bytes, {required String jobName}) async => false;

Future<bool> rawToNetwork(String host, int port, Uint8List bytes) async => false;
