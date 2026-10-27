/// Best-match-first ordering for typed searches, that forgives how products happen to be spelled.
///
///  * Every typed word must be in the text, in any order. A word counts when it is a whole word ("4" in "4 inch"), the start of a word
///    ("hav" in "havells") or, weaker, inside one (a barcode part).
///  * Spellings of the same thing are one thing: 4 inch = 4" = 4in = 4inches = 4.00INCH; 110mm = 110 mm; 3/4 and 0.75 are single numbers (the
///    4 inside 3/4 is not the number 4).
///  * Order: a whole word beats a word start, words that follow each other as typed beat scattered ones, an earlier hit beats a later one.
///  * When fewer than [looseBelow] products match exactly, close matches follow them: a word with one wrong letter ("tea" for "tee",
///    "finolx"), or ONE typed word that is nowhere in the product (a number or a size is never forgiven). They are always listed after the
///    exact matches.
library;

/// Lower case, with spellings made comparable (see the library note).
String normalizeForSearch(String s) {
  var t = s.toLowerCase();
  t = t.replaceAllMapped(RegExp(r'(\d)\s*(?:"|”|″|\x27\x27|inches\b|inch\b|in\b)'), (m) => '${m.group(1)} inch '); // 4" 4in 4inches -> 4 inch
  t = t.replaceAllMapped(RegExp(r'(\d)\.0+(?!\d)'), (m) => m.group(1)!); // 4.00 -> 4
  t = t.replaceAllMapped(RegExp(r'(\d)[/.](\d)'), (m) => '${m.group(1)}_${m.group(2)}'); // 3/4, 0.75 -> 3_4, 0_75
  t = t.replaceAllMapped(RegExp(r'(\d)([a-z])'), (m) => '${m.group(1)} ${m.group(2)}'); // 110mm -> 110 mm
  t = t.replaceAllMapped(RegExp(r'([a-z])(\d)'), (m) => '${m.group(1)} ${m.group(2)}');
  return t.replaceAll('inches', 'inch').replaceAll(RegExp(r' {2,}'), ' ');
}

String? _qIn;
List<String> _qWords = const [];

/// The typed words, normalized once per typed text (the same query is scored against thousands of products).
List<String> _queryWords(String query) {
  if (query != _qIn) {
    _qWords = _words(normalizeForSearch(query));
    _qIn = query;
  }
  return _qWords;
}

List<String> _words(String normalized) => normalized.split(RegExp(r'[^a-z0-9_\u0080-￿]+')).where((w) => w.isNotEmpty).toList();

bool _isNumber(String w) => RegExp(r'^[0-9_]+$').hasMatch(w);

/// Different by at most one inserted, missing or changed letter (a typing slip).
bool _oneOff(String a, String b) {
  if ((a.length - b.length).abs() > 1) return false;
  var i = 0, j = 0, diff = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      i++;
      j++;
      continue;
    }
    if (++diff > 1) return false;
    if (a.length > b.length) {
      i++;
    } else if (b.length > a.length) {
      j++;
    } else {
      i++;
      j++;
    }
  }
  return diff + (a.length - i) + (b.length - j) <= 1;
}

/// How well [text] matches the typed [query] (higher is better); null when a typed word is not in it at all. [textNormalized]: [text]
/// has already been through [normalizeForSearch] (a program that searches thousands of products does it once).
int? searchScore(String text, String query, {bool textNormalized = false}) {
  final q = _queryWords(query);
  if (q.isEmpty) return 0;
  final norm = textNormalized ? text : normalizeForSearch(text);
  final words = _words(norm);
  var score = 0;
  final at = <int>[];
  for (final t in q) {
    var best = -1, bestAt = -1;
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final s = w == t ? 100 : (w.startsWith(t) ? 60 : 0);
      if (s > best) {
        best = s;
        bestAt = i;
        if (s == 100) break; // the first whole-word hit is the earliest
      }
    }
    if (best <= 0) {
      final i = words.indexWhere((w) => w.contains(t));
      if (i < 0) return null;
      best = 20;
      bestAt = i;
    }
    score += best;
    at.add(bestAt);
  }
  if (q.length > 1) {
    var run = true;
    for (var i = 1; i < at.length; i++) {
      if (at[i] != at[i - 1] + 1) run = false;
    }
    if (run) score += 80 * (q.length - 1);
  }
  final first = at.reduce((a, b) => a < b ? a : b);
  return score * 10 - first.clamp(0, 9);
}

/// The forgiving score: like [searchScore] but a word may be one typing slip away from a word of the text, and with three or more typed
/// words one may be missing (never a number). Null when it is not even close. Always lower than any exact score.
int? looseScore(String text, String query, {bool textNormalized = false}) {
  final q = _queryWords(query);
  if (q.isEmpty) return null;
  final words = _words(textNormalized ? text : normalizeForSearch(text));
  var points = 0, missed = 0;
  for (final t in q) {
    var best = 0;
    for (final w in words) {
      if (w == t) {
        best = 3;
        break;
      }
      if (w.startsWith(t) || (t.length >= 3 && w.contains(t))) {
        if (best < 2) best = 2;
      } else if (t.length >= 4 && !_isNumber(t) && (_oneOff(w, t) || (w.length > t.length && _oneOff(w.substring(0, t.length), t)))) {
        if (best < 1) best = 1;
      }
    }
    if (best == 0) {
      if (_isNumber(t) || q.length < 3) return null; // a number or a size is never forgiven; two words: both needed
      missed++;
    }
    points += best;
  }
  if (missed > 1) return null;
  return points - missed;
}

/// [items] that match every typed word, best match first (equal matches keep their order); when fewer than [looseBelow] match exactly,
/// the close matches follow (at most [looseMax]). [text] gives what is searched for each item.
List<T> rankedSearch<T>(Iterable<T> items, String query, String Function(T) text, {bool textNormalized = false, int looseBelow = 6, int looseMax = 30}) {
  final exact = <(int, int, T)>[];
  final loose = <(int, int, T)>[];
  final all = items is List<T> ? items : items.toList();
  for (var i = 0; i < all.length; i++) {
    final t = text(all[i]);
    final s = searchScore(t, query, textNormalized: textNormalized);
    if (s != null) exact.add((s, i, all[i]));
  }
  if (exact.length < looseBelow) {
    final seen = {for (final e in exact) e.$2};
    for (var i = 0; i < all.length; i++) {
      if (seen.contains(i)) continue;
      final s = looseScore(text(all[i]), query, textNormalized: textNormalized);
      if (s != null) loose.add((s, i, all[i]));
    }
  }
  int by((int, int, T) a, (int, int, T) b) => b.$1 != a.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2);
  exact.sort(by);
  loose.sort(by);
  return [for (final x in exact) x.$3, for (final x in loose.take(looseMax)) x.$3];
}
