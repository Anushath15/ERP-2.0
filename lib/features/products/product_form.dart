import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../data/ids.dart';
import '../../design/form_sheet.dart';
import '../../design/widgets.dart';
import '../../domain/gst_price.dart';
import '../../fake/data_providers.dart';
import '../../fake/models.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart';

/// Add or edit a product. Returns the new product, or null if cancelled. Used by Products and by billing quick-add.
///
/// Must be filled in: name, selling price, buying price, current stock and minimum stock. Each price has its own "Includes GST /
/// Excludes GST" buttons: what is typed is turned into the figure the program keeps (selling price the way the shop prices things,
/// buying price without GST; see lib/domain/gst_price.dart). The product code is made by the program from the category when the
/// product is first saved; brand and HSN code are optional.
Future<Product?> showProductForm(BuildContext context, {String initialName = '', Product? edit, required String saveLabel, bool forPurchase = false}) async {
  final l = tr(context);
  final p = edit;
  final box = ProviderScope.containerOf(context);
  final shopInclusive = box.read(shopProvider).pricesIncludeGst;
  // the shop's own categories (made on the Categories page); the product's current one is always in the list
  final shopCategories = [for (final r in box.read(recsProvider('categories'))) r.s('name')];
  final categoryList = shopCategories.isEmpty ? [if (p != null) p.category else 'General'] : shopCategories;
  if (p != null && !categoryList.contains(p.category)) categoryList.insert(0, p.category);
  final brandList = brandNames(box.read(recsProvider('brands')), box.read(productsProvider));
  final unitList = unitNames(box.read(recsProvider('units')), box.read(productsProvider), keep: p?.unit);
  final modes = [('incl', l.gstIncl), ('excl', l.gstExcl)];
  String two(int paise) => (paise / 100).toStringAsFixed(2);
  final v = await showFormSheet(
    context,
    title: p == null ? l.addProduct : l.editProduct,
    saveLabel: saveLabel,
    note: p == null ? l.productCodeNew : (p.code.isEmpty ? null : l.productCodeIs(p.code)),
    fields: [
      FieldSpec('name', l.fieldProductName, initial: p?.name ?? initialName, required: true, autofocus: true, hint: l.productNameHint),
      FieldSpec('brand', l.fieldBrand, type: FieldType.combo, initial: p?.brand ?? '', hint: l.brandPickHint, options: [for (final b in brandList) (b, b)]),
      FieldSpec('category', l.fieldCategory, type: FieldType.dropdown, initial: p?.category ?? categoryList.first, options: [for (final c in categoryList) (c, c)]),
      FieldSpec('unit', l.fieldUnit, type: FieldType.dropdown, initial: p?.unit ?? unitList.first, options: [for (final u in unitList) (u, u)]),
      FieldSpec('gst', l.fieldGst, type: FieldType.dropdown, initial: '${p?.gstBp ?? 1800}', options: const [('0', '0%'), ('500', '5%'), ('1200', '12%'), ('1800', '18%'), ('2800', '28%')]),
      // the order of work: the printed price (MRP), what it costs (buying price), what it is sold for (selling price); each price can also be set as a percent of the MRP
      FieldSpec('mrp', l.fieldMrp, type: FieldType.money, initial: p == null || p.mrpPaise == 0 ? '' : two(p.mrpPaise)),
      FieldSpec('cost', l.fieldCostPrice, type: FieldType.money, initial: p == null ? '' : two(p.costPaise), required: true),
      FieldSpec('costPct', l.fieldCostPct, type: FieldType.money, percentOf: 'mrp', fills: 'cost'),
      FieldSpec('costMode', '', type: FieldType.choice, initial: 'excl', options: modes),
      FieldSpec('price', l.fieldSellPrice, type: FieldType.money, initial: p == null ? '' : two(p.pricePaise), required: true),
      FieldSpec('pricePct', l.fieldSellPct, type: FieldType.money, percentOf: 'mrp', fills: 'price'),
      FieldSpec('priceMode', '', type: FieldType.choice, initial: shopInclusive ? 'incl' : 'excl', options: modes),
      if (!forPurchase) FieldSpec('stock', l.fieldStockNow, type: FieldType.number, initial: p == null ? '' : formatQty(p.stockMilli), required: true), // a purchase brings the stock
      FieldSpec('minStock', l.fieldMinStock, type: FieldType.number, initial: p == null ? '' : formatQty(p.minStockMilli), required: true),
      FieldSpec('hsn', l.fieldHsn, initial: p?.hsn ?? '', check: (s) => RegExp(r'^\d{4,8}$').hasMatch(s) ? null : l.errHsn),
      FieldSpec('barcode', l.fieldBarcode, initial: p?.barcode ?? '', hint: l.barcodeHelp, suffix: (ctl) => IconButton(
        key: const ValueKey('makeBarcode'),
        tooltip: l.makeBarcode,
        icon: const Icon(Icons.qr_code_2_rounded),
        onPressed: () async => ctl.text = await box.read(appDataProvider).catalog.newBarcode(),
      )),
    ],
  );
  if (v == null) return null;
  // a brand typed for the first time joins the list, so it can be picked next time
  final brand = v['brand']!.trim();
  if (brand.isNotEmpty && !brandList.any((b) => b.toLowerCase() == brand.toLowerCase())) {
    box.read(recsProvider('brands').notifier).add(Rec(newId(), {'name': brand}));
  }
  int paise(String? s) => ((double.tryParse(s ?? '') ?? 0) * 100).round();
  final gst = int.tryParse(v['gst'] ?? '') ?? 1800;
  final mrp = paise(v['mrp']);
  return Product(
    mrpPaise: mrp,
    id: p?.id ?? newId(),
    name: v['name']!,
    category: v['category']!,
    unit: v['unit']!,
    pricePaise: sellingPriceToStore(enteredPaise: paise(v['price']), enteredIncludesGst: v['priceMode'] == 'incl', shopPricesIncludeGst: shopInclusive, gstBp: gst),
    costPaise: buyingPriceToStore(enteredPaise: paise(v['cost']), enteredIncludesGst: v['costMode'] == 'incl', gstBp: gst),
    stockMilli: ((double.tryParse(v['stock'] ?? '') ?? 0) * 1000).round(),
    minStockMilli: ((double.tryParse(v['minStock'] ?? '') ?? 0) * 1000).round(),
    gstBp: gst,
    barcode: v['barcode']!,
    hsn: v['hsn']!.trim(),
    brand: brand,
    code: p?.code ?? '',
  );
}

