import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_widgets.dart';
import 'auth_service.dart';

enum _Step { email, reset }

/// Forgot password: email → a 6-digit code → new password. Codes (not a
/// deep link) so nothing extra needs configuring on Android — see
/// CLAUDE.md's "Decisions already made".
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();

  _Step _step = _Step.email;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .sendPasswordResetCode(_email.text.trim());
      if (mounted) setState(() => _step = _Step.reset);
    } on AuthServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .resetPasswordWithCode(
            email: _email.text.trim(),
            code: _code.text.trim(),
            newPassword: _newPassword.text,
          );
      if (mounted) Navigator.of(context).pop();
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
          children: _step == _Step.email ? _emailStep() : _resetStep(),
        ),
      ),
    );
  }

  List<Widget> _emailStep() => [
    Form(
      key: _emailFormKey,
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
      label: 'SEND CODE',
      onPressed: _sendCode,
      loading: _loading,
    ),
  ];

  List<Widget> _resetStep() => [
    Text(
      'Enter the code we emailed to ${_email.text} and choose a new '
      'password.',
    ),
    const SizedBox(height: 12),
    Form(
      key: _resetFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Code'),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter the code' : null,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _newPassword,
            label: 'New password',
            validator: (v) =>
                (v == null || v.length < 8) ? 'At least 8 characters' : null,
          ),
        ],
      ),
    ),
    AuthErrorText(_error),
    const SizedBox(height: 8),
    AuthPrimaryButton(
      label: 'RESET PASSWORD',
      onPressed: _resetPassword,
      loading: _loading,
    ),
    ResendCodeButton(
      onResend: () => ref
          .read(authServiceProvider)
          .sendPasswordResetCode(_email.text.trim()),
    ),
  ];
}
