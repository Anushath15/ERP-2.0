import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cloud/session_vault.dart';

/// The PIN lock of this computer: the program asks for a PIN when it starts, after some minutes of not being used, and when the person presses
/// Lock. Stored in this computer's own protected file (not in the shop data, never in a backup, never synced).
///  * The PIN is kept only as a salted PBKDF2 hash; a 12-letter recovery code (shown once, to be written on paper) is the way back in when the
///    PIN is forgotten, also kept only as a hash.
///  * Wrong tries are counted across restarts: every 5th wrong try in a row makes the program wait (30 seconds, then longer, up to 15 minutes).
///  * It keeps casual users out of the shop's data. It is not a defence against someone who can sign in to this Windows account.
class PinLockState {
  const PinLockState({this.enabled = false, this.locked = false, this.minutes = 15, this.failed = 0, this.until});
  final bool enabled, locked;

  /// Lock after this many minutes of not being used; 0 = never (only when Lock is pressed).
  final int minutes;
  final int failed;

  /// Wrong tries are refused until this time.
  final DateTime? until;

  PinLockState copyWith({bool? enabled, bool? locked, int? minutes, int? failed, DateTime? until, bool clearUntil = false}) =>
      PinLockState(enabled: enabled ?? this.enabled, locked: locked ?? this.locked, minutes: minutes ?? this.minutes, failed: failed ?? this.failed, until: clearUntil ? null : (until ?? this.until));
}

enum UnlockResult { ok, wrong, waiting }

/// The PIN is 4 to 8 digits.
bool validPin(String pin) => RegExp(r'^[0-9]{4,8}$').hasMatch(pin);

/// A new recovery code: three groups of four, no look-alike characters.
String makeRecoveryCode([Random? random]) {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = random ?? Random.secure();
  return [for (var g = 0; g < 3; g++) String.fromCharCodes([for (var i = 0; i < 4; i++) alphabet.codeUnitAt(r.nextInt(alphabet.length))])].join('-');
}

String _normalise(String code) => code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// How many password rounds the PIN and recovery hashes use (tests make it small).
final pinRoundsProvider = Provider<int>((ref) => 120000);

