import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/widgets/select_list_screen.dart';

/// Opens the full-screen "Select" list for a catalog [kind] and returns the
/// picked item (null if the user backed out). The "+" button asks for a
/// name and inserts a new catalog item on the spot.
///
/// [items] limits the choices (e.g. only fuels matching the vehicle's tank);
/// by default every item of [kind] is listed. [newFuelKind] tags fuels
/// created from here.
Future<CatalogItem?> pickCatalogItem(
  BuildContext context,
  WidgetRef ref, {
  required CatalogKind kind,
  required String title,
  List<CatalogItem>? items,
  FuelKind? newFuelKind,
}) async {
  final db = ref.read(databaseProvider);
  final choices = items ?? await db.watchCatalog(kind).first;
  if (!context.mounted) return null;

  final created = <String, CatalogItem>{};
  final picked = await Navigator.of(context).push<List<String>>(
    MaterialPageRoute(
      builder: (pickerContext) => SelectListScreen(
        title: title,
        items: [for (final c in choices) c.name],
        onAddNew: () async {
          final name = await promptCatalogName(pickerContext, title: title);
          if (name == null) return null;
          created[name] = await db
              .into(db.catalogItems)
              .insertReturning(
                CatalogItemsCompanion.insert(
                  kind: kind,
                  name: name,
                  fuelKind: Value(newFuelKind),
                ),
              );
          return name;
        },
      ),
    ),
  );
  final name = picked?.firstOrNull;
  if (name == null) return null;
  return created[name] ?? choices.where((c) => c.name == name).firstOrNull;
}

/// Small "New item" dialog with one text field. Returns the trimmed name or
/// null when cancelled/empty.
Future<String?> promptCatalogName(BuildContext context, {String? title}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({this.title});

  final String? title;

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
    Navigator.pop(context, name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title == null ? 'New item' : 'New · ${widget.title}'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(onPressed: _submit, child: const Text('ADD')),
      ],
    );
  }
}
