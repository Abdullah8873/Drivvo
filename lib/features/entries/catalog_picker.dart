import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/widgets/select_list_screen.dart';
import 'entry_queries.dart';

/// Opens the full-screen "Select" list for a catalog (types, places,
/// payment methods…) and returns the picked items, or null if cancelled.
/// The "+" button asks for a name and creates a new catalog item on the spot.
///
/// `SelectListScreen` works with plain labels, so this maps labels back to
/// [CatalogItem]s (like a `<select>` whose values are names).
Future<List<CatalogItem>?> pickCatalogItems(
  BuildContext context,
  AppDatabase db, {
  required CatalogKind kind,
  required String title,
  bool multiSelect = false,
  Set<String> selectedIds = const {},
}) async {
  final items = await db.watchCatalog(kind).first;
  final byName = {for (final i in items) i.name: i};
  if (!context.mounted) return null;

  final picked = await Navigator.of(context).push<List<String>>(
    MaterialPageRoute(
      builder: (_) => SelectListScreen(
        title: title,
        items: byName.keys.toList(),
        multiSelect: multiSelect,
        initialSelection: {
          for (final i in items)
            if (selectedIds.contains(i.id)) i.name,
        },
        onAddNew: () async {
          if (!context.mounted) return null;
          final name = await showCatalogNameDialog(context, title: title);
          if (name == null) return null;
          // Reuse an existing item with the same name instead of duplicating.
          final created = byName[name] ?? await db.addCatalogItem(kind, name);
          byName[name] = created;
          return name;
        },
      ),
    ),
  );
  if (picked == null) return null;
  return [for (final name in picked) ?byName[name]];
}

/// Single-select shortcut for [pickCatalogItems].
Future<CatalogItem?> pickCatalogItem(
  BuildContext context,
  AppDatabase db, {
  required CatalogKind kind,
  required String title,
}) async {
  final picked = await pickCatalogItems(context, db, kind: kind, title: title);
  return picked?.firstOrNull;
}

/// "New item" dialog with one name field. Returns the trimmed name, or null.
Future<String?> showCatalogNameDialog(
  BuildContext context, {
  required String title,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title),
  );
}

/// Stateful so the text controller is disposed with the dialog.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title});

  final String title;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        TextButton(onPressed: _submit, child: const Text('SAVE')),
      ],
    );
  }
}
