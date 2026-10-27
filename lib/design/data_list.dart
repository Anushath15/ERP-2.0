import 'dart:async';
import 'package:flutter/material.dart';
import '../core/responsive.dart';
import '../core/search_rank.dart';
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

/// What a paged list is asked for: the text typed, the filter chip chosen (0 = all) and the sort chosen (0 = default).
class PageQuery {
  const PageQuery(this.text, this.filter, this.sort);
  final String text;
  final int filter, sort;
}

/// One page of rows and where the next one starts ([next] null = that was the last page).
class PageResult<T> {
  const PageResult(this.rows, this.next);
  final List<T> rows;
  final Object? next;
}

/// For lists that can be huge (a million bills): rows come from the database a page at a time, as the person scrolls. Search,
/// filter and sort are asked of the database, not done in memory.
class PagedSource<T> {
  const PagedSource({required this.load, this.total, this.initial});
  final Future<PageResult<T>> Function(PageQuery query, Object? cursor) load;

  /// How many rows match, shown under the list when given.
  final Future<int> Function(PageQuery query)? total;

  /// The first page for an empty search, already read (so the list shows rows in its very first frame).
  final PageResult<T>? initial;
}

/// One list screen for almost everything: search, filter chips, a table on wide screens and cards on phones.
/// Rows are built lazily (virtualised), so 20,000 rows stay smooth.
String _noText(Object? _) => '';

