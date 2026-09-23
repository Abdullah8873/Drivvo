import 'package:flutter/material.dart';

import '../../core/db/tables.dart';
import '../../core/widgets/stub_screen.dart';

/// TODO: stub — replaced by the feature implementation.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.kind});

  final CatalogKind kind;

  @override
  Widget build(BuildContext context) => StubScreen(title: 'Catalog');
}
