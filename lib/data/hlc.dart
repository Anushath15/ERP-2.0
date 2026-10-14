/// Hybrid logical clock (docs/sync-design.md): a stamp that is always later than anything this device has seen, even if the
/// device clock is wrong. Stamps compare as plain text: `millis(15 digits)-counter(4 digits)-deviceId`.
class Hlc {
  Hlc(this.deviceId, {int Function()? nowMs}) : _now = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);
  final String deviceId;
  final int Function() _now;
  int _ms = 0;
  int _counter = 0;

  /// The stamp for a change made now on this device.
  String next() {
    final t = _now();
    if (t > _ms) {
      _ms = t;
      _counter = 0;
    } else {
      _counter++;
    }
    return _format(_ms, _counter, deviceId);
  }

  /// A stamp seen from another device: the local clock moves forward so the next local stamp is later than it.
  void receive(String stamp) {
    final p = parse(stamp);
    if (p == null) return;
    final (ms, counter, _) = p;
    if (ms > _ms || (ms == _ms && counter > _counter)) {
      _ms = ms;
      _counter = counter;
    }
  }

  static String _format(int ms, int counter, String device) => '${ms.toString().padLeft(15, '0')}-${counter.toString().padLeft(4, '0')}-$device';

  static (int, int, String)? parse(String stamp) {
    final m = RegExp(r'^(\d{15})-(\d{4})-(.+)$').firstMatch(stamp);
    if (m == null) return null;
    return (int.parse(m.group(1)!), int.parse(m.group(2)!), m.group(3)!);
  }

  /// Negative when [a] is older than [b].
  static int compare(String a, String b) => a.compareTo(b);
}
