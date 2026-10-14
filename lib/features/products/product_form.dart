import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/ids.dart';
import '../../design/form_sheet.dart';
import '../../design/widgets.dart';
import '../../fake/models.dart';
import '../../demo/seed.dart';

/// Add or edit a product. Returns the new product, or null if cancelled. Used by Products and by billing quick-add.
Future<Product?> showProductForm(BuildContext context, {String initialName = '', Product? edit, required String saveLabel}) async {
  final l = tr(context);
  final p = edit;
  final v = await showFormSheet(
    context,
    title: p == null ? l.addProduct : l.editProduct,
    saveLabel: saveLabel,
    fields: [
      FieldSpec('name', l.fieldProductName, initial: p?.name ?? initialName, required: true, autofocus: true, hint: l.productNameHint),
      FieldSpec('price', l.fieldSellPrice, type: FieldType.money, initial: p == null ? '' : (p.pricePaise / 100).toStringAsFixed(2), required: true),
      FieldSpec('cost', l.fieldCostPrice, type: FieldType.money, initial: p == null ? '' : (p.costPaise / 100).toStringAsFixed(2)),
      FieldSpec('unit', l.fieldUnit, type: FieldType.dropdown, initial: p?.unit ?? 'pcs', options: [for (final u in ['pcs', 'kg', 'm', 'box', 'set', 'coil', 'tin', 'ltr']) (u, u)]),
      FieldSpec('gst', l.fieldGst, type: FieldType.dropdown, initial: '${p?.gstBp ?? 1800}', options: const [('0', '0%'), ('500', '5%'), ('1200', '12%'), ('1800', '18%'), ('2800', '28%')]),
      FieldSpec('category', l.fieldCategory, type: FieldType.dropdown, initial: p?.category ?? categories.first, options: [for (final c in categories) (c, c)]),
      FieldSpec('stock', l.fieldStockNow, type: FieldType.number, initial: p == null ? '0' : formatQty(p.stockMilli)),
      FieldSpec('barcode', l.fieldBarcode, initial: p?.barcode ?? ''),
    ],
  );
  if (v == null) return null;
  int paise(String? s) => ((double.tryParse(s ?? '') ?? 0) * 100).round();
  return Product(
    id: p?.id ?? newId(),
    name: v['name']!,
    category: v['category']!,
    unit: v['unit']!,
    pricePaise: paise(v['price']),
    costPaise: paise(v['cost']),
    stockMilli: ((double.tryParse(v['stock'] ?? '') ?? 0) * 1000).round(),
    gstBp: int.tryParse(v['gst'] ?? '') ?? 1800,
    barcode: v['barcode']!,
  );
}
