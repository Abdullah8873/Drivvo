import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_widgets.dart';
import 'auth_service.dart';

enum _Step { email, sent }

/// Forgot password: email → a reset link. Opening the link on this device
/// signs Supabase into a short-lived recovery session and fires
/// `AuthChangeEvent.passwordRecovery`, which `app.dart` listens for (via
/// `passwordRecoveryEventProvider`) to route straight to the "Set new
/// password" screen — so this screen's job ends once the link is sent.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  _Step _step = _Step.email;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .sendPasswordResetLink(_email.text.trim());
      if (mounted) setState(() => _step = _Step.sent);
    } on AuthServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _step == _Step.email ? _emailStep() : _sentStep(),
        ),
      ),
    );
  }

  List<Widget> _emailStep() => [
    Form(
      key: _formKey,
      child: TextFormField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.email_outlined),
        ),
        validator: (v) =>
            (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
      ),
    ),
    AuthErrorText(_error),
    const SizedBox(height: 20),
    AuthPrimaryButton(
      label: 'SEND RESET LINK',
      onPressed: _sendResetLink,
      loading: _loading,
    ),
  ];

  List<Widget> _sentStep() => [
    Icon(
      Icons.mark_email_read_outlined,
      size: 48,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    const SizedBox(height: 16),
    Text(
      'Check your email for a reset link. Open it in this '
      '${kIsWeb ? 'browser' : 'device'} to '
      'choose a new password.',
      textAlign: TextAlign.center,
    ),
    AuthErrorText(_error),
    const SizedBox(height: 12),
    ResendEmailButton(
      onResend: () => ref
          .read(authServiceProvider)
          .sendPasswordResetLink(_email.text.trim()),
    ),
  ];
}
