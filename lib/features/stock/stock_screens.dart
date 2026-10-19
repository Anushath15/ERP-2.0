import 'package:go_router/go_router.dart';
import '../../fake/shop_profile.dart' show shopProvider;
import '../../fake/stats.dart' show statsProvider;
import '../../fake/actions.dart' show returnsVersionProvider;
import '../../data/repo/report_repo.dart' show ProductSales;
import '../../fake/data_providers.dart';
import '../../data/ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../design/data_list.dart';
import '../../design/detail_sheet.dart';
import '../../design/form_sheet.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../fake/models.dart';
import '../../fake/store.dart';
import '../../fake/stock_value_provider.dart';
import '../products/product_form.dart';
import 'stock_value_sheet.dart';

Widget _stockCell(BuildContext context, Product p) {
  final l = tr(context);
  return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
    Text('${formatQty(p.stockMilli)} ${p.unit}', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: p.outOfStock ? context.c.danger : null)),
    if (p.outOfStock) Padding(padding: const EdgeInsets.only(top: 3), child: StatusBadge(l.outOfStock, kind: BadgeKind.danger, icon: Icons.block_rounded)),
    if (p.lowStock) Padding(padding: const EdgeInsets.only(top: 3), child: StatusBadge(l.lowStock, kind: BadgeKind.warning)),
  ]);
}

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key, this.autoAdd = false});
  final bool autoAdd;
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoAdd) WidgetsBinding.instance.addPostFrameCallback((_) => _add());
  }

  Future<void> _add() async {
    final l = tr(context);
    final p = await showProductForm(context, saveLabel: l.save);
    if (p != null) {
      ref.read(productsProvider.notifier).add(p);
      final warn = sellsAboveMrp(p, shopPricesIncludeGst: ref.read(shopProvider).pricesIncludeGst);
      if (mounted) toast(context, warn ? '${l.productAdded(p.name)} ${l.mrpAboveWarn}' : l.productAdded(p.name));
    }
  }

  Future<void> _edit(Product p) async {
    final l = tr(context);
    final n = await showProductForm(context, edit: p, saveLabel: l.save);
    if (n != null) {
      ref.read(productsProvider.notifier).update(n);
      final warn = sellsAboveMrp(n, shopPricesIncludeGst: ref.read(shopProvider).pricesIncludeGst);
      if (mounted) toast(context, warn ? '${l.saved} ${l.mrpAboveWarn}' : l.saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final items = ref.watch(productsProvider);
    final th = Theme.of(context).textTheme;
    return DataListScreen<Product>(
      title: l.navProducts,
      subtitle: l.productsSubtitle(items.length.toString()),
      items: items,
      searchText: (p) => '${p.name} ${p.code} ${p.brand} ${p.barcode} ${p.category}',
      searchHint: l.searchProductHint,
      addLabel: l.addProduct,
      onAdd: _add,
      actions: [OutlinedButton.icon(key: const ValueKey('productsLabels'), onPressed: () => context.go('/labels'), icon: const Icon(Icons.sell_rounded), label: Text(l.navLabels))],
      onTap: (ctx, p) => _edit(p),
      emptyTitle: l.noProductsYet,
      emptyText: l.noProductsHelp,
      filters: [
        FilterSpec(l.filterInStock, (p) => !p.outOfStock),
        FilterSpec(l.filterLow, (p) => p.lowStock),
        FilterSpec(l.filterOut, (p) => p.outOfStock),
      ],
      sorts: [
        (l.sortPriceHigh, (a, b) => b.pricePaise.compareTo(a.pricePaise)),
        (l.sortStockLow, (a, b) => a.stockMilli.compareTo(b.stockMilli)),
      ],
      columns: [
        ColumnSpec(l.colCode, (c, p) => Cell(p.code, muted: true), width: 96),
        ColumnSpec(l.colProduct, (c, p) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.name, style: th.titleSmall), if (p.brand.isNotEmpty) Text(p.brand, style: th.bodySmall)]), flex: 6),
        ColumnSpec(l.colCategory, (c, p) => Cell(p.category, muted: true), flex: 2),
        ColumnSpec(l.colMrp, (c, p) => Cell(p.mrpPaise == 0 ? '-' : formatPaise(p.mrpPaise), muted: true), width: 90, numeric: true),
        ColumnSpec(l.colPrice, (c, p) => Cell(formatPaise(p.pricePaise), bold: true), width: 100, numeric: true),
        ColumnSpec('GST', (c, p) => Cell('${p.gstBp ~/ 100}%', muted: true), width: 60, numeric: true),
        ColumnSpec(l.colStock, _stockCell, width: 130, numeric: true),
      ],
      phoneTitle: (c, p) => Text(p.name, style: th.titleSmall),
      phoneSubtitle: (p) => '${p.code.isEmpty ? '' : '${p.code}  ·  '}${p.brand.isEmpty ? '' : '${p.brand}  ·  '}${p.category}  ·  ₹ ${formatPaise(p.pricePaise)}',
      phoneTrailing: _stockCell,
    );
  }
}

