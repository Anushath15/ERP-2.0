import 'package:erp2/core/search_rank.dart';
import 'package:flutter_test/flutter_test.dart';

// What these tests prove: a search lists the best match first. "4 inch finolex" puts the real 4 inch Finolex pipes above products that only
// contain a 4 inside 3/4 or 1 1/4 or 0.75; "4.00INCH" counts as 4 inch; nothing that matched before is lost (every typed word must still be
// there); equal matches keep their order.
void main() {
  const names = [
    '2 1/2" inch SWR PVC Door Tee Finolex',
    '0.75 Inch 3/4" 22.20mm SDR 13.5 CPVC Hot Water Pipe FINOLEX',
    '3.00 inch 90mm 4kgf PVC Pipe FINOLEX',
    '1.25 inch (1 1/4") 40mm 10 Kgf PVC TEE FINOLEX',
    '4 inch 110mm 4kgf PVC Pipe Finolex',
    '4.00INCH 110MM 4KGF/CM2 PVC PASTING PIPE Finolex',
    '4" 110MM PVC Bend 90 Finolex',
    '5 inch 140mm PVC End Cap Finolex',
    '4 inch Binolex pipe',
  ];

  test('4 inch finolex: the real 4 inch Finolex products come first', () {
    final r = rankedSearch(names, '4 inch finolex', (s) => s);
    expect(r.take(2).toSet(), {names[4], names[5]}, reason: 'the 4 inch ones first');
    expect(r.indexOf(names[1]), greaterThan(r.indexOf(names[3])), reason: '3/4 inch only has a 4 inside a fraction: last');
    expect(r.indexOf(names[3]), greaterThan(r.indexOf(names[4])), reason: '1 1/4 is not 4');
    expect(r, isNot(contains(names[8])), reason: 'no Finolex word: still not a match');
    expect(r, isNot(contains(names[0])), reason: 'no 4 at all');
    expect(r, contains(names[6]), reason: '4" is 4 inch');
    expect(r.length, 7, reason: 'every other product with all three words is still there');
  });

  test('numbers are whole numbers, fractions and decimals are single words', () {
    expect(normalizeForSearch('4.00INCH 110MM'), '4 inch 110 mm');
    expect(normalizeForSearch('3/4 0.75'), '3_4 0_75');
    expect(searchScore('3/4 inch pipe', '4')!, lessThan(searchScore('4 inch pipe', '4')!));
    expect(searchScore('0.75 inch pipe', '4'), isNull, reason: 'there is no 4 in 0.75');
    expect(searchScore('3/4 inch pipe', '4'), isNotNull, reason: 'a 4 inside a fraction is still found, just later');
  });

  test('a barcode or code typed in part is still found; a missing word is not', () {
    expect(searchScore('Surya bulb SE000665', 'se0006'), isNotNull);
    expect(searchScore('Surya bulb', 'tube'), isNull);
    expect(rankedSearch(const ['a', 'b'], 'x', (s) => s), isEmpty);
  });

  test('equal matches keep their order; a word typed in full beats the start of a longer word', () {
    expect(rankedSearch(const ['pipe one', 'pipe two'], 'pipe', (s) => s), ['pipe one', 'pipe two']);
    expect(rankedSearch(const ['pipette', 'pipe'], 'pipe', (s) => s), ['pipe', 'pipette']);
  });

  test('spellings of inch are one thing: 4 inch finds 4", 4in, 4.00INCH and 4 Inch', () {
    for (final name in ['4" 110MM PVC TEE Finolex', '4in 110mm pvc tee', '4.00INCH 110MM PVC TEE', '4 Inch PVC Tee 110mm', '4inches pvc tee']) {
      expect(searchScore(name, '4 inch tee'), isNotNull, reason: name);
    }
    expect(searchScore('3 inch PVC TEE', '4 inch tee'), isNull, reason: 'a different size is never a match');
    expect(searchScore('0.75 inch PVC TEE', '4 inch tee'), isNull);
  });

  test('type, change the text, type again: the product is found each time (the reported problem)', () {
    const tees = ['4" 110MM PVC TEE Finolex', '4 inch 110mm Pvc Tee FINOLEX', '3 inch 90mm Pvc Tee FINOLEX', '4 inch Pvc Pipe Finolex'];
    List<String> find(String q) => rankedSearch(tees, q, (s) => s);
    expect(find('4 inch tee').take(2).toSet(), {tees[0], tees[1]});
    expect(find('inch tee'), containsAll([tees[0], tees[1], tees[2]]), reason: 'the 4 taken away');
    expect(find('4 inch tee').take(2).toSet(), {tees[0], tees[1]}, reason: 'typed again');
    expect(find('4 inch tee finolex').take(2).toSet(), {tees[0], tees[1]});
  });

  test('a slip or an unknown word is forgiven (after the exact matches); a wrong number is not', () {
    const names = ['4 inch 110mm Pvc Tee FINOLEX', '3 inch 90mm Pvc Tee FINOLEX'];
    expect(rankedSearch(names, '4 inch tea', (s) => s), [names[0]], reason: 'tea -> tee: only the 4 inch');
    expect(rankedSearch(names, '4 inch finolx tee', (s) => s), [names[0]], reason: 'finolx -> finolex');
    expect(rankedSearch(names, '4 inch tee heavy', (s) => s), [names[0]], reason: 'one unknown word of four is forgiven');
    expect(rankedSearch(names, '4 heavy', (s) => s), isEmpty, reason: 'two words: both are needed');
    expect(rankedSearch(names, '5 inch tee', (s) => s), isEmpty, reason: 'a number is never forgiven');
    expect(rankedSearch(const ['pipe a', 'pipe b', 'pipe c', 'pipe d', 'pipe e', 'pipe f', 'pipx'], 'pipe', (s) => s).contains('pipx'), isFalse, reason: 'enough exact matches: no loose ones');
  });
}
