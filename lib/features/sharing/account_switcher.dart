import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/sharing/active_account.dart';
import '../../core/sharing/sharing_api.dart';
import '../../core/sharing/sharing_controller.dart';

/// Label of an account in the switcher and the vehicle chip.
String accountLabel(Membership? account) =>
    account == null ? 'My data' : "${account.ownerName}'s account";

/// My account → "Account" row: which account this device works on. Only
/// shown once the user belongs to a shared account (or one is active).
class AccountSwitcherTile extends ConsumerWidget {
  const AccountSwitcherTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharing = ref.watch(sharingControllerProvider);
    final active = ref.watch(activeAccountProvider);
    if (sharing.memberships.isEmpty && active == null) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        ListTile(
          key: const Key('account-switcher'),
          leading: const Icon(Icons.swap_horizontal_circle_outlined),
          title: const Text('Account'),
          subtitle: Text(accountLabel(active)),
          trailing: const Icon(Icons.expand_more),
          onTap: () => _pick(context, ref, sharing.memberships, active),
        ),
        if (active != null)
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text('Leave ${accountLabel(active)}'),
            onTap: () => _leave(context, ref, active),
          ),
        const Divider(),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<Membership> memberships,
    Membership? active,
  ) async {
    // A record wrapper so "My data" (null) can be told apart from a
    // dismissed dialog.
    final picked = await showDialog<({Membership? account})>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Work on'),
        children: [
          for (final account in [null, ...memberships])
            ListTile(
              leading: Icon(
                _same(account, active)
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(accountLabel(account)),
              subtitle: account == null ? null : Text(account.profile.name),
              onTap: () => Navigator.pop(ctx, (account: account)),
            ),
        ],
      ),
    );
    if (picked == null || _same(picked.account, active)) return;
    await ref.read(sharingControllerProvider.notifier).switchTo(picked.account);
    if (context.mounted) context.go('/history');
  }

  static bool _same(Membership? a, Membership? b) =>
      a?.ownerId == b?.ownerId && a?.memberId == b?.memberId;

  Future<void> _leave(
    BuildContext context,
    WidgetRef ref,
    Membership active,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave ${accountLabel(active)}?'),
        content: const Text(
          'You lose access to its vehicles and its copy on this device is '
          'removed. Changes not synchronized yet are lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(sharingControllerProvider.notifier).leave(active);
      if (context.mounted) context.go('/history');
    } on SharingException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
