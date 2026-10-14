// Turns the rules template and the private list of people into the rules that get deployed.
// Everything that goes into the rules is checked first, so a typo or a hostile value cannot break out of the list.
final _plainAddress = RegExp(r'^[a-z0-9][a-z0-9._%+-]{0,63}@[a-z0-9][a-z0-9.-]{0,251}\.[a-z]{2,24}$');

List<String> _people(Object? v, String role) {
  final out = <String>[];
  for (final e in (v as List? ?? const [])) {
    final a = e.toString().trim().toLowerCase();
    if (!_plainAddress.hasMatch(a)) throw FormatException('"$role" has an entry that is not a plain e-mail address: "$a"');
    out.add(a);
  }
  return out;
}

String _list(List<String> l) => l.map((e) => "'$e'").join(', ');

int _cap(Object? caps, String key, int fallback) {
  final v = caps is Map ? caps[key] : null;
  if (v == null) return fallback;
  if (v is! int || v < 1 || v > 100000) throw FormatException('caps.$key must be a whole number from 1 to 100000');
  return v;
}

String buildRules(String template, Map<String, dynamic> j) {
  final owners = _people(j['owners'], 'owners');
  final managers = _people(j['managers'], 'managers');
  final cashiers = _people(j['cashiers'], 'cashiers');
  if (owners.isEmpty) throw const FormatException('At least one owner e-mail is needed.');
  final all = [...owners, ...managers, ...cashiers];
  if (all.toSet().length != all.length) throw const FormatException('A person can have only one role: an e-mail is listed twice.');
  final out = template
      .replaceAll("/*OWNERS*/'__OWNER_EMAIL__'", _list(owners))
      .replaceAll('/*MANAGERS*/', _list(managers))
      .replaceAll('/*CASHIERS*/', _list(cashiers))
      .replaceAll('/*CAP_OWNER*/24', '${_cap(j['caps'], 'owner', 24)}')
      .replaceAll('/*CAP_MANAGER*/24', '${_cap(j['caps'], 'manager', 24)}')
      .replaceAll('/*CAP_CASHIER*/16', '${_cap(j['caps'], 'cashier', 16)}');
  final left = RegExp(r'/\*(OWNERS|MANAGERS|CASHIERS|CAP_[A-Z]+)\*/|__OWNER_EMAIL__').firstMatch(out);
  if (left != null) throw FormatException('The template still has a placeholder: ${left.group(0)}');
  return out;
}
