import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/theme/app_theme.dart';

/// More → Synchronize data (`/sync`). Three faces, depending on the build and
/// the login: cloud not configured, signed out (sync is optional → "Sign in"),
/// or signed in (last sync, status, "Sync now"). When another account synced
/// on this device before, it asks whether to keep or replace the local data.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    // Already waiting for a decision when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(syncControllerProvider).phase == SyncPhase.needsDecision) {
        _askAccountSwitch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Detected while the screen is open (like a useEffect on status).
    ref.listen(syncControllerProvider, (prev, next) {
      if (next.phase == SyncPhase.needsDecision &&
          prev?.phase != SyncPhase.needsDecision) {
        _askAccountSwitch();
      }
    });
    final status = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Synchronize data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: switch (status.phase) {
          SyncPhase.unavailable => const [
            _Message(
              icon: Icons.cloud_off,
              title: 'Cloud sync is not available',
              text:
                  'Cloud sync isn\'t configured in this build. MotoLog works '
                  'fully offline and your data stays on this device.',
            ),
          ],
          SyncPhase.signedOut => [
            const _Message(
              icon: Icons.cloud_sync,
              title: 'Sync is optional',
              text:
                  'Sign in to back up your data and use it on your other '
                  'devices. Without an account everything keeps working '
                  'offline on this device.',
            ),
            const SizedBox(height: 24),
            _RoundButton(
              label: 'SIGN IN',
              onPressed: () => context.push('/account'),
            ),
          ],
          _ => _signedIn(status),
        },
      ),
    );
  }

  List<Widget> _signedIn(SyncStatus status) {
    final fmt = ref.watch(formattersProvider);
    final last = status.lastSyncedAt;
    final (IconData icon, String label, Color? color) = switch (status.phase) {
      SyncPhase.syncing => (Icons.sync, 'Synchronizing…', null),
      SyncPhase.error => (
        Icons.error_outline,
        'Last sync failed',
        Theme.of(context).colorScheme.error,
      ),
      SyncPhase.needsDecision => (
        Icons.warning_amber,
        'Waiting for your choice',
        Colors.orange.shade800,
      ),
      _ => (Icons.cloud_done, 'Up to date', AppTheme.primary),
    };
    return [
      const _Message(
        icon: Icons.cloud_sync,
        title: 'Your data is synchronized',
        text:
            'Records, vehicles and lists are backed up to your account and '
            'kept in sync on every device where you sign in. Sync runs by '
            'itself; you can also start it here.',
      ),
      const SizedBox(height: 16),
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        subtitle: status.error == null ? null : Text(status.error!),
      ),
      ListTile(
        leading: const Icon(Icons.history),
        title: const Text('Last synchronized'),
        subtitle: Text(
          last == null ? 'Never' : '${fmt.date(last)} ${fmt.time(last)}',
        ),
      ),
      const SizedBox(height: 24),
      if (status.phase == SyncPhase.needsDecision)
        _RoundButton(label: 'CHOOSE WHAT TO DO', onPressed: _askAccountSwitch)
      else
        _RoundButton(
          label: 'SYNC NOW',
          busy: status.isSyncing,
          onPressed: status.isSyncing
              ? null
              : () => ref.read(syncControllerProvider.notifier).syncNow(),
        ),
    ];
  }

  Future<void> _askAccountSwitch() async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    final keep = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Another account used this device'),
        content: const Text(
          'This device was last synchronized with a different account. '
          'Choose what to do with the data on this device.\n\n'
          'Replacing deletes this device\'s records and downloads the '
          'account\'s data instead. Anything not yet synchronized with the '
          'previous account will be lost.',
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("ADD THIS DEVICE'S DATA TO THE ACCOUNT"),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text("REPLACE WITH THE ACCOUNT'S DATA"),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (keep == null || !mounted) return;
    await ref
        .read(syncControllerProvider.notifier)
        .resolveAccountSwitch(keepLocalData: keep);
  }
}

/// Big icon + title + explanation, centred.
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Icon(icon, size: 64, color: AppTheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
      ],
    );
  }
}

/// Teal, rounded, full-width button (the app's SAVE style).
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
      ),
      onPressed: onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}
