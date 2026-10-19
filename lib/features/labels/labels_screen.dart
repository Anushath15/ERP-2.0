import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/file_saver.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain/barcode.dart';
import '../../fake/data_providers.dart';
import '../../fake/models.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart';
import '../print/print_action.dart';
import 'label_pdf.dart';

/// Barcode labels for loose items (nails, nuts, pipe) that have no barcode: pick the products and how many stickers of each, press Print.
/// A product with no barcode gets the shop's own Code 128 barcode at that moment (kept on the product), so the counter scanner finds it
/// in the bill at once.
class LabelsScreen extends ConsumerStatefulWidget {
  const LabelsScreen({super.key});
  @override
  ConsumerState<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends ConsumerState<LabelsScreen> {
  final _search = TextEditingController();
  final _copies = <String, int>{}; // product id -> how many stickers (insertion order = print order)
  LabelSize _size = LabelSize.roll50x25;
  bool _busy = false;

  static const maxCopies = 500, maxTotal = 3000;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _total => _copies.values.fold(0, (a, b) => a + b);

  void _add(Product p) => setState(() {
        _copies.putIfAbsent(p.id, () => 1);
        _search.clear();
      });

  void _setCopies(String id, int n) => setState(() {
        if (n <= 0) {
          _copies.remove(id);
        } else {
          _copies[id] = n > maxCopies ? maxCopies : n;
        }
      });

  /// Gives every chosen product without a barcode one, then makes the PDF. Null when there is nothing to print.
  Future<({Uint8List bytes, int made, int skipped})?> _make() async {
    final l = tr(context);
    if (_copies.isEmpty) {
      toast(context, l.labelsEmpty);
      return null;
    }
    if (_total > maxTotal) {
      toast(context, l.labelsTooMany(maxTotal.toString()));
      return null;
    }
    final data = ref.read(appDataProvider);
    final notifier = ref.read(productsProvider.notifier);
    final shop = ref.read(shopProvider);
    var products = {for (final p in ref.read(productsProvider)) p.id: p};
    final missing = [for (final id in _copies.keys) if ((products[id]?.barcode ?? '').isEmpty) id];
    if (missing.isNotEmpty) {
      await data.catalog.assignBarcodes(missing);
      await notifier.reload(missing);
      products = {for (final p in ref.read(productsProvider)) p.id: p};
    }
    final items = <LabelItem>[];
    var skipped = 0;
    _copies.forEach((id, n) {
      final p = products[id];
      if (p == null) return;
      if (!canMakeCode128(p.barcode)) {
        skipped++;
        return;
      }
      items.add(LabelItem(name: p.name, priceText: labelPrice(p.pricePaise, pricesIncludeGst: shop.pricesIncludeGst, gstBp: p.gstBp), barcode: p.barcode, copies: n));
    });
    if (items.isEmpty) {
      if (mounted) toast(context, l.labelsNoneCan);
      return null;
    }
    return (bytes: await buildLabelsPdf(items: items, size: _size, title: l.navLabels), made: missing.length, skipped: skipped);
  }

  Future<void> _savePdf(Uint8List bytes) async {
    final where = await ref.read(fileSaverProvider).save('Barcode labels.pdf', bytes);
    if (!mounted) return;
    final l = tr(context);
    toast(context, where == null ? l.pdfFailed : l.pdfSaved(where));
  }

  Future<void> _printBytes(Uint8List bytes) async {
    if (!mounted) return;
    await printPdfNow(context, ref, bytes, tr(context).navLabels, forLabels: true);
  }

  Future<void> _run(Future<void> Function(Uint8List bytes) then) async {
    if (_busy) return;
    final l = tr(context);
    setState(() => _busy = true);
    try {
      final r = await _make();
      if (r == null || !mounted) return;
      if (r.made > 0) toast(context, l.labelsMadeCodes(r.made.toString()));
      if (r.skipped > 0 && mounted) toast(context, l.labelsSkipped(r.skipped.toString()));
      await then(r.bytes);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    final th = Theme.of(context).textTheme;
    final all = ref.watch(productsProvider);
    final byId = {for (final p in all) p.id: p};
    final q = _search.text.trim().toLowerCase();
    final hits = q.isEmpty
        ? const <Product>[]
        : [
            for (final p in all)
              if ('${p.name} ${p.code} ${p.brand} ${p.barcode}'.toLowerCase().contains(q) && !_copies.containsKey(p.id)) p
          ].take(6).toList();
    final withoutCode = [for (final p in all) if (p.barcode.isEmpty && !_copies.containsKey(p.id)) p];

    return PageFrame(
      title: l.navLabels,
      subtitle: l.labelsSubtitle,
      actions: [
        FilledButton.icon(
          key: const ValueKey('labelPrint'),
          onPressed: _busy || _copies.isEmpty ? null : () => _run(_printBytes),
          icon: const Icon(Icons.print_rounded),
          label: Text(l.print),
        ),
        OutlinedButton.icon(
          key: const ValueKey('labelPdf'),
          onPressed: _busy || _copies.isEmpty
              ? null
              : () => _run(_savePdf),
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: Text(l.saveAsPdf),
        ),
      ],
      child: ListView(children: [
        Text(l.labelsSize, style: th.titleSmall),
        const SizedBox(height: 6),
        SegmentedButton<LabelSize>(
          key: const ValueKey('labelSize'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: LabelSize.roll50x25, label: Text(l.labelSize5025)),
            ButtonSegment(value: LabelSize.roll38x25, label: Text(l.labelSize3825)),
            ButtonSegment(value: LabelSize.sheetA4, label: Text(l.labelSizeSheet)),
          ],
          selected: {_size},
          onSelectionChanged: (s) => setState(() => _size = s.first),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('labelSearch'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.labelsSearchHint),
        ),
        for (final p in hits)
          ListTile(
            key: ValueKey('labelHit-${p.id}'),
            dense: true,
            title: Text(p.name),
            subtitle: Text([if (p.code.isNotEmpty) p.code, if (p.brand.isNotEmpty) p.brand, p.barcode.isEmpty ? l.labelsNoBarcode : p.barcode].join('  ·  ')),
            trailing: const Icon(Icons.add_rounded),
            onTap: () => _add(p),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('labelAddMissing'),
            onPressed: withoutCode.isEmpty
                ? null
                : () => setState(() {
                      for (final p in withoutCode) {
                        _copies.putIfAbsent(p.id, () => 1);
                      }
                    }),
            icon: const Icon(Icons.playlist_add_rounded),
            label: Text(l.labelsAddMissing(withoutCode.length.toString())),
          ),
        ),
        const Divider(),
        if (_copies.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(l.labelsEmpty, style: th.bodyMedium?.copyWith(color: c.textMuted), textAlign: TextAlign.center)))
        else ...[
          for (final e in _copies.entries)
            if (byId[e.key] != null)
              Padding(
                key: ValueKey('labelRow-${e.key}'),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(byId[e.key]!.name, style: th.titleSmall),
                      Text(byId[e.key]!.barcode.isEmpty ? l.labelsWillMake : byId[e.key]!.barcode, style: th.bodySmall),
                    ]),
                  ),
                  IconButton(key: ValueKey('labelMinus-${e.key}'), tooltip: l.lessQty, onPressed: () => _setCopies(e.key, e.value - 1), icon: const Icon(Icons.remove_rounded)),
                  SizedBox(width: 36, child: Text('${e.value}', textAlign: TextAlign.center, style: th.titleMedium)),
                  IconButton(key: ValueKey('labelPlus-${e.key}'), tooltip: l.moreQty, onPressed: () => _setCopies(e.key, e.value + 1), icon: const Icon(Icons.add_rounded)),
                  IconButton(tooltip: l.removeLine, onPressed: () => _setCopies(e.key, 0), icon: const Icon(Icons.close_rounded)),
                ]),
              ),
          const Divider(),
          Text(l.labelsTotal(_total.toString()), key: const ValueKey('labelTotal'), style: th.titleSmall),
        ],
      ]),
    );
  }
}
