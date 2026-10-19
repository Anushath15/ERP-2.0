import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../fake/data_providers.dart';
import '../cloud/sync_controller.dart';
import '../data_mode.dart';
import 'lan_crypto.dart';
import '../../data/sync/lan_link.dart';
import 'lan_transport.dart';

class LanState {
  const LanState({this.on = false, this.key = '', this.addresses = const [], this.peers = const [], this.status = const {}, this.startFailed = false, this.busy = false});
  final bool on, startFailed, busy;
  final String key;
  final List<String> addresses;
  final List<LanPeer> peers;

  /// chan -> '' (fine) or the problem from the last round.
  final Map<String, String> status;

  LanState copyWith({bool? on, String? key, List<String>? addresses, List<LanPeer>? peers, Map<String, String>? status, bool? startFailed, bool? busy}) => LanState(
      on: on ?? this.on, key: key ?? this.key, addresses: addresses ?? this.addresses, peers: peers ?? this.peers, status: status ?? this.status, startFailed: startFailed ?? this.startFailed, busy: busy ?? this.busy);
}

final lanTransportProvider = Provider<LanTransport>((ref) => createLanTransport());

/// The counter link of the real shop: switched on per computer (setting `lan.on`), with the shop's key (`lan.key`). While on, it answers the
/// other counters and every few seconds sends them what changed here.
class LanController extends Notifier<LanState> {
  Timer? _timer;
  LanLink? _link;
  bool _running = false;

  static const interval = Duration(seconds: 5);

  @override
  LanState build() {
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_link?.stop());
    });
    return const LanState();
  }

  Future<String?> _get(String name) => ref.read(appDataProvider).settings.get(name);
  Future<void> _put(String name, String value) => ref.read(appDataProvider).settings.put(name, value);

  /// At program start (real shop only): starts the link when it was switched on.
  Future<void> init({bool timer = true}) async {
    if (ref.read(appModeProvider) != DataMode.real) return;
    final key = await _get('lan.key') ?? '';
    state = state.copyWith(key: key);
    if (await _get('lan.on') == '1' && LanKey.parse(key) != null) await _start(timer: timer);
  }

  Future<void> _start({bool timer = true}) async {
    await _stop();
    final key = LanKey.parse(state.key);
    if (key == null) return;
    final data = ref.read(appDataProvider);
    final link = LanLink(data, ref.read(lanTransportProvider), key, name: 'Counter ${data.cx.deviceId.length > 4 ? data.cx.deviceId.substring(0, 4) : data.cx.deviceId}', onChanged: () => ref.read(syncProvider.notifier).markNewData());
    try {
      await link.start();
    } catch (_) {
      state = state.copyWith(on: false, startFailed: true);
      return;
    }
    _link = link;
    state = state.copyWith(on: true, startFailed: false, addresses: await ref.read(lanTransportProvider).localAddresses(), peers: await link.peers());
    if (timer) _timer = Timer.periodic(interval, (_) => unawaited(tick()));
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _timer = null;
    await _link?.stop();
    _link = null;
  }

  /// Switch on: makes a key when this computer has none (the first counter), starts listening.
  Future<void> enable() async {
    var key = state.key;
    if (LanKey.parse(key) == null) key = LanKey.generate().text;
    state = state.copyWith(key: key);
    await _put('lan.key', key);
    await _put('lan.on', '1');
    await _start();
  }

  Future<void> disable() async {
    await _put('lan.on', '0');
    await _stop();
    state = state.copyWith(on: false);
  }

  /// A key typed in from the first counter. Only while no counter is linked (changing it later would cut the link). False when it is not a key.
  Future<bool> setKey(String text) async {
    final k = LanKey.parse(text);
    if (k == null || state.peers.isNotEmpty) return false;
    state = state.copyWith(key: k.text);
    await _put('lan.key', k.text);
    if (state.on) await _start();
    return true;
  }

  Future<void> addPeer(String host) async {
    final l = _link;
    if (l == null) return;
    state = state.copyWith(busy: true);
    try {
      await l.addPeer(host);
      state = state.copyWith(peers: await l.peers());
      unawaited(tick());
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> removePeer(String chan) async {
    final l = _link;
    if (l == null) return;
    await l.removePeer(chan);
    state = state.copyWith(peers: await l.peers());
  }

  /// One round to every linked counter now.
  Future<void> tick() async {
    final l = _link;
    if (l == null || _running) return;
    _running = true;
    try {
      await l.syncOnce();
      state = state.copyWith(peers: await l.peers(), status: Map.of(l.status));
    } finally {
      _running = false;
    }
  }
}

final lanProvider = NotifierProvider<LanController, LanState>(LanController.new);
