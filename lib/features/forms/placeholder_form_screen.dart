import 'package:flutter/material.dart';

import '../../core/theme/record_module.dart';
import '../../core/widgets/module_form_scaffold.dart';

/// Temporary form for modules that are built in milestone 3.
class PlaceholderFormScreen extends StatelessWidget {
  const PlaceholderFormScreen({super.key, required this.module});

  final RecordModule module;

  @override
  Widget build(BuildContext context) {
    return ModuleFormScaffold(
      module: module,
      onSave: () => Navigator.of(context).pop(),
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '${module.label} form is coming in milestone 3.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
