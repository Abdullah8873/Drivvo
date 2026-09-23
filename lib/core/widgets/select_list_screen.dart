import 'package:flutter/material.dart';

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
    this.onAddNew,
  });

  final String title;
  final List<String> items;
  final bool multiSelect;
  final Set<String> initialSelection;

  /// Called by the "+" button; should return the created item's label.
  final Future<String?> Function()? onAddNew;

  @override
  State<SelectListScreen> createState() => _SelectListScreenState();
}

class _SelectListScreenState extends State<SelectListScreen> {
  late final Set<String> _selected = {...widget.initialSelection};
  late final List<String> _items = [...widget.items];
  String _query = '';

  List<String> get _filtered => _items
      .where((i) => i.toLowerCase().contains(_query.toLowerCase()))
      .toList();

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
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(indent: 56),
        itemBuilder: (context, i) {
          final item = items[i];
          return ListTile(
            leading: widget.multiSelect
                ? Checkbox(
                    value: _selected.contains(item),
                    onChanged: (_) => _tap(item),
                  )
                : null,
            title: Text(item),
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
