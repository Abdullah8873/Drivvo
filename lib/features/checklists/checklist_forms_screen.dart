import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import 'checklist_form_editor_screen.dart';
import 'checklist_queries.dart';

/// Live checklist templates with their item counts.
final checklistFormsProvider = StreamProvider<List<ChecklistFormSummary>>(
  (ref) => ref.watch(databaseProvider).watchChecklistForms(),
);

/// More → Forms: the checklist templates (name + "N items"). Tap to edit,
/// FAB + to create. Drivvo keeps this behind its Fleet plan, so the layout
/// follows our catalog screens.
class ChecklistFormsScreen extends ConsumerWidget {
  const ChecklistFormsScreen({super.key});

  void _open(BuildContext context, [String? id]) {
    Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (_) => ChecklistFormEditorScreen(id: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forms = ref.watch(checklistFormsProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Forms')),
      body: forms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  'No checklist forms yet.\nTap + to create one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(indent: 72),
                itemBuilder: (context, i) {
                  final s = list[i];
                  return ListTile(
                    leading: Icon(
                      RecordModule.checklist.icon,
                      color: RecordModule.checklist.color,
                    ),
                    title: Text(s.form.name),
                    subtitle: Text(
                      '${s.itemCount} ${s.itemCount == 1 ? 'item' : 'items'}',
                    ),
                    onTap: () => _open(context, s.form.id),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        tooltip: 'Add',
        onPressed: () => _open(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
