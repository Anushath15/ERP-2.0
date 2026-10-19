import 'dart:typed_data';
import 'lan_transport.dart';

LanTransport createTransport() => _Unsupported();

class _Unsupported implements LanTransport {
  @override
  Future<List<String>> localAddresses() async => const [];
  @override
  Future<({int status, Uint8List body})> post(String host, int port, String path, Uint8List body) => throw UnsupportedError('The counter link needs the Windows program.');
  @override
  Future<void> serve(int port, LanHandler handler) => throw UnsupportedError('The counter link needs the Windows program.');
  @override
  Future<void> stopServing() async {}
}
