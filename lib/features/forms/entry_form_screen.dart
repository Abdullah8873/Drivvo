import 'package:flutter/material.dart';

import '../../core/db/tables.dart';
import '../../core/theme/record_module.dart';
import '../../core/widgets/stub_screen.dart';

/// TODO: stub — replaced by the feature implementation.
class EntryFormScreen extends StatelessWidget {
  const EntryFormScreen({super.key, required this.kind, this.id});

  final EntryKind kind;

  /// Null = create; otherwise edit this entry.
  final String? id;

  @override
  Widget build(BuildContext context) => StubScreen(
    title: 'Entry',
    color: RecordModule.values.byName(kind.name).color,
  );
}
