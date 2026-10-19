import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

/// Why an encrypted backup could not be opened.
enum SealProblem { notSealed, wrongPassword, damaged }

class SealException implements Exception {
  const SealException(this.problem);
  final SealProblem problem;
  @override
  String toString() => 'SealException($problem)';
}

/// Encrypted backups (the copy that goes to Telegram). A file is: the 8 bytes `ASKBAK1\n`, the number of password rounds (4 bytes), a random salt
/// (16), a random nonce (12), then the backup (compressed) locked with AES-256-GCM, with a 16-byte seal at the end. The key comes from the
/// password with PBKDF2-HMAC-SHA256, so guessing passwords is slow. GCM both hides the data and proves that not one byte was changed: a wrong
/// password and a damaged file are both refused, never half-opened. The header is part of what is sealed.
const _magic = [0x41, 0x53, 0x4B, 0x42, 0x41, 0x4B, 0x31, 0x0A]; // ASKBAK1\n
const _headerLength = 8 + 4 + 16 + 12;
const defaultRounds = 210000;
const _minRounds = 1000, _maxRounds = 2000000;

Pbkdf2 _kdf(int rounds) => Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: rounds, bits: 256);

Uint8List _randomBytes(int n, Random r) => Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));

/// True when [data] starts like one of our encrypted backups.
bool looksSealed(Uint8List data) {
  if (data.length < _headerLength + 16) return false;
  for (var i = 0; i < _magic.length; i++) {
    if (data[i] != _magic[i]) return false;
  }
  return true;
}

/// Compresses and locks [plain] (a backup file's bytes) with [password]. [rounds] is only lowered by tests.
Future<Uint8List> sealBackup(Uint8List plain, String password, {int rounds = defaultRounds, Random? random}) async {
  final rnd = random ?? Random.secure();
  final salt = _randomBytes(16, rnd), nonce = _randomBytes(12, rnd);
  final header = Uint8List(8 + 4 + 16)
    ..setAll(0, _magic)
    ..buffer.asByteData().setUint32(8, rounds)
    ..setAll(12, salt);
  final key = await _kdf(rounds).deriveKeyFromPassword(password: password, nonce: salt);
  final packed = Uint8List.fromList(const GZipEncoder().encodeBytes(plain));
  final box = await AesGcm.with256bits().encrypt(packed, secretKey: key, nonce: nonce, aad: header);
  return Uint8List.fromList([...header, ...nonce, ...box.cipherText, ...box.mac.bytes]);
}

/// The backup inside a file made by [sealBackup]. Throws [SealException].
Future<Uint8List> openSealedBackup(Uint8List data, String password) async {
  if (!looksSealed(data)) throw const SealException(SealProblem.notSealed);
  final rounds = data.buffer.asByteData(data.offsetInBytes).getUint32(8);
  if (rounds < _minRounds || rounds > _maxRounds) throw const SealException(SealProblem.damaged); // a crafted file must not tie the computer up
  final header = Uint8List.sublistView(data, 0, 8 + 4 + 16);
  final salt = Uint8List.sublistView(data, 12, 28);
  final nonce = Uint8List.sublistView(data, 28, _headerLength);
  final cipher = Uint8List.sublistView(data, _headerLength, data.length - 16);
  final mac = Mac(Uint8List.sublistView(data, data.length - 16));
  final key = await _kdf(rounds).deriveKeyFromPassword(password: password, nonce: salt);
  final List<int> packed;
  try {
    packed = await AesGcm.with256bits().decrypt(SecretBox(cipher, nonce: nonce, mac: mac), secretKey: key, aad: header);
  } on SecretBoxAuthenticationError {
    throw const SealException(SealProblem.wrongPassword);
  }
  try {
    return Uint8List.fromList(const GZipDecoder().decodeBytes(packed));
  } catch (_) {
    throw const SealException(SealProblem.damaged);
  }
}

/// A password the program makes for the owner: 16 letters and digits without the look-alikes (no 0/O, 1/l/I), in four groups.
String makeBackupPassword([Random? random]) {
  const alphabet = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = random ?? Random.secure();
  final groups = [for (var g = 0; g < 4; g++) String.fromCharCodes([for (var i = 0; i < 4; i++) alphabet.codeUnitAt(r.nextInt(alphabet.length))])];
  return groups.join('-');
}

/// Is this password long enough to keep a backup safe from guessing?
bool goodBackupPassword(String p) => p.trim().length >= 10 && p == p.trim();
