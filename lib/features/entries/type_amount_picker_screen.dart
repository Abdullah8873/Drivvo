import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../routes/record_form_parts.dart' show parseNumber;
import 'catalog_picker.dart' show showCatalogNameDialog;
import 'entry_queries.dart' show EntryQueries;

/// One picked catalog item with the amount typed for it (null if the user
/// checked it but left the value blank).
typedef TypeAmount = (CatalogItem item, double? amount);

/// Opens Drivvo's types-with-amounts picker: a full-screen, searchable,
/// multi-select list (like `SelectListScreen`) where ticking a type's
/// checkbox reveals an inline "Value" field for its price, right there in
/// the row, instead of a separate dialog per type afterwards.
///
/// [initial] pre-checks the form's current lines with their values (keyed by
/// catalog item id). Returns the picked types with their entered amounts, or
/// null if the user backed out without confirming.
Future<List<TypeAmount>?> pickTypeAmounts(
  BuildContext context,
  AppDatabase db, {
  required CatalogKind kind,
  required String title,
  required String currencyCode,
  Map<String, double?> initial = const {},
}) async {
  final items = await db.watchCatalog(kind).first;
  if (!context.mounted) return null;
  return Navigator.of(context).push<List<TypeAmount>>(
    MaterialPageRoute(
      builder: (_) => _TypeAmountPickerScreen(
        title: title,
        items: items,
        initial: initial,
        currencyCode: currencyCode,
        onAddNew: () async {
          if (!context.mounted) return null;
          final name = await showCatalogNameDialog(context, title: title);
          if (name == null) return null;
          return db.addCatalogItem(kind, name);
        },
      ),
    ),
  );
}

class _TypeAmountPickerScreen extends StatefulWidget {
  const _TypeAmountPickerScreen({
    required this.title,
    required this.items,
    required this.initial,
    required this.currencyCode,
    required this.onAddNew,
  });

  final String title;
  final List<CatalogItem> items;
  final Map<String, double?> initial;
  final String currencyCode;

  /// Called by the "+" button; should return the newly created item, or
  /// null if the user backed out of the name dialog.
  final Future<CatalogItem?> Function() onAddNew;

  @override
  State<_TypeAmountPickerScreen> createState() =>
      _TypeAmountPickerScreenState();
}

class _TypeAmountPickerScreenState extends State<_TypeAmountPickerScreen> {
  late final List<CatalogItem> _items = [...widget.items];
  late final Set<String> _selected = {...widget.initial.keys};

  /// One amount controller per item, created upfront so a value typed while
  /// checked survives an accidental uncheck/recheck within the same picker.
  final _amounts = <String, TextEditingController>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    for (final item in _items) {
      _amounts[item.id] = TextEditingController(
        text: _plain(widget.initial[item.id]),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _plain(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  List<CatalogItem> get _filtered => _items
      .where((i) => i.name.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  void _toggle(CatalogItem item) {
    setState(() {
      _selected.contains(item.id)
          ? _selected.remove(item.id)
          : _selected.add(item.id);
    });
  }

  void _confirm() {
    Navigator.pop(context, [
      for (final item in _items)
        if (_selected.contains(item.id))
          (item, parseNumber(_amounts[item.id]!.text)),
    ]);
  }

  Future<void> _addNew() async {
    final created = await widget.onAddNew();
    if (created == null) return;
    setState(() {
      _items.add(created);
      _items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      _amounts[created.id] = TextEditingController();
      _selected.add(created.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _confirm),
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
          final checked = _selected.contains(item.id);
          return ListTile(
            leading: Checkbox(value: checked, onChanged: (_) => _toggle(item)),
            title: Text(item.name),
            trailing: checked
                ? SizedBox(
                    width: 96,
                    child: TextField(
                      key: Key('amount-${item.name}'),
                      controller: _amounts[item.id],
                      autofocus: true,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Value',
                        prefixText: '${widget.currencyCode} ',
                        isDense: true,
                      ),
                    ),
                  )
                : null,
            onTap: () => _toggle(item),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        onPressed: _addNew,
        child: const Icon(Icons.add),
      ),
    );
  }
}
