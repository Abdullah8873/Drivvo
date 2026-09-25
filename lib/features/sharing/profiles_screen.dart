import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/calc/access_profile.dart';
import '../../core/sharing/active_account.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/max_width_body.dart';
import 'users_screen.dart';

/// More → Profiles: the fixed built-in profiles (Administrator, Manager,
/// Driver) and the account's custom ones, "+" to add one (docs/SPEC.md
/// "Users, Profiles, Transfer").
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = ref.watch(customProfilesProvider).value ?? const [];
    final canAdd = ref
        .watch(currentAccessProvider)
        .can(AccessArea.profiles, AccessAction.register);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              tooltip: 'Add profile',
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/profiles/new'),
              child: const Icon(Icons.add),
            )
          : null,
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            const _Header('Built-in profiles'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Icon(Icons.lock_outline, color: muted),
                title: Text(
                  'Built-in profiles are fixed and can\'t be edited.',
                  style: TextStyle(color: muted),
                ),
              ),
            ),
            for (final p in AccessProfile.builtIns)
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(p.name),
                subtitle: Text(_summary(p)),
                onTap: () => context.push('/profiles/${p.id}'),
              ),
            const Divider(),
            const _Header('Custom profiles'),
            if (custom.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  canAdd
                      ? 'Add your first profile with the + button.'
                      : 'No custom profiles.',
                  style: TextStyle(color: muted),
                ),
              ),
            for (final p in custom)
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(p.name),
                subtitle: Text(_summary(p)),
                onTap: () => context.push('/profiles/${p.id}'),
              ),
          ],
        ),
      ),
    );
  }

  static String _summary(AccessProfile p) => [
    p.vehicleScope == VehicleScope.all ? 'All vehicles' : 'Assigned vehicles',
    p.recordScope == RecordScope.all ? 'all records' : 'own records',
  ].join(' · ');
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.primary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    ),
  );
}