class DataListScreen<T> extends StatefulWidget {
  const DataListScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.items = const [],
    this.searchText = _noText,
    this.source,
    this.refreshKey,
    required this.columns,
    required this.phoneTitle,
    this.phoneSubtitle,
    this.phoneTrailing,
    this.phoneActions,
    this.filters = const [],
    this.addLabel,
    this.onAdd,
    this.onTap,
    this.actions = const [],
    this.stats = const [],
    this.emptyTitle,
    this.emptyText,
    this.emptyIcon = Icons.inbox_rounded,
    this.searchHint,
    this.sorts = const [],
  });
  final String title;
  final String? subtitle;
  final List<T> items;
  final String Function(T) searchText;

  /// When given, rows are loaded page by page from here and [items] is ignored.
  final PagedSource<T>? source;

  /// Changes when the data behind a paged list changed (a bill was saved): the list starts again from the top.
  final Object? refreshKey;
  final List<ColumnSpec<T>> columns;
  final Widget Function(BuildContext, T) phoneTitle;
  final String Function(T)? phoneSubtitle;
  final Widget Function(BuildContext, T)? phoneTrailing;
  final Widget Function(BuildContext, T)? phoneActions; // extra row under a phone card (buttons, badges)
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

  // paged mode
  List<T> _rows = [];
  Object? _next;
  bool _loading = false, _more = true;
  int _epoch = 0;
  int? _total;
  Timer? _debounce;
  Timer? _spinTimer;
  bool _spin = false;

  PageQuery get _query => PageQuery(_q.trim(), _filter, _sort);

  @override
  void initState() {
    super.initState();
    final src = widget.source;
    if (src == null) return;
    final first = src.initial;
    if (first != null) {
      _rows = first.rows;
      _next = first.next;
      _more = first.next != null && first.rows.isNotEmpty;
    } else {
      unawaited(_reload());
    }
  }

  @override
  void didUpdateWidget(DataListScreen<T> old) {
    super.didUpdateWidget(old);
    if (widget.source != null && (old.refreshKey != widget.refreshKey || !identical(old.source, widget.source))) unawaited(_reload());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _spinTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final epoch = ++_epoch;
    _loading = false;
    _total = null;
    _spin = false;
    _spinTimer?.cancel();
    if (_rows.isEmpty) {
      _spinTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted && epoch == _epoch && _rows.isEmpty) setState(() => _spin = true);
      });
    }
    final src = widget.source;
    if (src == null) return;
    _loading = true;
    try {
      // the old rows stay on screen until the new first page is there (no flash of an empty list)
      final page = await src.load(_query, null);
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _rows = page.rows;
        _next = page.next;
        _more = page.next != null && page.rows.isNotEmpty;
      });
    } finally {
      if (epoch == _epoch) _loading = false;
    }
    final totalFn = src.total;
    if (totalFn != null) {
      final n = await totalFn(_query);
      if (mounted && epoch == _epoch) setState(() => _total = n);
    }
  }

  Future<void> _loadMore() async {
    final e = _epoch;
    final src = widget.source;
    if (src == null || _loading || !_more) return;
    _loading = true;
    try {
      final page = await src.load(_query, _next);
      if (!mounted || e != _epoch) return;
      setState(() {
        _rows = [..._rows, ...page.rows];
        _next = page.next;
        _more = page.next != null && page.rows.isNotEmpty;
      });
    } finally {
      if (e == _epoch) _loading = false;
    }
  }

  void _search(String v) {
    setState(() => _q = v);
    if (widget.source == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () => unawaited(_reload()));
  }

  List<T> _visible() {
    if (widget.source != null) return _rows;
    if (_q.trim().isEmpty && _filter == 0 && _sort == 0) return widget.items; // nothing to do: keeps lazy lists lazy
    final key = '$_q|$_filter|$_sort';
    if (_cache != null && key == _cacheKey && identical(_cacheSrc, widget.items)) return _cache!;
    final q = _q.trim().toLowerCase();
    final tokens = q.isEmpty ? const <String>[] : q.split(RegExp(r'\s+'));
    Iterable<T> r = widget.items;
    if (widget.filters.isNotEmpty && _filter > 0) {
      final f = widget.filters[_filter - 1];
      r = r.where(f.test);
    }
    var list = r.toList(growable: false);
    if (tokens.isNotEmpty) {
      // every typed word must be there, then BEST MATCH FIRST (a whole word beats a part of another number); a chosen sort overrides it
      list = rankedSearch(list, q, widget.searchText);
    }
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
        : FilledButton.icon(onPressed: widget.onAdd, icon: const Icon(Icons.add_rounded), label: Text(widget.addLabel ?? l.addNew));

    // On a very small screen with very big text the summary cards would push the list out of the window: they wait until there is room.
    final tiny = MediaQuery.sizeOf(context).height / context.textFactor < 380;
    final toolbar = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.stats.isNotEmpty && !tiny) ...[
        LayoutBuilder(builder: (ctx, bc) {
          final cols = (bc.maxWidth / ctx.textFactor) > 900 ? 4 : ((bc.maxWidth / ctx.textFactor) > 560 ? 2 : 1);
          final w = (bc.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final s in widget.stats) SizedBox(width: w.floorToDouble(), child: s)]);
        }),
        const SizedBox(height: 12),
      ],
      Row(children: [
        Expanded(child: SearchField(hint: widget.searchHint ?? l.searchHere, onChanged: _search, autofocus: !phone)),
        if (widget.sorts.isNotEmpty) ...[
          const SizedBox(width: 8),
          PopupMenuButton<int>(
            tooltip: l.sortBy,
            icon: const Icon(Icons.sort_rounded),
            onSelected: (v) {
              setState(() => _sort = v);
              if (widget.source != null) unawaited(_reload());
            },
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
                  onSelected: (_) {
                    setState(() => _filter = i);
                    if (widget.source != null) unawaited(_reload());
                  },
                ),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 10),
    ]);

    Widget list;
    if (rows.isEmpty && widget.source != null && (_loading || _more)) {
      list = _spin ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink(); // a quick load shows nothing in between
    } else if (rows.isEmpty) {
      list = EmptyState(
        icon: widget.emptyIcon,
        title: _q.isNotEmpty || _filter > 0 ? l.nothingFound : (widget.emptyTitle ?? l.nothingHere),
        text: _q.isNotEmpty || _filter > 0 ? l.nothingFoundHelp : widget.emptyText,
        action: _q.isEmpty && addBtn != null ? addBtn : null,
      );
    } else if (phone) {
      list = ListView.separated(
        itemCount: rows.length + (widget.source != null && _more ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        padding: const EdgeInsets.only(bottom: 12),
        itemBuilder: (ctx, i) {
          if (i >= rows.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_loadMore()));
            return const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
          }
          if (widget.source != null && i >= rows.length - 8) WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_loadMore()));
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
                      if (widget.phoneActions != null) Padding(padding: const EdgeInsets.only(top: 8), child: widget.phoneActions!(ctx, e)),
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
            child: RepaintBoundary(child: ListView.separated(
              itemCount: rows.length + (widget.source != null && _more ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (ctx, i) {
                if (i >= rows.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_loadMore()));
                  return const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
                }
                if (widget.source != null && i >= rows.length - 8) WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_loadMore()));
                final e = rows[i];
                return InkWell(
                  onTap: widget.onTap == null ? null : () => widget.onTap!(ctx, e),
                  hoverColor: c.rowSelected,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: context.metrics.rowHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.metrics.padH, vertical: context.metrics.padV - 1),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        for (final col in widget.columns) _cellBox(col.flex, col.width, col.numeric, col.cell(ctx, e)),
                      ]),
                    ),
                  ),
                );
              },
            )),
          ),
        ]),
      );
    }

    return PageFrame(
      title: widget.title,
      subtitle: widget.subtitle,
      actions: [...widget.actions, ?addBtn],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5), child: SingleChildScrollView(child: toolbar)),
        Expanded(child: list),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(l.resultCount((widget.source != null ? (_total ?? rows.length) : rows.length).toString()), style: th.bodySmall),
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
