import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_vault_stub.dart' if (dart.library.io) 'session_vault_io.dart' as impl;

/// Where this computer keeps the sign-in (the refresh token) so the program never asks again after the first time.
/// Windows: encrypted for this Windows user with DPAPI (the same protection Windows gives saved passwords), in this computer's own
/// folder, never in the shop data, never in a backup, never synced. In a browser nothing is kept.
abstract class SessionVault {
  String? read();
  void write(String? value);
}

class MemorySessionVault implements SessionVault {
  MemorySessionVault([this.value]);
  String? value;
  @override
  String? read() => value;
  @override
  void write(String? v) => value = v;
}

final sessionVaultProvider = Provider<SessionVault>((ref) => impl.createVault(MemorySessionVault.new));

/// The same kind of protected file, for the Telegram backup settings (bot token, channel and backup password): `telegram.bin`.
final telegramVaultProvider = Provider<SessionVault>((ref) => impl.createVault(MemorySessionVault.new, file: 'telegram.bin'));

/// The same kind of protected file, for the PIN lock (the PIN's hash, the recovery code's hash, the wrong-try count): `lock.bin`.
final lockVaultProvider = Provider<SessionVault>((ref) => impl.createVault(MemorySessionVault.new, file: 'lock.bin'));