/// The brands to pick from: the ones made on the Categories page plus any already used on a product, each once (capital letters do
/// not make a different brand), in alphabetical order.
List<String> brandNames(List<Rec> registry, List<Product> products) {
  final seen = <String, String>{};
  for (final n in [for (final r in registry) r.s('name'), for (final p in products) p.brand]) {
    final t = n.trim();
    if (t.isNotEmpty) seen.putIfAbsent(t.toLowerCase(), () => t);
  }
  return seen.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// The units a shop starts with.
const defaultUnits = ['pcs', 'kg', 'm', 'box', 'set', 'coil', 'tin', 'ltr'];

/// The units to pick from: the starting ones, the ones made on the Categories page and any already used on a product (and [keep],
/// the unit of the product being edited), each once, the starting ones first.
List<String> unitNames(List<Rec> registry, List<Product> products, {String? keep}) {
  final seen = <String, String>{};
  for (final n in [...defaultUnits, for (final r in registry) r.s('name'), for (final p in products) p.unit, ?keep]) {
    final t = n.trim();
    if (t.isNotEmpty) seen.putIfAbsent(t.toLowerCase(), () => t);
  }
  return seen.values.toList();
}

/// The MRP is the printed price with GST: a selling price above it is probably a slip of the finger (the product is still saved,
/// the person is only warned).
bool sellsAboveMrp(Product p, {required bool shopPricesIncludeGst}) {
  if (p.mrpPaise <= 0) return false;
  final withGst = shopPricesIncludeGst ? p.pricePaise : p.pricePaise + ((p.pricePaise * p.gstBp + 5000) ~/ 10000);
  return withGst > p.mrpPaise;
}
