import 'dart:typed_data';
import 'lan_transport_stub.dart' if (dart.library.io) 'lan_transport_io.dart' as impl;

/// A request the server could not accept; [status] goes back to the other counter (401 = wrong key).
class LanRefused implements Exception {
  const LanRefused(this.status);
  final int status;
}

typedef LanHandler = Future<Uint8List> Function(String path, Uint8List body, String remoteIp);

/// The network part of the counter link, kept apart so the rest can be tested without a network and so the web build still compiles.
abstract class LanTransport {
  /// Listens on [port] (all network cards of this computer). Throws when the port is taken or the computer refuses.
  Future<void> serve(int port, LanHandler handler);
  Future<void> stopServing();

  /// The addresses other counters can use to reach this computer (private IPv4 addresses of its network cards).
  Future<List<String>> localAddresses();

  /// One request to another counter. Throws on no connection or no answer within a few seconds.
  Future<({int status, Uint8List body})> post(String host, int port, String path, Uint8List body);
}

LanTransport createLanTransport() => impl.createTransport();

const lanPort = 47321;
