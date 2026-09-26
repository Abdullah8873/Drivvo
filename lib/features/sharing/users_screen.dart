import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/calc/access_profile.dart';
import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/sharing/active_account.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/max_width_body.dart';
import 'sharing_queries.dart';
import 'sharing_widgets.dart';

/// The members of the active account.
final membersProvider = StreamProvider<List<AccountMember>>(
  (ref) => ref.watch(databaseProvider).watchMembers(),
);

/// Custom profiles of the active account.
final customProfilesProvider = StreamProvider<List<AccessProfile>>(
  (ref) => ref.watch(databaseProvider).watchCustomProfiles(),
);

/// Every profile a member can get: built-ins, then custom ones.
final allProfilesProvider = Provider<List<AccessProfile>>(
  (ref) => [
    ...AccessProfile.builtIns,
    ...?ref.watch(customProfilesProvider).value,
  ],
);

/// Display name of a profile id ("Driver", a custom name, or a fallback
/// for a deleted custom profile).
String profileLabelOf(List<AccessProfile> profiles, String id) =>
    profiles.where((p) => p.id == id).firstOrNull?.name ?? 'Custom profile';

/// More → Users: the account owner, then every invited member (name,
/// email, profile), "+" to invite. Verified layout in docs/SPEC.md
/// "Users, Profiles, Transfer"; the invite/edit form is our own design.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInForSharingProvider);
    final access = ref.watch(currentAccessProvider);
    final canInvite =
        signedIn && access.can(AccessArea.users, AccessAction.register);
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: canInvite
          ? FloatingActionButton(
              tooltip: 'Invite',
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/users/new'),
              child: const Icon(Icons.add),
            )
          : null,
      body: !signedIn
          ? const SignInRequiredCard(
              message:
                  'Sign in to invite drivers and managers to your vehicles.',
            )
          : const MaxWidthBody(child: _UsersList()),
    );
  }
}

class _UsersList extends ConsumerWidget {
  const _UsersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider).value ?? const [];
    final profiles = ref.watch(allProfilesProvider);
    final active = ref.watch(activeAccountProvider);
    final access = ref.watch(currentAccessProvider);
    final canEdit = access.can(AccessArea.users, AccessAction.edit);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.group_add, color: AppTheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite drivers and managers',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add their email address and pick a profile. They '
                        'sign in to MotoLog with that address and accept the '
                        'invitation to work on the vehicles you share.',
                        style: TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(
            active == null ? 'You' : active.ownerName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Account owner'),
          trailing: Text(AccessProfile.administrator().name),
        ),
        for (final m in members)
          ListTile(
            leading: CircleAvatar(
              child: Text(
                (m.memberName?.isNotEmpty == true ? m.memberName! : m.email)
                    .substring(0, 1)
                    .toUpperCase(),
              ),
            ),
            title: Text(
              m.memberName?.isNotEmpty == true ? m.memberName! : m.email,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(switch (m.status) {
              MemberStatus.pending => '${m.email} · Invitation pending',
              MemberStatus.declined => '${m.email} · Declined',
              _ => m.email,
            }),
            trailing: Text(profileLabelOf(profiles, m.profileId)),
            onTap: canEdit ? () => context.push('/users/${m.id}') : null,
          ),
      ],
    );
  }
}
