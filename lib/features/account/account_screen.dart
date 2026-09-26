import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/cloud/auth_state.dart';
import '../../core/cloud/cloud_config.dart';
import '../../core/sync/sync_controller.dart';
import '../sharing/account_switcher.dart';
import 'account_widgets.dart';
import 'auth_service.dart';

/// Field lengths the server accepts (`profiles_field_lengths` in
/// `supabase/migrations/20260928000001_security_hardening.sql`): your name
/// is shown to the people you invite, so it stays a name.
const _nameMax = 100;
const _licenseMax = 50;

/// More → My account. Cloud login is optional (see CLAUDE.md): offline
/// users never need this screen. Branches like a React page reading
/// `useAuth().user` — signed out shows a pitch + sign-in/sign-up, signed in
/// shows Drivvo's profile fields plus sign-out/delete.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(cloudConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My account')),
      body: !config.isConfigured
          ? const _NotConfigured()
          : ref
                .watch(authUserIdProvider)
                .when(
                  data: (userId) => userId == null
                      ? const _SignedOutView()
                      : _SignedInView(key: ValueKey(userId)),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const _SignedOutView(),
                ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          'Cloud features are not configured in this build. The app works '
          'fully offline; sign-in will be available once Supabase is set '
          'up for MotoLog.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          const Text(
            'Optional. Sign in to back up and sync your data across '
            'devices. The app works fully without an account.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'SIGN IN',
            onPressed: () => context.push('/account/sign-in'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            onPressed: () => context.push('/account/sign-up'),
            child: const Text('CREATE ACCOUNT'),
          ),
        ],
      ),
    );
  }
}

/// The signed-in profile form: loads `AccountProfile` once, edits it
/// locally, and saves it back on SAVE — like a small controlled form bound
/// to a fetched record on the web.
class _SignedInView extends ConsumerStatefulWidget {
  const _SignedInView({super.key});

  @override
  ConsumerState<_SignedInView> createState() => _SignedInViewState();
}

class _SignedInViewState extends ConsumerState<_SignedInView> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _licenseNumber = TextEditingController();
  final _licenseCategory = TextEditingController();
  DateTime? _licenseExpiry;
  String _email = '';

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ref.read(authServiceProvider).loadProfile();
      if (!mounted) return;
      setState(() {
        _firstName.text = profile.firstName;
        _lastName.text = profile.lastName;
        _licenseNumber.text = profile.licenseNumber;
        _licenseCategory.text = profile.licenseCategory;
        _licenseExpiry = profile.licenseExpiry;
        _email = profile.email;
        _loading = false;
      });
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _licenseNumber.dispose();
    _licenseCategory.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .saveProfile(
            AccountProfile(
              firstName: _firstName.text.trim(),
              lastName: _lastName.text.trim(),
              email: _email,
              licenseNumber: _licenseNumber.text.trim(),
              licenseCategory: _licenseCategory.text.trim(),
              licenseExpiry: _licenseExpiry,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } on AuthServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiry ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) setState(() => _licenseExpiry = picked);
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your data on this device stays right where it is.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authServiceProvider).signOut();
  }

  Future<void> _confirmDeleteAccount() async {
    final typed = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Delete account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This erases your cloud account and backup. Data already on '
                'this device is not touched. Type DELETE to confirm.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typed,
                decoration: const InputDecoration(labelText: 'Type DELETE'),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: typed.text == 'DELETE'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('DELETE ACCOUNT'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    // Attachment files first: Supabase won't let the account deletion
    // (SQL) remove Storage objects, so they'd be orphaned in the bucket.
    final userId = ref.read(authUserIdProvider).value;
    final files = ref.read(remoteFileStoreProvider);
    if (userId != null && files != null) {
      try {
        await files.removeAllForUser(userId);
      } catch (_) {
        if (mounted) {
          setState(
            () => _error =
                "Couldn't delete your attached files. Check your internet "
                'connection and try again.',
          );
        }
        return;
      }
    }
    try {
      final auth = ref.read(authServiceProvider);
      await auth.deleteAccount();
      await auth.signOut();
    } on AuthServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Own data / shared accounts (only once the user joined one).
        const AccountSwitcherTile(),
        TextFormField(
          controller: _firstName,
          inputFormatters: [LengthLimitingTextInputFormatter(_nameMax)],
          decoration: const InputDecoration(
            labelText: 'First name',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _lastName,
          inputFormatters: [LengthLimitingTextInputFormatter(_nameMax)],
          decoration: const InputDecoration(
            labelText: 'Last name',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _email,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _licenseNumber,
          inputFormatters: [LengthLimitingTextInputFormatter(_licenseMax)],
          decoration: const InputDecoration(
            labelText: "Driver's license number",
            prefixIcon: Icon(Icons.credit_card),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _licenseCategory,
          inputFormatters: [LengthLimitingTextInputFormatter(_licenseMax)],
          decoration: const InputDecoration(
            labelText: 'License category',
            prefixIcon: Icon(Icons.category_outlined),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickExpiry,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'License expiry',
              prefixIcon: Icon(Icons.event_outlined),
            ),
            child: Text(
              _licenseExpiry == null
                  ? ''
                  : DateFormat.yMMMd().format(_licenseExpiry!),
            ),
          ),
        ),
        AuthErrorText(_error),
        const SizedBox(height: 20),
        AuthPrimaryButton(label: 'SAVE', onPressed: _save, loading: _saving),
        const SizedBox(height: 24),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: _confirmSignOut,
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Delete account',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: _confirmDeleteAccount,
        ),
      ],
    );
  }
}
