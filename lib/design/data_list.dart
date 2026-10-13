import 'package:flutter/material.dart';
import '../core/responsive.dart';
import 'tokens.dart';
import 'widgets.dart';

class ColumnSpec<T> {
  const ColumnSpec(this.label, this.cell, {this.flex = 1, this.numeric = false, this.width});
  final String label;
  final Widget Function(BuildContext, T) cell;
  final int flex;
  final bool numeric;
  final double? width;
}

class FilterSpec<T> {
  const FilterSpec(this.label, this.test);
  final String label;
  final bool Function(T) test;
}

/// One list screen for almost everything: search, filter chips, a table on wide screens and cards on phones.
/// Rows are built lazily (virtualised), so 20,000 rows stay smooth.
class DataListScreen<T> extends StatefulWidget {
  const DataListScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.searchText,
    required this.columns,
    required this.phoneTitle,
    this.phoneSubtitle,
    this.phoneTrailing,
    this.filters = const [],
    this.addLabel,
    this.onAdd,
    this.onTap,
    this.actions = const [],
    this.stats = const [],
    this.emptyTitle,
    this.emptyText,
    this.emptyIcon = Icons.inbox_outlined,
    this.searchHint,
    this.sorts = const [],
  });
  final String title;
  final String? subtitle;
  final List<T> items;
  final String Function(T) searchText;
  final List<ColumnSpec<T>> columns;
  final Widget Function(BuildContext, T) phoneTitle;
  final String Function(T)? phoneSubtitle;
  final Widget Function(BuildContext, T)? phoneTrailing;
  final List<FilterSpec<T>> filters;
  final String? addLabel;
  final VoidCallback? onAdd;
  final void Function(BuildContext, T)? onTap;
  final List<Widget> actions;
  final List<Widget> stats;
  final String? emptyTitle, emptyText, searchHint;
  final IconData emptyIcon;
  final List<(String, int Function(T, T))> sorts;

  @override
  State<DataListScreen<T>> createState() => _DataListScreenState<T>();
}

class _DataListScreenState<T> extends State<DataListScreen<T>> {
  String _q = '';
  int _filter = 0;
  int _sort = 0;
  List<T>? _cache;
  String _cacheKey = '';
  Object? _cacheSrc;

