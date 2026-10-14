import 'dart:convert';
import 'records_repo.dart';

/// Each computer that makes bills has its own series letter (`A-000123`, `B-000045`), so two computers never make the same bill number.
/// The list of who has which letter belongs to the SHOP (it is part of the shop's data and is shared when the computers sync), so a
/// letter can never be given to a second computer.
class SeriesTakenException implements Exception {
  const SeriesTakenException(this.letter);
  final String letter;
  @override
  String toString() => 'The letter $letter is already used by another computer of this shop.';
}

class SeriesRegistry {
  SeriesRegistry(this.settings, this.deviceId);
  final SettingsRepo settings;
  final String deviceId;

  static const key = 'shop.series';
  static const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];

  static bool valid(String letter) => letters.contains(letter);

  /// Letter -> id of the computer that holds it.
  Future<Map<String, String>> all() async {
    final raw = await settings.get(key);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw);
      return m is Map ? {for (final e in m.entries) if (e.key is String && e.value is String) e.key as String: e.value as String} : {};
    } catch (_) {
      return {};
    }
  }

  /// This computer's letter, or null when it has none yet (then the set-up asks for one).
  Future<String?> mine() async {
    final a = await all();
    for (final e in a.entries) {
      if (e.value == deviceId) return e.key;
    }
    return null;
  }

  /// Letters nobody holds yet.
  Future<List<String>> free() async {
    final taken = (await all()).keys.toSet();
    return [for (final l in letters) if (!taken.contains(l)) l];
  }

  /// Takes [letter] for this computer. Taking the letter it already holds is fine; a letter held by another computer is refused.
  /// A computer holds one letter only: asking for a second one is refused too (its old bills carry the first).
  Future<void> claim(String letter) async {
    if (!valid(letter)) throw ArgumentError('Choose a letter from the list.');
    final a = await all();
    final holder = a[letter];
    if (holder != null && holder != deviceId) throw SeriesTakenException(letter);
    final own = await mine();
    if (own != null && own != letter) throw StateError('This computer already has the letter $own; its bills carry it.');
    a[letter] = deviceId;
    await settings.put(key, jsonEncode(a), upload: true);
  }
}
