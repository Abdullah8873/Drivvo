import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/calc/access_profile.dart';
import '../../core/calc/member_access.dart';
import '../../core/cloud/auth_state.dart';
import '../../core/cloud/cloud_config.dart';
import '../../core/providers.dart';
import '../../core/sharing/active_account.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/record_module.dart';

/// Opens the share sheet with plain text (an invitation, a transfer
/// code). Overridden in tests to record the text instead.
final textSharerProvider = Provider<Future<void> Function(String text)>(
  (ref) =>
      (text) => SharePlus.instance.share(ShareParams(text: text)),
);

/// Whether sharing features can be used: a cloud build with someone
/// signed in.
final signedInForSharingProvider = Provider<bool>(
  (ref) =>
      ref.watch(cloudConfigProvider).isConfigured &&
      ref.watch(authUserIdProvider).value != null,
);

/// "Sign in to use …" card with a button to My account — Users and
/// Transfer need a cloud account (local-only installs have nothing to
/// share).
class SignInRequiredCard extends StatelessWidget {
  const SignInRequiredCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => context.push('/account'),
              child: const Text('MY ACCOUNT'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grey "nothing to see here" block with an icon.
class SharingEmptyState extends StatelessWidget {
  const SharingEmptyState({super.key, required this.icon, required this.lines});

  final IconData icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: muted),
          for (final line in lines) ...[
            const SizedBox(height: 16),
            Text(
              line,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Label of a permission row (Drivvo's wording).
String accessAreaLabel(AccessArea area) => switch (area) {
  AccessArea.refueling => 'Refueling',
  AccessArea.expense => 'Expense',
  AccessArea.income => 'Income',
  AccessArea.service => 'Service',
  AccessArea.route => 'Route',
  AccessArea.checklist => 'Checklist',
  AccessArea.reminder => 'Reminder',
  AccessArea.reading => 'Reading',
  AccessArea.report => 'Report',
  AccessArea.fuel => 'Fuel',
  AccessArea.gasStation => 'Gas stations',
  AccessArea.place => 'Places',
  AccessArea.expenseType => 'Types of expense',
  AccessArea.serviceType => 'Types of service',
  AccessArea.incomeType => 'Types of income',
  AccessArea.reason => 'Reasons',
  AccessArea.paymentMethod => 'Payment methods',
  AccessArea.vehicles => 'Vehicles',
  AccessArea.users => 'Users',
  AccessArea.profiles => 'Profiles',
  AccessArea.forms => 'Forms',
};

/// Dot color of a permission row: module color, teal for types and
/// categories, grey for administration.
Color accessAreaColor(AccessArea area) {
  switch (area.group) {
    case AccessGroup.modules:
      final module = RecordModule.values
          .where((m) => m.name == area.name)
          .firstOrNull;
      return module?.color ?? AppTheme.primary;
    case AccessGroup.catalogs:
      return AppTheme.primary;
    case AccessGroup.administration:
      return Colors.blueGrey;
  }
}

String accessActionLabel(AccessAction action) => switch (action) {
  AccessAction.view => 'View',
  AccessAction.register => 'Register',
  AccessAction.edit => 'Edit',
  AccessAction.delete => 'Delete',
};

/// The permission area of a record module.
AccessArea areaOfModule(RecordModule module) =>
    AccessArea.values.byName(module.name);

/// Local SQL table of a record module.
String tableOfModule(RecordModule module) => switch (module) {
  RecordModule.refueling => 'refuelings',
  RecordModule.expense ||
  RecordModule.service ||
  RecordModule.income => 'entries',
  RecordModule.route => 'routes',
  RecordModule.reading => 'readings',
  RecordModule.checklist => 'checklists',
  RecordModule.reminder => 'reminders',
};

/// `(vehicle_id, created_by)` of one record, for permission checks.
final recordOwnershipProvider = FutureProvider.autoDispose
    .family<({String vehicleId, String? createdBy})?, (RecordModule, String)>((
      ref,
      key,
    ) async {
      final row = await ref
          .watch(databaseProvider)
          .customSelect(
            'SELECT vehicle_id, created_by FROM ${tableOfModule(key.$1)} '
            'WHERE id = ?',
            variables: [Variable.withString(key.$2)],
          )
          .getSingleOrNull();
      if (row == null) return null;
      return (
        vehicleId: row.read<String>('vehicle_id'),
        createdBy: row.readNullable<String>('created_by'),
      );
    });

/// Whether [action] is allowed on record [id] of [module] (always true in
/// the user's own account; false while the lookup is loading).
bool canActOnRecord(
  WidgetRef ref,
  RecordModule module,
  String id,
  AccessAction action,
) {
  final MemberAccess access = ref.watch(currentAccessProvider);
  if (access.isOwner) return true;
  final info = ref.watch(recordOwnershipProvider((module, id))).value;
  if (info == null) return false;
  return access.canRecord(
    areaOfModule(module),
    action,
    vehicleId: info.vehicleId,
    createdBy: info.createdBy,
  );
}