/// What every product has sold and made, all time (read again whenever a bill or a return is saved).
final productSalesProvider = FutureProvider.autoDispose<Map<String, ProductSales>>((ref) {
  ref.watch(statsProvider);
  ref.watch(returnsVersionProvider);
  return ref.read(appDataProvider).reports.productSales();
});

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(productsProvider);
    final th = Theme.of(context).textTheme;
    // per-row value for the "highest value" sort only; the TOTAL comes from the one shared calculation (stockValuationProvider)
    int value(Product p) => p.stockMilli <= 0 ? 0 : p.costPaise * p.stockMilli ~/ 1000;
    final sv = ref.watch(stockValuationProvider).value;
    final sales = ref.watch(productSalesProvider).asData?.value;
    final low = items.where((p) => p.lowStock).length;
    final out = items.where((p) => p.outOfStock).length;
    return DataListScreen<Product>(
      title: l.navInventory,
      subtitle: l.inventorySubtitle,
      items: items,
      searchText: (p) => '${p.name} ${p.barcode}',
      searchHint: l.searchProductHint,
      stats: [
        InkWell(onTap: () => showStockValueSheet(context, ref), child: StatCard(label: l.statStockValue, value: sv == null ? '…' : '₹ ${formatPaise(sv.shownTotal)}', icon: Icons.account_balance_rounded, hint: sv == null ? null : ruleCaption(l, sv))),
        StatCard(label: l.statItems, value: items.length.toString(), icon: Icons.inventory_2_rounded),
        StatCard(label: l.statLow, value: low.toString(), icon: Icons.warning_amber_rounded, tone: context.c.warning),
        StatCard(label: l.statOut, value: out.toString(), icon: Icons.block_rounded, tone: context.c.danger),
      ],
      filters: [FilterSpec(l.filterLow, (p) => p.lowStock), FilterSpec(l.filterOut, (p) => p.outOfStock)],
      sorts: [(l.sortValueHigh, (a, b) => value(b).compareTo(value(a))), (l.sortStockLow, (a, b) => a.stockMilli.compareTo(b.stockMilli))],
      columns: [
        ColumnSpec(l.colProduct, (c, p) => Text(p.name, style: th.titleSmall), flex: 6),
        ColumnSpec(l.colStock, _stockCell, width: 130, numeric: true),
        ColumnSpec(l.colCost, (c, p) => Cell(formatPaise(p.costPaise), muted: true), width: 90, numeric: true),
        ColumnSpec(l.colValue, (c, p) => Cell(formatPaise(value(p)), bold: true), width: 120, numeric: true),
        ColumnSpec(l.colSold, (c, p) => Cell(sales == null ? '…' : '${formatQty(sales[p.id]?.qtyMilli ?? 0)} ${p.unit}', muted: true, key: ValueKey('sold-${p.id}')), width: 110, numeric: true),
        ColumnSpec(l.colSales, (c, p) => Cell(sales == null ? '…' : formatPaise(sales[p.id]?.salesPaise ?? 0), key: ValueKey('sales-${p.id}')), width: 110, numeric: true),
        ColumnSpec(l.colProfit, (c, p) {
          final profit = sales == null ? null : (sales[p.id]?.profitPaise ?? 0);
          return Cell(profit == null ? '…' : formatPaise(profit), bold: true, color: profit != null && profit < 0 ? c.c.danger : (profit != null && profit > 0 ? c.c.success : null), key: ValueKey('profit-${p.id}'));
        }, width: 110, numeric: true),
      ],
      phoneTitle: (c, p) => Text(p.name, style: th.titleSmall),
      phoneSubtitle: (p) => '${l.colValue}: ₹ ${formatPaise(value(p))}',
      phoneTrailing: _stockCell,
    );
  }
}

