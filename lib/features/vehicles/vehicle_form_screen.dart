import 'package:flutter/material.dart';

import '../../core/widgets/stub_screen.dart';

/// TODO: stub — replaced by the feature implementation.
class VehicleFormScreen extends StatelessWidget {
  const VehicleFormScreen({super.key, this.id});

  /// Null = create a new vehicle.
  final String? id;

  @override
  Widget build(BuildContext context) => StubScreen(title: 'Vehicle');
}
