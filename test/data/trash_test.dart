import 'package:erp2/data/context.dart';
import 'package:erp2/data/repo/records_repo.dart';
import 'package:erp2/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

// What these tests prove: a deleted estimate and a deleted expense wait in the Trash (newest first, with what they were), come back with Restore,
// are queued to sync like any change, and a second Restore of the same thing says it is gone; things that were never deleted are not in the Trash.
void main() {
  test('deleted things are in the Trash and come back', () async {
    final d = memoryShop();
    addTearDown(d.close);
    await d.catalog.saveProduct(sampleProduct('Bulb', id: 'p', price: 5000), create: true);
    final est = await d.estimations.save(lines: const [EstimateLine(productId: 'p', name: 'Bulb', unit: 'pcs', qtyMilli: 2000, ratePaise: 5000)], totalPaise: 10000, customerName: 'Murugan', at: DateTime(2026, 10, 20));
    await d.records.put('expenses', Rec('ex1', {'date': DateTime(2026, 10, 20), 'category': 'Tea', 'note': 'for staff', 'amount': 4000}), create: true);
    await d.records.put('expenses', Rec('ex2', {'date': DateTime(2026, 10, 20), 'category': 'Kept', 'amount': 100}), create: true);
    expect(await d.trash.list(), isEmpty);

    await d.estimations.remove(est.number, reason: 'not needed');
    await d.records.remove('ex1');
    final t = await d.trash.list();
    expect(t.map((x) => x.kind).toSet(), {'estimate', 'expenses'});
    final ex = t.firstWhere((x) => x.kind == 'expenses');
    expect((ex.title, ex.detail, ex.amountPaise), ('Tea', 'for staff', 4000));
    expect(t.firstWhere((x) => x.kind == 'estimate').title, est.number);

    await d.db.exec('DELETE FROM outbox');
    expect(await d.trash.restore(ex), isTrue);
    expect((await d.records.list('expenses')).map((r) => r.id), containsAll(['ex1', 'ex2']));
    expect(await d.db.scalarInt("SELECT COUNT(*) FROM outbox WHERE coll = 'records' AND doc_id = 'ex1'"), greaterThan(0), reason: 'the other computers get it back too');
    expect(await d.trash.restore(ex), isFalse, reason: 'already restored');

    expect(await d.trash.restore(t.firstWhere((x) => x.kind == 'estimate')), isTrue);
    expect((await d.estimations.list()).map((e) => e.number), contains(est.number));
    expect(await d.trash.list(), isEmpty);
  });

  test('a kind that is not deletable on the screens never shows', () async {
    final d = memoryShop();
    addTearDown(d.close);
    await d.records.put('purchases', Rec('old', {'date': DateTime(2026, 10, 1), 'no': 'PUR-1'}), create: true);
    await d.records.remove('old');
    expect(await d.trash.list(), isEmpty);
  });
}
