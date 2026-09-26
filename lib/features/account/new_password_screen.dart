import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'account_widgets.dart';
import 'auth_service.dart';

/// Set a new password after opening a password-reset email link. Reached
/// only via `app.dart`'s app-wide listener on `passwordRecoveryEventProvider`
/// (never linked to directly), since Supabase has already put the user in a
/// short-lived recovery session by the time this screen shows — there's no
/// old password to check, the opened link is the proof of identity.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).updatePassword(_password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password updated')));
      context.go('/account');
    } on AuthServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set new password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  PasswordField(
                    controller: _password,
                    label: 'New password',
                    validator: (v) => (v == null || v.length < 8)
                        ? 'At least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _confirm,
                    label: 'Confirm new password',
                    validator: (v) =>
                        v != _password.text ? 'Passwords do not match' : null,
                  ),
                ],
              ),
            ),
            AuthErrorText(_error),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'UPDATE PASSWORD',
              onPressed: _submit,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
