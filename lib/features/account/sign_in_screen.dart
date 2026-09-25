import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/cloud/cloud_config.dart';
import 'account_widgets.dart';
import 'auth_service.dart';

enum _Step { credentials, linkSent }

/// Sign in with Google, password, or an emailed sign-in link. Pushed from
/// `AccountScreen`'s "Sign in" button; pops itself on success, and the
/// account screen — watching `authUserIdProvider` — updates on its own,
/// the way a React page re-renders when an auth context changes.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  _Step _step = _Step.credentials;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Runs [action]; on success pops this screen when [popOnSuccess], shows
  /// [_error] under the form otherwise. Shared by every button here so each
  /// only has to describe *what* it calls.
  Future<void> _run(
    Future<void> Function() action, {
    bool popOnSuccess = false,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (popOnSuccess && mounted) Navigator.of(context).pop();
    } on AuthServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithPassword() {
    if (!(_formKey.currentState?.validate() ?? false)) return Future.value();
    return _run(
      () => ref
          .read(authServiceProvider)
          .signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          ),
      popOnSuccess: true,
    );
  }

  Future<void> _sendSignInLink() {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email first.');
      return Future.value();
    }
    return _run(() async {
      await ref.read(authServiceProvider).sendSignInLink(_email.text.trim());
      if (mounted) setState(() => _step = _Step.linkSent);
    });
  }

  Future<void> _signInWithGoogle() => _run(
    () => ref.read(authServiceProvider).signInWithGoogle(),
    popOnSuccess: true,
  );

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(cloudConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (config.hasGoogle) ...[
              GoogleSignInButton(
                onPressed: _signInWithGoogle,
                loading: _loading,
              ),
              const SizedBox(height: 16),
              const OrDivider(),
              const SizedBox(height: 16),
            ],
            if (_step == _Step.credentials)
              ..._credentialsStep()
            else
              ..._linkSentStep(),
          ],
        ),
      ),
    );
  }

  List<Widget> _credentialsStep() => [
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
                (v == null || v.isEmpty) ? 'Enter your password' : null,
          ),
        ],
      ),
    ),
    AuthErrorText(_error),
    const SizedBox(height: 20),
    AuthPrimaryButton(
      label: 'SIGN IN',
      onPressed: _signInWithPassword,
      loading: _loading,
    ),
    const SizedBox(height: 8),
    TextButton(
      onPressed: _loading ? null : _sendSignInLink,
      child: const Text('Email me a sign-in link'),
    ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: _loading
            ? null
            : () => context.push('/account/reset-password'),
        child: const Text('Forgot password?'),
      ),
    ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: _loading ? null : () => context.push('/account/sign-up'),
        child: const Text('Create account'),
      ),
    ),
  ];

  List<Widget> _linkSentStep() => [
    Icon(
      Icons.mark_email_read_outlined,
      size: 48,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    const SizedBox(height: 16),
    Text(
      'Check your email — we sent a sign-in link to ${_email.text}. Open '
      'it on this device.',
      textAlign: TextAlign.center,
    ),
    AuthErrorText(_error),
    const SizedBox(height: 12),
    ResendEmailButton(
      onResend: () =>
          ref.read(authServiceProvider).sendSignInLink(_email.text.trim()),
    ),
    TextButton(
      onPressed: () => setState(() {
        _step = _Step.credentials;
        _error = null;
      }),
      child: const Text('Use a different email'),
    ),
  ];
}
