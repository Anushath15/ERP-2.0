import 'package:drift/drift.dart' show DatabaseConnectionUser;
import '../../domain/product_code.dart';
import '../context.dart';
import '../db/app_database.dart';

/// The next free product code for [category] (ELE-0001, ELE-0002 ...). Call inside the transaction that saves the product, so the
/// number is never skipped or repeated. A code that is already taken (typed by hand in an older version, or imported) is passed over.
Future<String> nextProductCode(DatabaseConnectionUser tx, String category) async {
  final prefix = productCodePrefix(category);
  for (var i = 0; i < 100000; i++) {
    final code = formatProductCode(prefix, await nextCounter(tx, 'code.$prefix'));
    if (await tx.scalarInt('SELECT COUNT(*) FROM products WHERE code = ?', [code]) == 0) return code;
  }
  throw StateError('No free product code for $category.');
}

/// Gives every product that has no code its code, oldest first (used by the upgrade to version 4 and after an import).
/// Returns how many were given one.
Future<int> backfillProductCodes(AppDatabase db) async {
  final rows = await db.rows("SELECT id, category FROM products WHERE code = '' ORDER BY created_at, id");
  for (final r in rows) {
    final code = await nextProductCode(db, r.read<String>('category'));
    await db.exec('UPDATE products SET code = ? WHERE id = ?', [code, r.read<String>('id')]);
  }
  return rows.length;
}
