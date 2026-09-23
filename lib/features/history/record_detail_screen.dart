import 'package:flutter/material.dart';

import '../../core/theme/record_module.dart';
import '../../core/widgets/stub_screen.dart';

/// TODO: stub — replaced by the feature implementation.
class RecordDetailScreen extends StatelessWidget {
  const RecordDetailScreen({super.key, required this.module, required this.id});

  final RecordModule module;
  final String id;

  @override
  Widget build(BuildContext context) =>
      StubScreen(title: 'Record', color: module.color);
}
