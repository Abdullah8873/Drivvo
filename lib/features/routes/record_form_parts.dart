import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import '../../core/widgets/module_form_scaffold.dart';
import '../../core/widgets/select_list_screen.dart';

/// Small building blocks shared by the Route and Reading forms.

/// Parses a user-typed number, accepting "," as decimal separator.
/// Returns null for empty or invalid input.
double? parseNumber(String text) {
  final t = text.trim().replaceAll(',', '.');
  return t.isEmpty ? null : double.tryParse(t);
}

/// Number → text for a form field ("56935" instead of "56935.0").
String numberInput(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// Trimmed text or null when blank (so empty fields are stored as NULL).
String? textOrNull(TextEditingController c) {
  final t = c.text.trim();
  return t.isEmpty ? null : t;
}

/// Shows a snackbar right away, replacing any one still on screen (the
/// messenger otherwise queues them, like toasts waiting their turn).
void showFormMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Shown instead of a form when there is no vehicle yet.
class NoVehicleView extends StatelessWidget {
  const NoVehicleView({super.key, required this.module});

  final RecordModule module;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: module.color, title: Text(module.label)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.two_wheeler, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Add a vehicle before recording a '
                '${module.label.toLowerCase()}.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: module.color),
                onPressed: () => context.push('/vehicles/new'),
                icon: const Icon(Icons.add),
                label: const Text('Add vehicle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spinner page while an edited record loads.
class FormLoadingView extends StatelessWidget {
  const FormLoadingView({super.key, required this.module});

  final RecordModule module;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(backgroundColor: module.color, title: Text(module.label)),
    body: const Center(child: CircularProgressIndicator()),
  );
}

/// "Vehicle" row: shows the chosen vehicle's name, tap to switch.
class VehicleField extends StatelessWidget {
  const VehicleField({
    super.key,
    required this.vehicles,
    required this.vehicleId,
    required this.onChanged,
  });

  final List<Vehicle> vehicles;
  final String? vehicleId;
  final ValueChanged<String> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => SelectListScreen(
          title: 'Vehicles',
          items: [for (final v in vehicles) v.name],
        ),
      ),
    );
    final name = picked?.firstOrNull;
    final v = vehicles.where((v) => v.name == name).firstOrNull;
    if (v != null) onChanged(v.id);
  }

  @override
  Widget build(BuildContext context) {
    final name = vehicles.where((v) => v.id == vehicleId).firstOrNull?.name;
    return FieldRow(
      icon: Icons.two_wheeler,
      child: PickerField(
        label: 'Vehicle',
        value: name,
        onTap: () => _pick(context),
      ),
    );
  }
}

/// Date + time pickers side by side, editing one [DateTime].
class DateTimeRow extends ConsumerWidget {
  const DateTimeRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.icon = Icons.event,
    this.dateLabel = 'Date',
    this.timeLabel = 'Time',
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final IconData icon;
  final String dateLabel;
  final String timeLabel;

  Future<void> _pickDate(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (d == null) return;
    onChanged(DateTime(d.year, d.month, d.day, value.hour, value.minute));
  }

  Future<void> _pickTime(BuildContext context) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (t == null) return;
    onChanged(DateTime(value.year, value.month, value.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(formattersProvider);
    return FieldRow(
      icon: icon,
      child: Row(
        children: [
          Expanded(
            child: PickerField(
              label: dateLabel,
              value: fmt.date(value),
              onTap: () => _pickDate(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PickerField(
              label: timeLabel,
              value: fmt.time(value),
              onTap: () => _pickTime(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Disabled "+ Attach file" button (attachments come with Supabase Storage).
class AttachFilePlaceholder extends StatelessWidget {
  const AttachFilePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: null, // TODO(milestone-6): attachments.
          icon: const Icon(Icons.add),
          label: const Text('Attach file'),
        ),
      ),
    );
  }
}

/// "Delete this X?" confirmation; resolves true when confirmed.
Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete this $what?'),
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
  return ok ?? false;
}

/// Asks for a single line of text (e.g. a new reason name).
Future<String?> promptText(BuildContext context, String title) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('ADD'),
        ),
      ],
    ),
  );
  controller.dispose();
  return (result == null || result.isEmpty) ? null : result;
}

/// Opens the Reasons pick list (with "+" to add one) and returns the chosen
/// catalog item, or null if the user backed out.
Future<CatalogItem?> pickReason(BuildContext context, AppDatabase db) async {
  var items = await db.watchCatalog(CatalogKind.reason).first;
  if (!context.mounted) return null;
  final picked = await Navigator.of(context).push<List<String>>(
    MaterialPageRoute(
      builder: (_) => SelectListScreen(
        title: 'Reasons',
        items: [for (final i in items) i.name],
        onAddNew: () async {
          final name = await promptText(context, 'New reason');
          if (name == null) return null;
          final row = await db
              .into(db.catalogItems)
              .insertReturning(
                CatalogItemsCompanion.insert(
                  kind: CatalogKind.reason,
                  name: name,
                ),
              );
          items = [...items, row];
          return name;
        },
      ),
    ),
  );
  final name = picked?.firstOrNull;
  return items.where((i) => i.name == name).firstOrNull;
}
