import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/calc/transfer_code.dart';
import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/sharing/active_account.dart';
import '../../core/sharing/sharing_api.dart';
import '../../core/sharing/sharing_controller.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/max_width_body.dart';
import 'sharing_widgets.dart';

/// The transfer codes the signed-in user generated.
final myTransfersProvider = FutureProvider.autoDispose<List<TransferInfo>>((
  ref,
) async {
  final api = ref.watch(sharingApiProvider);
  if (api == null) return const [];
  return api.myTransfers();
});

/// More → Transfer: send a **copy** of a vehicle's history to its buyer
/// (generate a code), or receive one from the seller (redeem a code).
/// The seller keeps their own history. Flow designed in docs/SHARING.md.
class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInForSharingProvider);
    final shared = ref.watch(activeAccountProvider) != null;
    final ready = signedIn && !shared;
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer')),
      floatingActionButton: ready
          ? FloatingActionButton(
              tooltip: 'Transfer',
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              onPressed: () => _openMenu(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: !signedIn
          ? const SignInRequiredCard(
              message: 'Sign in to send or receive a vehicle history.',
            )
          : shared
          ? const SharingEmptyState(
              icon: Icons.swap_horiz,
              lines: [
                'Transfer works with your own vehicles. Switch to "My data" '
                    'in More → My account to use it.',
              ],
            )
          : const MaxWidthBody(child: _TransferList()),
    );
  }

  static Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text('Generate transfer code'),
              onTap: () => Navigator.pop(ctx, 'generate'),
            ),
            ListTile(
              leading: const Icon(Icons.input),
              title: const Text('Redeem transfer code'),
              onTap: () => Navigator.pop(ctx, 'redeem'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'generate':
        await _generate(context, ref);
      case 'redeem':
        await _redeem(context, ref);
    }
  }

  static Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final vehicles = ref.read(vehiclesProvider).value ?? const <Vehicle>[];
    if (vehicles.isEmpty) {
      _snack(context, 'Add a vehicle first.');
      return;
    }
    final vehicle = await showModalBottomSheet<Vehicle>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Which vehicle did you sell?')),
            for (final v in vehicles)
              ListTile(
                leading: const Icon(Icons.directions_car),
                title: Text(v.name),
                onTap: () => Navigator.pop(ctx, v),
              ),
          ],
        ),
      ),
    );
    if (vehicle == null || !context.mounted) return;
    final api = ref.read(sharingApiProvider)!;
    try {
      // The server copies from the cloud: upload local changes first.
      await ref.read(syncControllerProvider.notifier).syncNow();
      final info = await api.createTransfer(vehicle.id);
      ref.invalidate(myTransfersProvider);
      if (context.mounted) await _showCode(context, ref, info);
    } on SharingException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  static Future<void> _showCode(
    BuildContext context,
    WidgetRef ref,
    TransferInfo info,
  ) {
    final expires = DateFormat.yMMMd().format(info.expiresAt);
    final text =
        'Use this code in MotoLog (More → Transfer → Redeem transfer code) '
        'to receive the history of ${info.vehicleName}: ${info.displayCode} '
        '(valid until $expires).';
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              info.displayCode,
              key: const Key('transfer-code'),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Give this code to the buyer of ${info.vehicleName}. It can be '
              'used once, until $expires. You keep your own history.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: info.displayCode)),
            child: const Text('COPY'),
          ),
          TextButton(
            onPressed: () => ref.read(textSharerProvider)(text),
            child: const Text('SHARE'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }

  static Future<void> _redeem(BuildContext context, WidgetRef ref) async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => const _RedeemDialog(),
    );
    if (code == null || !context.mounted) return;
    final normalized = TransferCode.normalize(code);
    if (!TransferCode.isValid(normalized)) {
      _snack(context, 'A code has 8 letters and digits, like K7QM-3XPD.');
      return;
    }
    try {
      final result = await ref
          .read(sharingApiProvider)!
          .redeemTransfer(normalized);
      if (context.mounted) {
        _snack(
          context,
          '${result.vehicleName} received. Its history is downloading.',
        );
      }
      await ref.read(syncControllerProvider.notifier).syncNow();
    } on SharingException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  static void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}

/// Asks for the seller's code. Owns its text controller, so it is only
/// disposed once the dialog has finished animating out.
class _RedeemDialog extends StatefulWidget {
  const _RedeemDialog();

  @override
  State<_RedeemDialog> createState() => _RedeemDialogState();
}

class _RedeemDialogState extends State<_RedeemDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Redeem transfer code'),
      content: TextField(
        key: const Key('redeem-code'),
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Code from the seller',
          hintText: 'K7QM-3XPD',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('REDEEM'),
        ),
      ],
    );
  }
}

class _TransferList extends ConsumerWidget {
  const _TransferList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(myTransfersProvider);
    return transfers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => SharingEmptyState(
        icon: Icons.cloud_off,
        lines: [e is SharingException ? e.message : "Couldn't load codes."],
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: SingleChildScrollView(
              child: SharingEmptyState(
                icon: Icons.published_with_changes,
                lines: [
                  'Did you sell your vehicle? Send a copy of the history to '
                      'the buyer!',
                  "Did you buy a new vehicle? Receive a copy of the vehicle's "
                      'history from the seller!',
                ],
              ),
            ),
          );
        }
        final now = DateTime.now();
        final fmt = DateFormat.yMMMd();
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final t in list)
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: Text(
                  t.displayCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                subtitle: Text(
                  '${t.vehicleName} · ${switch (t.statusAt(now)) {
                    TransferStatus.pending => 'valid until ${fmt.format(t.expiresAt)}',
                    TransferStatus.redeemed => 'redeemed ${fmt.format(t.redeemedAt!)}',
                    TransferStatus.expired => 'expired',
                    TransferStatus.cancelled => 'cancelled',
                  }}',
                ),
                trailing: t.statusAt(now) == TransferStatus.pending
                    ? IconButton(
                        tooltip: 'Cancel code',
                        icon: const Icon(Icons.close),
                        onPressed: () => _cancel(context, ref, t),
                      )
                    : null,
                onTap: t.statusAt(now) == TransferStatus.pending
                    ? () => TransferScreen._showCode(context, ref, t)
                    : null,
              ),
          ],
        );
      },
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    TransferInfo t,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel ${t.displayCode}?'),
        content: const Text('The buyer will no longer be able to use it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('KEEP'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CANCEL CODE'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(sharingApiProvider)!.cancelTransfer(t.code);
      ref.invalidate(myTransfersProvider);
    } on SharingException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
