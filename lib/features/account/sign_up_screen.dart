import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_widgets.dart';
import 'auth_service.dart';

enum _Step { form, confirmEmail }

/// Create an account with email + password. When the Supabase project
/// requires confirming the email (the usual default), this shows a "confirm
/// your email" state instead of navigating away — the user finishes by
/// opening the link Supabase just emailed, which (with `detectSessionInUri`
/// on web) signs the app in on its own once the link is opened on this
/// device.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Step _step = _Step.form;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final signedInImmediately = await ref
          .read(authServiceProvider)
          .signUp(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      if (signedInImmediately) {
        Navigator.of(context).pop();
      } else {
        setState(() => _step = _Step.confirmEmail);
      }
    } on AuthServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _step == _Step.form ? _formStep() : _confirmEmailStep(),
        ),
      ),
    );
  }

  List<Widget> _formStep() => [
    Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _password,
            validator: (v) =>
                (v == null || v.length < 8) ? 'At least 8 characters' : null,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _confirm,
            label: 'Confirm password',
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
          ),
        ],
      ),
    ),
    AuthErrorText(_error),
    const SizedBox(height: 20),
    AuthPrimaryButton(
      label: 'CREATE ACCOUNT',
      onPressed: _signUp,
      loading: _loading,
    ),
  ];

  List<Widget> _confirmEmailStep() => [
    Icon(
      Icons.mark_email_read_outlined,
      size: 48,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    const SizedBox(height: 16),
    Text(
      'Confirm your email — we sent a link to ${_email.text}. After '
      "confirming you'll be signed in.",
      textAlign: TextAlign.center,
    ),
    AuthErrorText(_error),
    const SizedBox(height: 12),
    ResendEmailButton(
      onResend: () => ref
          .read(authServiceProvider)
          .resendSignUpConfirmation(_email.text.trim()),
    ),
  ];
}
