import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Full-width rounded teal button used by every account screen (matches
/// `ModuleFormScaffold`'s SAVE button). Shows a spinner in place of the
/// label while [loading] — the equivalent of a disabled submit button with
/// a spinner on a web form.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primary,
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
      ),
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label, style: const TextStyle(letterSpacing: 1)),
    );
  }
}

/// Red error text shown under a form after a failed submit. Renders nothing
/// when [message] is null, so it can sit in the layout unconditionally.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        m,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

/// "Continue with Google" button. Uses a plain Material icon (never Google's
/// own logo/asset) as a stand-in glyph — see CLAUDE.md's rule against
/// reusing another product's branding.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        side: BorderSide(color: Colors.grey.shade400),
        foregroundColor: Colors.black87,
      ),
      icon: loading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.g_mobiledata, size: 28),
      label: const Text('Continue with Google'),
    );
  }
}

/// A password `TextFormField` with a show/hide toggle — reused by sign-in,
/// sign-up and reset-password.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// "Resend email" link with a 60-second cooldown (configurable), so a
/// "check your email" screen can't spam the email provider. Starts counting
/// down as soon as it's shown, since a link was just sent to land on this
/// screen.
class ResendEmailButton extends StatefulWidget {
  const ResendEmailButton({
    super.key,
    required this.onResend,
    this.cooldown = const Duration(seconds: 60),
  });

  final Future<void> Function() onResend;
  final Duration cooldown;

  @override
  State<ResendEmailButton> createState() => _ResendEmailButtonState();
}

class _ResendEmailButtonState extends State<ResendEmailButton> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    setState(() => _secondsLeft = widget.cooldown.inSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    await widget.onResend();
    if (mounted) _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _secondsLeft <= 0;
    return TextButton(
      onPressed: ready ? _resend : null,
      child: Text(ready ? 'Resend email' : 'Resend email (${_secondsLeft}s)'),
    );
  }
}

/// "── or ──" row between the Google button and the email form.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('or', style: TextStyle(color: Colors.grey.shade600)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
