/// GST return helpers. Pure Dart.
library;

/// The unit code the GST return wants (UQC) for a unit the shop typed ("pcs", "mtr", "kg", ...). Anything unknown is OTH (other).
String gstUqc(String unit) {
  final u = unit.trim().toLowerCase().replaceAll('.', '');
  return switch (u) {
    'pcs' || 'pc' || 'piece' || 'pieces' || 'nos' || 'no' || 'number' || 'numbers' || 'unit' || 'units' || 'each' || 'ea' => 'NOS',
    'm' || 'mtr' || 'mtrs' || 'meter' || 'meters' || 'metre' || 'metres' => 'MTR',
    'kg' || 'kgs' || 'kilo' || 'kilogram' || 'kilograms' => 'KGS',
    'g' || 'gm' || 'gms' || 'gram' || 'grams' => 'GMS',
    'l' || 'ltr' || 'ltrs' || 'litre' || 'litres' || 'liter' || 'liters' => 'LTR',
    'box' || 'boxes' => 'BOX',
    'set' || 'sets' => 'SET',
    'roll' || 'rolls' => 'ROL',
    'pair' || 'pairs' || 'prs' => 'PRS',
    'bag' || 'bags' => 'BAG',
    'bundle' || 'bundles' || 'bdl' => 'BDL',
    'packet' || 'packets' || 'pkt' || 'pack' || 'packs' => 'PAC',
    'dozen' || 'doz' => 'DOZ',
    'ft' || 'feet' || 'foot' => 'OTH',
    _ => 'OTH',
  };
}

final _gstin = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

/// Whether [s] has the shape of a GSTIN (15 characters: state code, PAN, entity, Z, check). The check digit is not verified.
bool looksLikeGstin(String s) => _gstin.hasMatch(s.trim().toUpperCase());

/// The two-digit state code a GSTIN starts with ("33" = Tamil Nadu), or '' when it is not a GSTIN.
String gstinState(String s) => looksLikeGstin(s) ? s.trim().substring(0, 2) : '';
