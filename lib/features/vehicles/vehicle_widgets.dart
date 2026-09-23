import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import 'vehicle_labels.dart';

/// Teal counterpart of `ModuleFormScaffold` for forms that don't belong to a
/// record module: app bar + scrolling fields inside a [Form] + rounded SAVE.
class TealFormScaffold extends StatelessWidget {
  const TealFormScaffold({
    super.key,
    required this.title,
    required this.formKey,
    required this.children,
    required this.onSave,
    this.actions,
  });

  final String title;

  /// Lets the screen run the fields' validators (`formKey.currentState!.validate()`).
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onSave;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(
        // A (non-lazy) scroll view + Column, not ListView: ListView unmounts
        // off-screen rows, and `Form.validate()` only checks mounted fields.
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...children,
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: onSave,
                    child: const Text(
                      'SAVE',
                      style: TextStyle(letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Drivvo-style two/three-way toggle (e.g. ONE TANK | TWO TANKS).
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// (value, label) pairs, left to right.
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppTheme.primary,
        selectedForegroundColor: Colors.white,
        foregroundColor: AppTheme.primary,
      ),
      segments: [
        for (final (value, label) in options)
          ButtonSegment<T>(value: value, label: Text(label)),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Radio-list dialog (how Drivvo shows single choices). Resolves to the
/// picked option, or null if dismissed — like awaiting a modal's promise.
Future<T?> showChoiceDialog<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T? selected,
  required String Function(T) label,
  IconData Function(T)? icon,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: SingleChildScrollView(
        // RadioGroup owns the selected value; the tiles just declare theirs.
        child: RadioGroup<T>(
          groupValue: selected,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in options)
                RadioListTile<T>(
                  value: o,
                  title: Text(label(o)),
                  secondary: icon == null ? null : Icon(icon(o)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Round icon for a vehicle's type (used in lists and the picker).
class VehicleAvatar extends StatelessWidget {
  const VehicleAvatar({super.key, required this.type, this.enabled = true});

  final VehicleType type;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.primary : Colors.grey;
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(type.icon, color: color),
    );
  }
}

/// A vehicle row: type icon, name, "model · plate"; inactive ones greyed.
class VehicleTile extends StatelessWidget {
  const VehicleTile({
    super.key,
    required this.vehicle,
    this.onTap,
    this.trailing,
  });

  final Vehicle vehicle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final details = vehicleDetails(vehicle);
    final grey = vehicle.active ? null : Colors.grey;
    return ListTile(
      leading: VehicleAvatar(type: vehicle.type, enabled: vehicle.active),
      title: Text(vehicle.name),
      subtitle: details.isEmpty ? null : Text(details),
      textColor: grey,
      trailing:
          trailing ??
          (vehicle.active
              ? null
              : const Text('Inactive', style: TextStyle(color: Colors.grey))),
      onTap: onTap,
    );
  }
}
