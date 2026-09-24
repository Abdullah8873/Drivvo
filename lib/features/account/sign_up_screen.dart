import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_widgets.dart';
import 'auth_service.dart';

enum _Step { form, code }

/// Create an account with email + password. When the Supabase project
/// requires confirming the email (the usual default), this shows a 6-digit
/// code step (`verifyOTP(type: OtpType.signup)`) instead of relying on a
/// deep link, so there's nothing extra to configure on Android.
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
  final _code = TextEditingController();

  _Step _step = _Step.form;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
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
        setState(() => _step = _Step.code);
      }
    } on AuthServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .verifyEmailCode(
            email: _email.text.trim(),
            code: _code.text.trim(),
            signUpConfirmation: true,
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
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _step == _Step.form ? _formStep() : _codeStep(),
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

  List<Widget> _codeStep() => [
    Text(
      'Enter the 6-digit code we emailed to ${_email.text} to confirm your '
      'account.',
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _code,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: const InputDecoration(labelText: 'Code'),
    ),
    AuthErrorText(_error),
    const SizedBox(height: 8),
    AuthPrimaryButton(
      label: 'CONFIRM',
      onPressed: _verifyCode,
      loading: _loading,
    ),
    ResendCodeButton(
      onResend: () async {
        // Supabase resends the confirmation email when signUp is called
        // again for the same unconfirmed address.
        await ref
            .read(authServiceProvider)
            .signUp(email: _email.text.trim(), password: _password.text);
      },
    ),
  ];
}
