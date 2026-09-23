import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../theme/app_theme.dart';

/// Full-screen picker used everywhere Drivvo shows a "Select" list: search
/// field in the app bar, tap to pick (or checkboxes + ✓ for multi-select),
/// and a "+" button to create a new entry.
///
/// Push it and await the result, like awaiting a modal in a web app:
/// `final picked = await Navigator.push<List<String>>(...);`
class SelectListScreen extends StatefulWidget {
  const SelectListScreen({
    super.key,
    required this.title,
    required this.items,
    this.multiSelect = false,
    this.initialSelection = const {},
    this.selected,
    this.onAddNew,
  });

  final String title;
  final List<String> items;
  final bool multiSelect;
  final Set<String> initialSelection;

  /// Single-select mode only: the item currently in effect (e.g. the active
  /// currency). Shown with a check mark and scrolled into view on open.
  final String? selected;

  /// Called by the "+" button; should return the created item's label.
  final Future<String?> Function()? onAddNew;

  @override
  State<SelectListScreen> createState() => _SelectListScreenState();
}

class _SelectListScreenState extends State<SelectListScreen> {
  late final Set<String> _selected = {...widget.initialSelection};
  late final List<String> _items = [...widget.items];
  String _query = '';

  /// Attached to the selected row (if any) so it can be located once built,
  /// to scroll it into view.
  final _selectedItemKey = GlobalKey();

  List<String> get _filtered => _items
      .where((i) => i.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  void initState() {
    super.initState();
    if (widget.selected == null) return;
    // The list is built with a large cache extent below (only when
    // `selected` is set) so the selected row exists in the tree straight
    // away, even off-screen — no need to guess a scroll offset by hand.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _selectedItemKey.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: 0.5);
    });
  }

  void _tap(String item) {
    if (!widget.multiSelect) {
      Navigator.pop(context, [item]);
      return;
    }
    setState(() {
      _selected.contains(item) ? _selected.remove(item) : _selected.add(item);
    });
  }

  Future<void> _addNew() async {
    final created = await widget.onAddNew?.call();
    if (created == null || created.isEmpty) return;
    setState(() {
      _items.add(created);
      _items.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (widget.multiSelect) _selected.add(created);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.multiSelect)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => Navigator.pop(context, _selected.toList()),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 10),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.search, color: Colors.white70, size: 18),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: ListView.separated(
        // A single-select list with a `selected` value (e.g. every ISO
        // currency) needs the selected row laid out immediately so it can
        // be scrolled into view — a huge cache extent forces that without
        // giving every other (much shorter) picker the same eager build.
        scrollCacheExtent: widget.selected == null
            ? null
            : const ScrollCacheExtent.pixels(100000),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(indent: 56),
        itemBuilder: (context, i) {
          final item = items[i];
          final isSelected = !widget.multiSelect && item == widget.selected;
          return ListTile(
            key: isSelected ? _selectedItemKey : null,
            leading: widget.multiSelect
                ? Checkbox(
                    value: _selected.contains(item),
                    onChanged: (_) => _tap(item),
                  )
                : null,
            title: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: isSelected
                ? const Icon(Icons.check, color: AppTheme.primary)
                : null,
            onTap: () => _tap(item),
          );
        },
      ),
      floatingActionButton: widget.onAddNew == null
          ? null
          : FloatingActionButton(
              shape: const CircleBorder(),
              onPressed: _addNew,
              child: const Icon(Icons.add),
            ),
    );
  }
}