/// What time it is for the idle check (tests replace it).
final lockClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class PinLockController extends Notifier<PinLockState> {
  String _salt = '', _hash = '', _rSalt = '', _rHash = '';
  int _rounds = 120000;
  late DateTime _last;
  Timer? _timer;

  SessionVault get _vault => ref.read(lockVaultProvider);
  DateTime _now() => ref.read(lockClockProvider)();

  @override
  PinLockState build() {
    ref.onDispose(() => _timer?.cancel());
    _last = _now();
    try {
      final j = jsonDecode(_vault.read() ?? '');
      if (j is Map && '${j['hash'] ?? ''}'.isNotEmpty && '${j['salt'] ?? ''}'.isNotEmpty) {
        _salt = '${j['salt']}';
        _hash = '${j['hash']}';
        _rSalt = '${j['rSalt'] ?? ''}';
        _rHash = '${j['rHash'] ?? ''}';
        _rounds = j['rounds'] is int ? (j['rounds'] as int).clamp(1000, 2000000) : 120000;
        final minutes = j['minutes'] is int ? (j['minutes'] as int).clamp(0, 600) : 15;
        final until = j['until'] is int ? DateTime.fromMillisecondsSinceEpoch(j['until'] as int) : null;
        _timer = Timer.periodic(const Duration(seconds: 15), (_) => checkIdle());
        // every start of the program asks for the PIN
        return PinLockState(enabled: true, locked: true, minutes: minutes, failed: j['failed'] is int ? j['failed'] as int : 0, until: until);
      }
    } catch (_) {}
    return const PinLockState();
  }

  void _save() => _vault.write(state.enabled
      ? jsonEncode({'salt': _salt, 'hash': _hash, 'rSalt': _rSalt, 'rHash': _rHash, 'rounds': _rounds, 'minutes': state.minutes, 'failed': state.failed, 'until': state.until?.millisecondsSinceEpoch})
      : null);

  Future<String> _digest(String secret, String saltB64, int rounds) async {
    final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: rounds, bits: 256).deriveKeyFromPassword(password: secret, nonce: base64.decode(saltB64));
    return base64.encode(await key.extractBytes());
  }

  String _newSalt() => base64.encode(Uint8List.fromList(List.generate(16, (_) => Random.secure().nextInt(256))));

  bool _same(String a, String b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return d == 0;
  }

  /// Called for every touch or key press: the program is in use.
  void touch() => _last = _now();

  /// Locks when the program has not been used for the chosen time. Checked every few seconds.
  void checkIdle() {
    if (!state.enabled || state.locked || state.minutes <= 0) return;
    if (_now().difference(_last) >= Duration(minutes: state.minutes)) lock();
  }

  void lock() {
    if (state.enabled && !state.locked) state = state.copyWith(locked: true);
  }

  /// Only every 5th wrong try in a row starts a wait: 30 seconds, then 60, 120 ... up to 15 minutes.
  int _waitSeconds(int failed) => failed % 5 != 0 ? 0 : min(900, 30 * pow(2, failed ~/ 5 - 1).toInt());

  /// A wrong try: counted, and every 5th in a row starts a wait. Kept so that closing and reopening the program does not reset it.
  void _failed() {
    final n = state.failed + 1;
    final wait = _waitSeconds(n);
    state = state.copyWith(failed: n, until: wait == 0 ? null : _now().add(Duration(seconds: wait)), clearUntil: wait == 0);
    _save();
  }

  bool get _waiting => state.until != null && _now().isBefore(state.until!);

  /// How many seconds are left of the wait after too many wrong tries (0 = none).
  int get waitLeft => _waiting ? state.until!.difference(_now()).inSeconds + 1 : 0;

  void _good() {
    state = state.copyWith(failed: 0, clearUntil: true);
    _save();
  }

  Future<UnlockResult> unlock(String pin) async {
    if (!state.enabled) return UnlockResult.ok;
    if (_waiting) return UnlockResult.waiting;
    if (_same(await _digest(pin, _salt, _rounds), _hash)) {
      _good();
      state = state.copyWith(locked: false);
      touch();
      return UnlockResult.ok;
    }
    _failed();
    return _waiting ? UnlockResult.waiting : UnlockResult.wrong;
  }

  /// Is [pin] the current PIN? (For changing or removing it; wrong tries count like at the lock screen.)
  Future<bool> check(String pin) async {
    if (!state.enabled) return true;
    if (_waiting) return false;
    final ok = _same(await _digest(pin, _salt, _rounds), _hash);
    ok ? _good() : _failed();
    return ok;
  }

  /// Makes (or changes) the PIN. Returns the new recovery code to show once, or null when [pin] is not 4 to 8 digits.
  Future<String?> setPin(String pin, {bool keepLocked = false}) async {
    if (!validPin(pin)) return null;
    final rounds = ref.read(pinRoundsProvider);
    final code = makeRecoveryCode();
    _rounds = rounds;
    _salt = _newSalt();
    _hash = await _digest(pin, _salt, rounds);
    _rSalt = _newSalt();
    _rHash = await _digest(_normalise(code), _rSalt, rounds);
    final wasOn = state.enabled;
    state = PinLockState(enabled: true, locked: keepLocked, minutes: state.minutes, failed: 0);
    _save();
    if (!wasOn) _timer = Timer.periodic(const Duration(seconds: 15), (_) => checkIdle());
    touch();
    return code;
  }

  void turnOff() {
    _timer?.cancel();
    _timer = null;
    _salt = _hash = _rSalt = _rHash = '';
    state = const PinLockState();
    _save();
  }

  void setMinutes(int minutes) {
    state = state.copyWith(minutes: minutes.clamp(0, 600));
    _save();
  }

  /// Forgot the PIN: the recovery code lets the person choose a new PIN (and a new recovery code is made). Null when the code is not right.
  Future<String?> resetWithRecovery(String code, String newPin) async {
    if (!state.enabled || !validPin(newPin)) return null;
    if (_waiting) return null;
    if (!_same(await _digest(_normalise(code), _rSalt, _rounds), _rHash)) {
      _failed();
      return null;
    }
    return setPin(newPin, keepLocked: true); // stays locked until the new recovery code has been written down (see [openAfterReset])
  }

  /// After a reset by recovery code: the new code was shown, so the program opens.
  void openAfterReset() {
    state = state.copyWith(locked: false);
    touch();
  }
}

final pinLockProvider = NotifierProvider<PinLockController, PinLockState>(PinLockController.new);