  List<T> _visible() {
    final key = '$_q|$_filter|$_sort';
    if (_cache != null && key == _cacheKey && identical(_cacheSrc, widget.items)) return _cache!;
    final q = _q.trim().toLowerCase();
    final tokens = q.isEmpty ? const <String>[] : q.split(RegExp(r'\s+'));
    Iterable<T> r = widget.items;
    if (widget.filters.isNotEmpty && _filter > 0) {
      final f = widget.filters[_filter - 1];
      r = r.where(f.test);
    }
    if (tokens.isNotEmpty) {
      r = r.where((e) {
        final s = widget.searchText(e).toLowerCase();
        return tokens.every(s.contains);
      });
    }
    var list = r.toList(growable: false);
    if (widget.sorts.isNotEmpty && _sort > 0) {
      list = [...list]..sort(widget.sorts[_sort - 1].$2);
    }
    _cacheKey = key;
    _cacheSrc = widget.items;
    return _cache = list;
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final phone = context.isPhone;
    final rows = _visible();
    final th = Theme.of(context).textTheme;
    final c = context.c;

    final addBtn = widget.onAdd == null
        ? null
        : FilledButton.icon(onPressed: widget.onAdd, icon: const Icon(Icons.add), label: Text(widget.addLabel ?? l.addNew));

    final toolbar = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.stats.isNotEmpty) ...[
        LayoutBuilder(builder: (ctx, bc) {
          final cols = (bc.maxWidth / ctx.textFactor) > 900 ? 4 : ((bc.maxWidth / ctx.textFactor) > 560 ? 2 : 1);
          final w = (bc.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final s in widget.stats) SizedBox(width: w.floorToDouble(), child: s)]);
        }),
        const SizedBox(height: 12),
      ],
      Row(children: [
        Expanded(child: SearchField(hint: widget.searchHint ?? l.searchHere, onChanged: (v) => setState(() => _q = v), autofocus: !phone)),
        if (widget.sorts.isNotEmpty) ...[
          const SizedBox(width: 8),
          PopupMenuButton<int>(
            tooltip: l.sortBy,
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 0, child: Text(l.sortDefault)),
              for (var i = 0; i < widget.sorts.length; i++) PopupMenuItem(value: i + 1, child: Text(widget.sorts[i].$1)),
            ],
          ),
        ],
      ]),
      if (widget.filters.isNotEmpty) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i <= widget.filters.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(i == 0 ? l.filterAll : widget.filters[i - 1].label),
                  selected: _filter == i,
                  onSelected: (_) => setState(() => _filter = i),
                ),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 10),
    ]);

    Widget list;
    if (rows.isEmpty) {
      list = EmptyState(
        icon: widget.emptyIcon,
        title: _q.isNotEmpty || _filter > 0 ? l.nothingFound : (widget.emptyTitle ?? l.nothingHere),
        text: _q.isNotEmpty || _filter > 0 ? l.nothingFoundHelp : widget.emptyText,
        action: _q.isEmpty && addBtn != null ? addBtn : null,
      );
    } else if (phone) {
      list = ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        padding: const EdgeInsets.only(bottom: 12),
        itemBuilder: (ctx, i) {
          final e = rows[i];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.m),
              onTap: widget.onTap == null ? null : () => widget.onTap!(ctx, e),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      widget.phoneTitle(ctx, e),
                      if (widget.phoneSubtitle != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(widget.phoneSubtitle!(e), style: th.bodySmall)),
                    ]),
                  ),
                  if (widget.phoneTrailing != null) Padding(padding: const EdgeInsets.only(left: 10), child: widget.phoneTrailing!(ctx, e)),
                ]),
              ),
            ),
          );
        },
      );
    } else {
      list = Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            color: c.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              for (final col in widget.columns)
                _cellBox(col.flex, col.width, col.numeric, Text(col.label, style: th.labelMedium?.copyWith(color: c.textMuted), textAlign: col.numeric ? TextAlign.right : TextAlign.left)),
            ]),
          ),
          const Divider(),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (ctx, i) {
                final e = rows[i];
                return InkWell(
                  onTap: widget.onTap == null ? null : () => widget.onTap!(ctx, e),
                  hoverColor: c.rowSelected,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Sizes.rowHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        for (final col in widget.columns) _cellBox(col.flex, col.width, col.numeric, col.cell(ctx, e)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      );
    }

    return PageFrame(
      title: widget.title,
      subtitle: widget.subtitle,
      actions: [...widget.actions, ?addBtn],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        toolbar,
        Expanded(child: list),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(l.resultCount(rows.length.toString()), style: th.bodySmall),
        ),
      ]),
    );
  }

  Widget _cellBox(int flex, double? width, bool numeric, Widget child) {
    final box = Align(alignment: numeric ? Alignment.centerRight : Alignment.centerLeft, child: child);
    if (width != null) return SizedBox(width: width, child: Padding(padding: const EdgeInsets.only(right: 8), child: box));
    return Expanded(flex: flex, child: Padding(padding: const EdgeInsets.only(right: 8), child: box));
  }
}

/// Plain bold/normal text cell that wraps (never an ellipsis).
class Cell extends StatelessWidget {
  const Cell(this.text, {super.key, this.bold = false, this.muted = false, this.color});
  final String text;
  final bool bold, muted;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).textTheme;
    return Text(text, style: (bold ? th.titleSmall : th.bodyMedium)?.copyWith(color: color ?? (muted ? context.c.textMuted : null)));
  }
}
