import 'package:flutter/material.dart';

import '../theme/record_module.dart';

/// Full-screen form page in a module's color: colored app bar, scrolling
/// fields and a full-width rounded SAVE button at the bottom.
class ModuleFormScaffold extends StatelessWidget {
  const ModuleFormScaffold({
    super.key,
    required this.module,
    required this.children,
    required this.onSave,
    this.title,
    this.actions,
  });

  final RecordModule module;
  final String? title;
  final List<Widget> children;
  final VoidCallback onSave;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Re-tint accents (cursor, switches, focused underline) with the module color.
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme
            .copyWith(primary: module.color),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: module.color,
          title: Text(title ?? module.label),
          actions: actions,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
            children: [
              ...children,
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: module.color,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onSave,
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

/// One form row: grey leading icon + the field(s). Mirrors Drivvo's layout
/// where every input has an icon in a left gutter.
class FieldRow extends StatelessWidget {
  const FieldRow({super.key, this.icon, required this.child, this.helper});

  final IconData? icon;
  final Widget child;

  /// Small right-aligned hint under the field (e.g. "Last odometer: 56935 km").
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: icon == null
                  ? null
                  : Icon(icon, size: 22, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                child,
                if (helper != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      helper!,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A read-only field that opens a picker when tapped (fuel, station, type…).
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        isEmpty: value == null || value!.isEmpty,
        decoration: InputDecoration(labelText: label),
        child: Text(value ?? ''),
      ),
    );
  }
}
