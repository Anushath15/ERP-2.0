import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// The shop's counter-link key: 32 random bytes shown as 8 groups of 8 hex digits. Everything the counters send each other over the shop
/// Wi-Fi is locked with it (AES-256-GCM), so someone else on the Wi-Fi can neither read nor change it, and a computer without the key is
/// refused. Written down once, typed into the other counter once.
class LanKey {
  LanKey._(this.bytes);
  final Uint8List bytes;

  static LanKey generate([Random? random]) {
    final r = random ?? Random.secure();
    return LanKey._(Uint8List.fromList(List<int>.generate(32, (_) => r.nextInt(256))));
  }

  /// Parses what a person typed (dashes, spaces and capitals allowed). Null when it is not a key.
  static LanKey? parse(String text) {
    final t = text.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(t)) return null;
    return LanKey._(Uint8List.fromList([for (var i = 0; i < 64; i += 2) int.parse(t.substring(i, i + 2), radix: 16)]));
  }

  /// `1a2b3c4d-...` for showing and typing.
  String get text {
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return [for (var i = 0; i < 64; i += 8) h.substring(i, i + 8)].join('-');
  }
}

class LanSealException implements Exception {
  const LanSealException();
  @override
  String toString() => 'LanSealException';
}

final _gcm = AesGcm.with256bits();

/// Locks [message] (JSON) with [key]: 12-byte random nonce, the cipher text, a 16-byte seal. A time stamp inside is checked on opening.
Future<Uint8List> lanSeal(LanKey key, Map<String, Object?> message, {int Function()? nowMs, Random? random}) async {
  final rnd = random ?? Random.secure();
  final nonce = Uint8List.fromList(List<int>.generate(12, (_) => rnd.nextInt(256)));
  final body = {...message, 'ts': (nowMs ?? () => DateTime.now().millisecondsSinceEpoch)()};
  final box = await _gcm.encrypt(utf8.encode(jsonEncode(body)), secretKey: SecretKey(key.bytes), nonce: nonce);
  return Uint8List.fromList([...nonce, ...box.cipherText, ...box.mac.bytes]);
}

/// The nonce of a sealed message as text: unique for every message, so it tells a replay (the same message sent again) from a new one.
String lanNonce(Uint8List sealed) => sealed.length < 12 ? '' : [for (final b in Uint8List.sublistView(sealed, 0, 12)) b.toRadixString(16).padLeft(2, '0')].join();

/// The nonces seen in the last [window]: a message that comes a second time is refused.
class LanReplayGuard {
  LanReplayGuard({this.window = const Duration(minutes: 11), DateTime Function()? now}) : _now = now ?? DateTime.now;
  final Duration window;
  final DateTime Function() _now;
  final _seen = <String, DateTime>{};

  /// True the first time [nonce] is seen, false after.
  bool fresh(String nonce) {
    final now = _now();
    _seen.removeWhere((_, t) => now.difference(t) > window);
    if (nonce.isEmpty || _seen.containsKey(nonce)) return false;
    if (_seen.length > 50000) _seen.clear(); // a flood cannot fill the memory; anything older than the window is refused by its time stamp anyway
    _seen[nonce] = now;
    return true;
  }
}

/// The message inside [data], or a [LanSealException] when it was not locked with [key], was changed, or is older than [maxAgeMs]
/// (a recorded message cannot be played back later).
Future<Map<String, Object?>> lanOpen(LanKey key, Uint8List data, {int maxAgeMs = 10 * 60 * 1000, int Function()? nowMs}) async {
  if (data.length < 12 + 16 + 2) throw const LanSealException();
  try {
    final plain = await _gcm.decrypt(
      SecretBox(Uint8List.sublistView(data, 12, data.length - 16), nonce: Uint8List.sublistView(data, 0, 12), mac: Mac(Uint8List.sublistView(data, data.length - 16))),
      secretKey: SecretKey(key.bytes),
    );
    final j = jsonDecode(utf8.decode(plain));
    if (j is! Map) throw const LanSealException();
    final ts = j['ts'];
    final now = (nowMs ?? () => DateTime.now().millisecondsSinceEpoch)();
    if (ts is! int || (now - ts).abs() > maxAgeMs) throw const LanSealException();
    return j.cast<String, Object?>();
  } on LanSealException {
    rethrow;
  } catch (_) {
    throw const LanSealException();
  }
}