/// A list the shop keeps by name next to its categories: brands and units. Both are small records; a product carries the plain text.
class _NameList {
  const _NameList({required this.kind, required this.tab});
  final String kind; // records kind
  final int tab;
  bool get brand => kind == 'brands';
}

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});
  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  int _tab = 0; // 0 categories, 1 brands, 2 units

  static const _brands = _NameList(kind: 'brands', tab: 1);
  static const _units = _NameList(kind: 'units', tab: 2);

  String _valueOf(_NameList n, Product p) => n.brand ? p.brand : p.unit;

  /// Rename or delete (only when no product uses it) a brand or a unit.
  Future<void> _namePopup(_NameList n, BuildContext ctx, Rec r) async {
    final l = tr(context);
    final name = r.s('name');
    final used = ref.read(productsProvider).where((p) => _valueOf(n, p).toLowerCase() == name.toLowerCase()).length;
    await showDetail(ctx, title: name, subtitle: l.itemsCount('$used'), body: [Text(n.brand ? l.brandsHelp : l.unitsHelp)], actions: [
      OutlinedButton.icon(
        key: ValueKey('${n.kind}-rename'),
        icon: const Icon(Icons.edit_rounded),
        label: Text(n.brand ? l.brandRename : l.unitRename),
        onPressed: () async {
          Navigator.of(ctx, rootNavigator: true).pop();
          final v = await showFormSheet(context, title: n.brand ? l.brandRename : l.unitRename, saveLabel: l.save, fields: [FieldSpec('name', l.fieldName, initial: name, required: true, autofocus: true)]);
          if (v == null || !mounted) return;
          final to = v['name']!.trim();
          final clash = ref.read(recsProvider(n.kind)).any((x) => x.id != r.id && x.s('name').toLowerCase() == to.toLowerCase());
          if (clash) {
            toast(context, n.brand ? l.brandExists : l.unitExists);
            return;
          }
          ref.read(recsProvider(n.kind).notifier).replace(r.with_({'name': to}));
          final cat = ref.read(appDataProvider).catalog;
          final ids = await ref.read(writeQueueProvider).run(() => n.brand ? cat.renameBrand(name, to) : cat.renameUnit(name, to));
          await ref.read(productsProvider.notifier).reload(ids);
          if (mounted) toast(context, n.brand ? l.brandRenamed('${ids.length}') : l.unitRenamed('${ids.length}'));
        },
      ),
      OutlinedButton.icon(
        key: ValueKey('${n.kind}-delete'),
        style: OutlinedButton.styleFrom(foregroundColor: context.c.danger),
        icon: const Icon(Icons.delete_outline_rounded),
        label: Text(n.brand ? l.brandDelete : l.unitDelete),
        onPressed: () async {
          Navigator.of(ctx, rootNavigator: true).pop();
          if (used > 0) {
            toast(context, n.brand ? l.brandInUse('$used') : l.unitInUse('$used'));
            return;
          }
          final ok = await confirmDialog(context, title: n.brand ? l.brandDelete : l.unitDelete, message: n.brand ? l.brandDeleteConfirm(name) : l.unitDeleteConfirm(name), confirmLabel: l.delete, danger: true);
          if (ok) ref.read(recsProvider(n.kind).notifier).remove(r.id);
        },
      ),
    ]);
  }

  Widget _nameTab(_NameList n, Widget tabs) {
    final l = tr(context);
    final products = ref.watch(productsProvider);
    // the ones made here plus any used on a product (or, for units, the starting ones) that were never listed
    final registry = ref.watch(recsProvider(n.kind));
    final known = {for (final r in registry) r.s('name').toLowerCase()};
    final others = n.brand ? brandNames(const [], products) : unitNames(const [], products);
    final listed = [
      ...registry,
      for (final x in others)
        if (!known.contains(x.toLowerCase())) Rec('used-$x', {'name': x}),
    ]..sort((a, b) => a.s('name').toLowerCase().compareTo(b.s('name').toLowerCase()));
    int count(Rec r) => products.where((p) => _valueOf(n, p).toLowerCase() == r.s('name').toLowerCase()).length;
    return DataListScreen<Rec>(
      key: ValueKey('${n.kind}-list'),
      title: l.navCategories,
      subtitle: n.brand ? l.brandsHelp : l.unitsHelp,
      stats: [Align(alignment: Alignment.centerLeft, child: tabs)],
      items: listed,
      searchText: (r) => r.s('name'),
      addLabel: n.brand ? l.addBrand : l.addUnit,
      onAdd: () async {
        final v = await showFormSheet(context, title: n.brand ? l.addBrand : l.addUnit, saveLabel: l.save, fields: [FieldSpec('name', l.fieldName, required: true, autofocus: true)]);
        if (v == null) return;
        final name = v['name']!.trim();
        if (listed.any((r) => r.s('name').toLowerCase() == name.toLowerCase())) {
          if (mounted) toast(context, n.brand ? l.brandExists : l.unitExists);
          return;
        }
        ref.read(recsProvider(n.kind).notifier).add(Rec(newId(), {'name': name}));
      },
      onTap: (ctx, r) {
        if (!r.id.startsWith('used-')) _namePopup(n, ctx, r);
      },
      columns: [
        ColumnSpec(l.fieldName, (c, r) => Cell(r.s('name'), bold: true), flex: 4),
        ColumnSpec(l.statItems, (c, r) => Cell('${count(r)}'), width: 100, numeric: true),
      ],
      phoneTitle: (c, r) => Cell(r.s('name'), bold: true),
      phoneTrailing: (c, r) => Text('${count(r)}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final tabs = SegmentedButton<int>(
      key: const ValueKey('category-tabs'),
      showSelectedIcon: false,
      segments: [ButtonSegment(value: 0, label: Text(l.tabCategories)), ButtonSegment(value: 1, label: Text(l.tabBrands)), ButtonSegment(value: 2, label: Text(l.tabUnits))],
      selected: {_tab},
      onSelectionChanged: (v) => setState(() => _tab = v.first),
    );
    if (_tab == 1) return _nameTab(_brands, tabs);
    if (_tab == 2) return _nameTab(_units, tabs);
    final items = ref.watch(recsProvider('categories'));
    return DataListScreen<Rec>(
      key: const ValueKey('categories-list'),
      title: l.navCategories,
      stats: [Align(alignment: Alignment.centerLeft, child: tabs)],
      items: items,
      searchText: (r) => r.s('name'),
      addLabel: l.addCategory,
      onAdd: () async {
        final v = await showFormSheet(context, title: l.addCategory, saveLabel: l.save, fields: [FieldSpec('name', l.fieldName, required: true, autofocus: true)]);
        if (v != null) ref.read(recsProvider('categories').notifier).add(Rec(newId(), {'name': v['name']!, 'items': 0}));
      },
      columns: [
        ColumnSpec(l.fieldName, (c, r) => Cell(r.s('name'), bold: true), flex: 4),
        ColumnSpec(l.statItems, (c, r) => Cell('${r.i('items')}'), width: 100, numeric: true),
      ],
      phoneTitle: (c, r) => Cell(r.s('name'), bold: true),
      phoneTrailing: (c, r) => Text('${r.i('items')}'),
    );
  }
}

