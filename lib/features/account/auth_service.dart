import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cloud/cloud_config.dart';

/// Drivvo's "My account" fields, stored server-side in `public.profiles`
/// (see `supabase/migrations/20260924000002_account.sql`). [email] always
/// comes from the auth user, never from the profile row, so it can't drift.
class AccountProfile {
  const AccountProfile({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.licenseNumber = '',
    this.licenseCategory = '',
    this.licenseExpiry,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String licenseNumber;
  final String licenseCategory;
  final DateTime? licenseExpiry;

  AccountProfile copyWith({
    String? firstName,
    String? lastName,
    String? licenseNumber,
    String? licenseCategory,
    DateTime? licenseExpiry,
  }) => AccountProfile(
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email,
    licenseNumber: licenseNumber ?? this.licenseNumber,
    licenseCategory: licenseCategory ?? this.licenseCategory,
    licenseExpiry: licenseExpiry ?? this.licenseExpiry,
  );
}

/// A short, user-facing message an account screen can show directly (under
/// a form or in a SnackBar) — the Flutter equivalent of throwing an `Error`
/// with a friendly `.message` from an API client. Never wraps a raw
/// Supabase/Postgres error string.
class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Every cloud-account operation the login/account screens need, behind one
/// interface — like a small `AuthProvider`/API-client class on the web.
/// [SupabaseAuthService] is the real implementation; [FakeAuthService]
/// (see `fake_auth_service.dart`) drives widget tests with no network calls.
/// Screens never talk to Supabase directly.
abstract class AuthService {
  /// Creates an account. Returns true when a session was created
  /// immediately (no email confirmation required by the project), false
  /// when the caller must confirm via [verifyEmailCode] with
  /// `signUpConfirmation: true`.
  Future<bool> signUp({required String email, required String password});

  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  /// Emails a 6-digit one-time code for passwordless sign-in.
  Future<void> sendEmailCode(String email);

  /// Verifies a code from [sendEmailCode] (or, with `signUpConfirmation:
  /// true`, the confirmation code from [signUp]) and completes sign-in.
  Future<void> verifyEmailCode({
    required String email,
    required String code,
    bool signUpConfirmation = false,
  });

  /// Emails a 6-digit code for the "forgot password" flow.
  Future<void> sendPasswordResetCode(String email);

  /// Verifies the code from [sendPasswordResetCode] and sets [newPassword]
  /// in one step.
  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Web: opens Google's OAuth redirect. Android/other native platforms:
  /// uses `google_sign_in` to get an ID token, then hands it to Supabase.
  /// Completes without error (and without signing in) if the user cancels.
  Future<void> signInWithGoogle();

  Future<void> signOut();

  /// Erases the user's cloud account (calls the `delete_my_account` RPC —
  /// see the migration). Local, on-device data is untouched.
  Future<void> deleteAccount();

  /// Throws [AuthServiceException] when nobody is signed in.
  Future<AccountProfile> loadProfile();

  Future<void> saveProfile(AccountProfile profile);
}

/// The active [AuthService]. Only ever read once `cloudConfigProvider` says
/// the build is configured — screens reached when it isn't never touch this
/// (see `AccountScreen`). Tests override it with `FakeAuthService`.
final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    throw StateError(
      'authServiceProvider read without cloud config — screens must check '
      'cloudConfigProvider.isConfigured first.',
    );
  }
  return SupabaseAuthService(client, ref.watch(cloudConfigProvider));
});

/// Real [AuthService] backed by Supabase auth (+ Postgres for the profile
/// row) and, on non-web platforms, native Google sign-in.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client, this._config);

  final SupabaseClient _client;
  final CloudConfig _config;

  GoTrueClient get _auth => _client.auth;

  @override
  Future<bool> signUp({required String email, required String password}) =>
      _guard(() async {
        final res = await _auth.signUp(email: email, password: password);
        return res.session != null;
      });

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) =>
      _guard(() => _auth.signInWithPassword(email: email, password: password));

  @override
  Future<void> sendEmailCode(String email) =>
      _guard(() => _auth.signInWithOtp(email: email));

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
    bool signUpConfirmation = false,
  }) => _guard(
    () => _auth.verifyOTP(
      email: email,
      token: code,
      type: signUpConfirmation ? OtpType.signup : OtpType.email,
    ),
  );

  @override
  Future<void> sendPasswordResetCode(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email));

  @override
  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) => _guard(() async {
    await _auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
    await _auth.updateUser(UserAttributes(password: newPassword));
  });

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    if (kIsWeb) {
      await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
      return;
    }
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: _config.googleWebClientId);
    final GoogleSignInAccount account;
    try {
      account = await googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      // The user backed out of the picker — not an error worth surfacing.
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthServiceException(
        'Google did not return a sign-in token. Please try again.',
      );
    }
    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  });

  @override
  Future<void> signOut() => _guard(() => _auth.signOut());

  @override
  Future<void> deleteAccount() =>
      _guard(() => _client.rpc('delete_my_account'));

  @override
  Future<AccountProfile> loadProfile() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException('Not signed in.');
    }
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    final expiry = row?['license_expiry'] as String?;
    return AccountProfile(
      firstName: row?['first_name'] as String? ?? '',
      lastName: row?['last_name'] as String? ?? '',
      email: user.email ?? '',
      licenseNumber: row?['license_number'] as String? ?? '',
      licenseCategory: row?['license_category'] as String? ?? '',
      licenseExpiry: expiry == null ? null : DateTime.parse(expiry),
    );
  });

  @override
  Future<void> saveProfile(AccountProfile profile) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException('Not signed in.');
    }
    await _client.from('profiles').upsert({
      'id': user.id,
      'first_name': profile.firstName,
      'last_name': profile.lastName,
      'license_number': profile.licenseNumber,
      'license_category': profile.licenseCategory,
      'license_expiry': profile.licenseExpiry
          ?.toIso8601String()
          .split('T')
          .first,
      'updated_at': DateTime.now().toIso8601String(),
    });
  });

  /// Runs [action], turning Supabase/Google/network failures into a short
  /// [AuthServiceException] the UI can show as-is.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthServiceException {
      rethrow;
    } on AuthException catch (e) {
      throw AuthServiceException(_friendlyAuthMessage(e));
    } on GoogleSignInException catch (e) {
      throw AuthServiceException(
        e.description ?? 'Google sign-in failed. Please try again.',
      );
    } on PostgrestException catch (e) {
      throw AuthServiceException(e.message);
    } catch (_) {
      throw const AuthServiceException(
        'Something went wrong. Check your internet connection and try '
        'again.',
      );
    }
  }
}

/// Maps Supabase's `AuthException.code` to a short sentence a form or
/// SnackBar can show directly. Full list of codes:
/// https://supabase.com/docs/guides/auth/debugging/error-codes
String _friendlyAuthMessage(AuthException e) {
  switch (e.code) {
    case 'invalid_credentials':
      return 'Wrong email or password.';
    case 'email_not_confirmed':
      return 'Please confirm your email before signing in.';
    case 'user_already_exists':
    case 'email_exists':
      return 'An account with this email already exists.';
    case 'weak_password':
      return 'Password is too weak — use at least 8 characters.';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
    case 'over_sms_send_rate_limit':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'otp_expired':
      return 'This code has expired or is invalid. Request a new one.';
    case 'same_password':
      return 'New password must be different from the old one.';
    case 'user_not_found':
      return 'No account found with this email.';
    case 'signup_disabled':
      return 'Sign-up is currently disabled.';
    default:
      return e.message;
  }
}
