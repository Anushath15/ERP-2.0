import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'lan_transport.dart';

LanTransport createTransport() => _IoTransport();

const _maxBody = 16 * 1024 * 1024;

class _IoTransport implements LanTransport {
  HttpServer? _server;

  @override
  Future<void> serve(int port, LanHandler handler) async {
    await stopServing();
    final s = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = s;
    s.listen((req) async {
      try {
        if (req.method != 'POST') {
          req.response.statusCode = 405;
        } else {
          final bytes = BytesBuilder(copy: false);
          await for (final chunk in req) {
            bytes.add(chunk);
            if (bytes.length > _maxBody) throw const LanRefused(413);
          }
          final out = await handler(req.uri.path, bytes.takeBytes(), req.connectionInfo?.remoteAddress.address ?? '');
          req.response.statusCode = 200;
          req.response.add(out);
        }
      } on LanRefused catch (e) {
        req.response.statusCode = e.status;
      } catch (_) {
        req.response.statusCode = 500;
      } finally {
        try {
          await req.response.close();
        } catch (_) {}
      }
    }, onError: (Object _) {});
  }

  @override
  Future<void> stopServing() async {
    final s = _server;
    _server = null;
    await s?.close(force: true);
  }

  @override
  Future<List<String>> localAddresses() async {
    final out = <String>[];
    try {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in i.addresses) {
          if (!a.isLoopback && !a.isLinkLocal) out.add(a.address);
        }
      }
    } catch (_) {}
    return out;
  }

  @override
  Future<({int status, Uint8List body})> post(String host, int port, String path, Uint8List body) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await c.postUrl(Uri(scheme: 'http', host: host, port: port, path: path)).timeout(const Duration(seconds: 4));
      req.add(body);
      final res = await req.close().timeout(const Duration(seconds: 30));
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in res) {
        bytes.add(chunk);
      }
      return (status: res.statusCode, body: bytes.takeBytes());
    } finally {
      c.close(force: true);
    }
  }
}
