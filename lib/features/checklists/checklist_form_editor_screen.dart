import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/module_form_scaffold.dart';
import 'checklist_queries.dart';

/// Create/edit one checklist template: name, a reorderable item list (drag
/// handle, ✕ per row, "+ Add item") and notes. Pops with the template's id
/// after SAVE, so the checklist form's "+" can select the new template
/// straight away.
class ChecklistFormEditorScreen extends ConsumerStatefulWidget {
  const ChecklistFormEditorScreen({super.key, this.id});

  /// Null = new template.
  final String? id;

  @override
  ConsumerState<ChecklistFormEditorScreen> createState() =>
      _ChecklistFormEditorScreenState();
}

/// One editable template line; [key] keeps its row (and text field) stable
/// while dragging, like a React `key`.
class _ItemRow {
  _ItemRow({this.id, String label = ''})
    : label = TextEditingController(text: label);

  final String? id;
  final TextEditingController label;
  final key = UniqueKey();
}

class _ChecklistFormEditorScreenState
    extends ConsumerState<ChecklistFormEditorScreen> {
  bool get _isNew => widget.id == null;
  late bool _loading = !_isNew;
  bool _saving = false;
  bool _dirty = false;
  String? _nameError;

  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _items = <_ItemRow>[];

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _items.add(_ItemRow());
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final details = await ref
        .read(databaseProvider)
        .getChecklistForm(widget.id!);
    if (!mounted) return;
    if (details == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _name.text = details.form.name;
      _notes.text = details.form.notes ?? '';
      _items.addAll([
        for (final i in details.items) _ItemRow(id: i.id, label: i.label),
      ]);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    for (final i in _items) {
      i.label.dispose();
    }
    super.dispose();
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter a name');
      return;
    }
    final items = <FormItemDraft>[
      for (final i in _items)
        if (i.label.text.trim().isNotEmpty)
          (id: i.id, label: i.label.text.trim()),
    ];
    if (items.isEmpty) return _snack('Add at least one item');
    setState(() => _saving = true);
    final notes = _notes.text.trim();
    final id = await ref
        .read(databaseProvider)
        .saveChecklistForm(
          id: widget.id,
          name: name,
          notes: notes.isEmpty ? null : notes,
          items: items,
        );
    if (!mounted) return;
    Navigator.of(context).pop(id);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this form?'),
        content: const Text(
          'Checklists already filled in with it keep their items.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).deleteChecklistForm(widget.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _addItem() {
    _touch();
    setState(() => _items.add(_ItemRow()));
  }

  void _removeItem(_ItemRow row) {
    _touch();
    setState(() => _items.remove(row));
    // Disposed after the frame: the row's TextField is still mounted now.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.label.dispose());
  }

  void _reorder(int from, int to) {
    _touch();
    // `onReorderItem` already adjusted [to] for the removed row.
    setState(() => _items.insert(to, _items.removeAt(from)));
  }

  @override
  Widget build(BuildContext context) {
    final title = _isNew ? 'New form' : 'Edit form';
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return UnsavedChangesGuard(
      isDirty: () => _dirty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
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
                icon: Icons.description,
                child: TextField(
                  key: const Key('form-name'),
                  controller: _name,
                  autofocus: _isNew,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: _nameError,
                  ),
                  onChanged: (_) {
                    _touch();
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 16, 0, 4),
                child: Text(
                  'ITEMS',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: AppTheme.primary, letterSpacing: 0.8),
                ),
              ),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _items.length,
                onReorderItem: _reorder,
                itemBuilder: (context, i) {
                  final row = _items[i];
                  return Row(
                    key: row.key,
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.drag_handle,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          key: Key('form-item-$i'),
                          controller: row.label,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Item ${i + 1}',
                          ),
                          onChanged: (_) => _touch(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove item',
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeItem(row),
                      ),
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ),
              ),
              FieldRow(
                icon: Icons.notes,
                child: TextField(
                  controller: _notes,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  onChanged: (_) => _touch(),
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
      ),
    );
  }
}
