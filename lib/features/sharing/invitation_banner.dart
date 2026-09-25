import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/sharing/sharing_api.dart';
import '../../core/sharing/sharing_controller.dart';
import '../../core/theme/app_theme.dart';

/// "`<Owner>` invited you to their account as Driver — DECLINE / ACCEPT",
/// shown above the bottom bar while an invitation waits for an answer
/// (the server matches invitations to the signed-in user's verified
/// email; nothing is emailed).
class InvitationBanner extends ConsumerStatefulWidget {
  const InvitationBanner({super.key});

  @override
  ConsumerState<InvitationBanner> createState() => _InvitationBannerState();
}

class _InvitationBannerState extends ConsumerState<InvitationBanner> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } on SharingException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(Invitation inv) => _run(() async {
    final controller = ref.read(sharingControllerProvider.notifier);
    final joined = await controller.accept(inv);
    if (joined == null || !mounted) return;
    final switchNow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Open ${inv.ownerName}'s account?"),
        content: const Text(
          'You can switch between your data and shared accounts any time '
          'in More → My account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('LATER'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OPEN'),
          ),
        ],
      ),
    );
    if (switchNow == true) {
      await controller.switchTo(joined);
      if (mounted) context.go('/history');
    }
  });

  @override
  Widget build(BuildContext context) {
    final invitations = ref.watch(
      sharingControllerProvider.select((s) => s.invitations),
    );
    if (invitations.isEmpty) return const SizedBox.shrink();
    final inv = invitations.first;
    return Material(
      key: const Key('invitation-banner'),
      color: AppTheme.primary.withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_add, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${inv.ownerName} invited you to their account as '
                      '${inv.profileName}.',
                    ),
                  ),
                ],
              ),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => ref
                                .read(sharingControllerProvider.notifier)
                                .decline(inv),
                          ),
                    child: const Text('DECLINE'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _accept(inv),
                    child: const Text('ACCEPT'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
