import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/access_profile.dart';
import '../../core/sharing/active_account.dart';
import '../../core/widgets/main_tab_app_bar.dart';
import 'sharing_widgets.dart';

/// Shows [child] (the Reports tab) only when the active profile has the
/// Report › View switch; otherwise a short "no access" state.
class ReportsGate extends ConsumerWidget {
  const ReportsGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref
        .watch(currentAccessProvider)
        .can(AccessArea.report, AccessAction.view);
    if (allowed) return child;
    return const Scaffold(
      appBar: MainTabAppBar(),
      body: Center(
        child: SharingEmptyState(
          icon: Icons.lock_outline,
          lines: ["You don't have access to reports in this account."],
        ),
      ),
    );
  }
}
