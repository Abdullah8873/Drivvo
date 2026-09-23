import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/module_form_scaffold.dart';
import 'catalog_labels.dart';
import 'catalog_queries.dart';

/// Asks for confirmation, then soft-deletes [item]. Returns true if deleted.
Future<bool> confirmDeleteCatalogItem(
  BuildContext context,
  WidgetRef ref,
  CatalogItem item,
) async {
  // Grab the db before awaiting: the widget may be gone after the dialog.
  final db = ref.read(databaseProvider);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete'),
      content: Text('Delete "${item.name}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('DELETE'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await db.softDeleteCatalogItem(item.id);
  return true;
}

/// Add / edit form for one catalog entry. Fields depend on the kind:
/// every kind has a Name; gas stations & places add an Address; fuels add
/// the tank kind (Liquids / Gas / Electric).
class CatalogItemFormScreen extends ConsumerStatefulWidget {
  const CatalogItemFormScreen({super.key, required this.kind, this.item});

  final CatalogKind kind;

  /// Null = create a new entry.
  final CatalogItem? item;

  @override
  ConsumerState<CatalogItemFormScreen> createState() =>
      _CatalogItemFormScreenState();
}

class _CatalogItemFormScreenState extends ConsumerState<CatalogItemFormScreen> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _address = TextEditingController(text: widget.item?.address);
  late FuelKind _fuelKind = widget.item?.fuelKind ?? FuelKind.liquid;
  String? _nameError;
  bool _saving = false;

  bool get _isNew => widget.item == null;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final kind = widget.kind;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter a name');
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    if (await db.catalogNameExists(kind, name, exceptId: widget.item?.id)) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _nameError = '"$name" already exists';
      });
      return;
    }

    final address = _address.text.trim().isEmpty ? null : _address.text.trim();
    final fuelKind = kind == CatalogKind.fuel ? _fuelKind : null;
    if (_isNew) {
      await db.addCatalogItem(
        kind: kind,
        name: name,
        fuelKind: fuelKind,
        address: kind.hasAddress ? address : null,
      );
    } else {
      await db.updateCatalogItem(
        widget.item!.id,
        name: name,
        fuelKind: kind == CatalogKind.fuel
            ? Value(fuelKind)
            : const Value.absent(),
        address: kind.hasAddress ? Value(address) : const Value.absent(),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final deleted = await confirmDeleteCatalogItem(context, ref, widget.item!);
    if (deleted && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    return Scaffold(
      appBar: AppBar(
        title: Text(kind.singular),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
          children: [
            FieldRow(
              icon: kind.icon,
              child: TextField(
                controller: _name,
                autofocus: _isNew,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: _nameError,
                ),
                // Clear the error as soon as the user edits the name.
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
                onSubmitted: (_) => kind.hasAddress ? null : _save(),
              ),
            ),
            if (kind.hasAddress)
              FieldRow(
                icon: Icons.map,
                child: TextField(
                  controller: _address,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
              ),
            if (kind == CatalogKind.fuel)
              FieldRow(
                icon: Icons.category,
                child: DropdownButtonFormField<FuelKind>(
                  initialValue: _fuelKind,
                  decoration: const InputDecoration(labelText: 'Type of fuel'),
                  items: [
                    for (final k in FuelKind.values)
                      DropdownMenuItem(value: k, child: Text(k.label)),
                  ],
                  onChanged: (k) => setState(() => _fuelKind = k ?? _fuelKind),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                onPressed: _saving ? null : _save,
                child: const Text('SAVE', style: TextStyle(letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