class AdjustmentsScreen extends ConsumerWidget {
  const AdjustmentsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(recsProvider('adjustments'));
    final products = ref.watch(productsProvider);
    return DataListScreen<Rec>(
      title: l.navAdjustments,
      subtitle: l.adjustmentsSubtitle,
      items: items,
      searchText: (r) => '${r.s('product')} ${r.s('reason')}',
      addLabel: l.addAdjustment,
      onAdd: () async {
        final v = await showFormSheet(context, title: l.addAdjustment, saveLabel: l.save, note: l.adjustmentNote, fields: [
          FieldSpec('product', l.colProduct, type: FieldType.dropdown, initial: products.first.name, options: [for (final p in products.take(60)) (p.name, p.name)]),
          FieldSpec('kind', l.adjustKind, type: FieldType.dropdown, initial: 'minus', options: [('minus', l.adjustMinus), ('plus', l.adjustPlus)]),
          FieldSpec('qty', l.colQty, type: FieldType.number, required: true),
          FieldSpec('reason', l.fieldReason, type: FieldType.multiline, required: true),
        ]);
        if (v == null) return;
        final q = ((double.tryParse(v['qty']!) ?? 0) * 1000).round() * (v['kind'] == 'minus' ? -1 : 1);
        ref.read(recsProvider('adjustments').notifier).add(Rec(newId(), {'date': ref.read(clockProvider), 'product': v['product']!, 'qty': q, 'reason': v['reason']!}));
        if (context.mounted) toast(context, l.saved);
      },
      columns: [
        ColumnSpec(l.colDate, (c, r) => Cell(formatDate(r.f['date'] as DateTime), muted: true), width: 100),
        ColumnSpec(l.colProduct, (c, r) => Cell(r.s('product'), bold: true), flex: 5),
        ColumnSpec(l.colQty, (c, r) => Cell('${r.i('qty') > 0 ? '+' : ''}${formatQty(r.i('qty'))}', bold: true, color: r.i('qty') < 0 ? c.c.danger : c.c.success), width: 80, numeric: true),
        ColumnSpec(l.fieldReason, (c, r) => Cell(r.s('reason'), muted: true), flex: 3),
      ],
      phoneTitle: (c, r) => Cell(r.s('product'), bold: true),
      phoneSubtitle: (r) => '${formatDate(r.f['date'] as DateTime)} · ${r.s('reason')}',
      phoneTrailing: (c, r) => Text('${r.i('qty') > 0 ? '+' : ''}${formatQty(r.i('qty'))}', style: Theme.of(c).textTheme.titleSmall?.copyWith(color: r.i('qty') < 0 ? c.c.danger : c.c.success)),
      onTap: (ctx, r) => showDetail(ctx, title: l.navAdjustments, body: [KeyValue(l.colDate, formatDate(r.f['date'] as DateTime)), KeyValue(l.colProduct, r.s('product'), bold: true), KeyValue(l.colQty, formatQty(r.i('qty'))), KeyValue(l.fieldReason, r.s('reason'))]),
    );
  }
}
