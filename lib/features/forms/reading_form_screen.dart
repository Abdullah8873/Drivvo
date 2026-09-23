import 'package:flutter/material.dart';

import '../../core/theme/record_module.dart';
import '../../core/widgets/stub_screen.dart';

/// TODO: stub — replaced by the feature implementation.
class ReadingFormScreen extends StatelessWidget {
  const ReadingFormScreen({super.key, this.id});

  final String? id;

  @override
  Widget build(BuildContext context) =>
      StubScreen(title: 'Reading', color: RecordModule.reading.color);
}
