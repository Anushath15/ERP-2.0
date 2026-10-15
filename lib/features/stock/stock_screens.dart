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
import '../products/product_form.dart';

Widget _stockCell(BuildContext context, Product p) {
  final l = tr(context);
  return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
    Text('${formatQty(p.stockMilli)} ${p.unit}', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: p.outOfStock ? context.c.danger : null)),
    if (p.outOfStock) Padding(padding: const EdgeInsets.only(top: 3), child: StatusBadge(l.outOfStock, kind: BadgeKind.danger, icon: Icons.block)),
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
      if (mounted) toast(context, l.productAdded(p.name));
    }
  }

  Future<void> _edit(Product p) async {
    final l = tr(context);
    final n = await showProductForm(context, edit: p, saveLabel: l.save);
    if (n != null) {
      ref.read(productsProvider.notifier).update(n);
      if (mounted) toast(context, l.saved);
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
      searchText: (p) => '${p.name} ${p.barcode} ${p.category}',
      searchHint: l.searchProductHint,
      addLabel: l.addProduct,
      onAdd: _add,
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
        ColumnSpec(l.colProduct, (c, p) => Text(p.name, style: th.titleSmall), flex: 6),
        ColumnSpec(l.colCategory, (c, p) => Cell(p.category, muted: true), flex: 2),
        ColumnSpec(l.colPrice, (c, p) => Cell(formatPaise(p.pricePaise), bold: true), width: 100, numeric: true),
        ColumnSpec('GST', (c, p) => Cell('${p.gstBp ~/ 100}%', muted: true), width: 60, numeric: true),
        ColumnSpec(l.colStock, _stockCell, width: 130, numeric: true),
      ],
      phoneTitle: (c, p) => Text(p.name, style: th.titleSmall),
      phoneSubtitle: (p) => '${p.category}  ·  ₹ ${formatPaise(p.pricePaise)}',
      phoneTrailing: _stockCell,
    );
  }
}

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(productsProvider);
    final th = Theme.of(context).textTheme;
    // One shared valuation rule for now (buying price; unpriced and negative stock = 0; the shop has not chosen a rule yet, see docs/erp1-import-map.md section 7) so totals can never disagree between screens.
    int value(Product p) => p.stockMilli <= 0 ? 0 : p.costPaise * p.stockMilli ~/ 1000;
    final total = items.fold<int>(0, (s, p) => s + value(p));
    final low = items.where((p) => p.lowStock).length;
    final out = items.where((p) => p.outOfStock).length;
    return DataListScreen<Product>(
      title: l.navInventory,
      subtitle: l.inventorySubtitle,
      items: items,
      searchText: (p) => '${p.name} ${p.barcode}',
      searchHint: l.searchProductHint,
      stats: [
        StatCard(label: l.statStockValue, value: '₹ ${formatPaise(total)}', icon: Icons.account_balance_outlined, hint: l.valuationRule),
        StatCard(label: l.statItems, value: items.length.toString(), icon: Icons.inventory_2_outlined),
        StatCard(label: l.statLow, value: low.toString(), icon: Icons.warning_amber_rounded, tone: context.c.warning),
        StatCard(label: l.statOut, value: out.toString(), icon: Icons.block, tone: context.c.danger),
      ],
      filters: [FilterSpec(l.filterLow, (p) => p.lowStock), FilterSpec(l.filterOut, (p) => p.outOfStock)],
      sorts: [(l.sortValueHigh, (a, b) => value(b).compareTo(value(a))), (l.sortStockLow, (a, b) => a.stockMilli.compareTo(b.stockMilli))],
      columns: [
        ColumnSpec(l.colProduct, (c, p) => Text(p.name, style: th.titleSmall), flex: 6),
        ColumnSpec(l.colStock, _stockCell, width: 130, numeric: true),
        ColumnSpec(l.colCost, (c, p) => Cell(formatPaise(p.costPaise), muted: true), width: 90, numeric: true),
        ColumnSpec(l.colValue, (c, p) => Cell(formatPaise(value(p)), bold: true), width: 120, numeric: true),
      ],
      phoneTitle: (c, p) => Text(p.name, style: th.titleSmall),
      phoneSubtitle: (p) => '${l.colValue}: ₹ ${formatPaise(value(p))}',
      phoneTrailing: _stockCell,
    );
  }
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final items = ref.watch(recsProvider('categories'));
    return DataListScreen<Rec>(
      title: l.navCategories,
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
