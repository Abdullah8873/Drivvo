import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Entry point — like index.tsx calling createRoot(...).render(`<App />`).
/// ProviderScope is Riverpod's store/context provider for the whole app.
void main() {
  runApp(const ProviderScope(child: MotoLogApp()));
}
