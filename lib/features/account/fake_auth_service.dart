import 'dart:async';

import 'auth_service.dart';

/// In-memory [AuthService] for widget tests — no network, no Supabase
/// project needed. Override `authServiceProvider` with an instance of this
/// (like swapping in a mock `fetch` for an API client on the web).
///
/// Every real flow now sends an email *link* rather than a code, so there is
/// nothing for a test to "type back in". Instead this fake just records the
/// email each `send*`/`resend*` call was given (`lastSignInLinkEmail` etc.)
/// so a test can assert the right call happened, and exposes
/// [firePasswordRecovery] to simulate the app being opened from a
/// password-reset link.
class FakeAuthService implements AuthService {
  FakeAuthService({
    Map<String, String>? passwordsByEmail,
    this.profile = const AccountProfile(),
    this.requireSignUpConfirmation = false,
    this.failNextGoogleSignIn = false,
  }) : _passwords = {...?passwordsByEmail};

  final Map<String, String> _passwords;

  /// The signed-in user's profile, as [loadProfile]/[saveProfile] see it.
  AccountProfile profile;

  /// When true, [signUp] never signs in immediately — tests must simulate
  /// the confirmation link separately, like a project with "confirm email"
  /// on and no way to fake clicking the link.
  final bool requireSignUpConfirmation;

  /// Consumed by the next [signInWithGoogle] call: throws once, then clears
  /// itself so later calls succeed.
  bool failNextGoogleSignIn;

  bool signedIn = false;
  String? lastSignedInEmail;
  bool signOutCalled = false;
  bool deleteAccountCalled = false;

  /// The email each of these calls was most recently given — what a test
  /// checks instead of reading a real inbox.
  String? lastSignInLinkEmail;
  String? lastResendConfirmationEmail;
  String? lastPasswordResetEmail;
  String? lastUpdatedPassword;

  final StreamController<DateTime> _passwordRecoveryController =
      StreamController<DateTime>.broadcast();

  /// Feeds `passwordRecoveryEventProvider` in tests (see
  /// `account_test_utils.dart`'s `accountTestApp`).
  Stream<DateTime> get passwordRecoveryEvents =>
      _passwordRecoveryController.stream;

  /// Simulates the app being reopened from a password-reset email link.
  void firePasswordRecovery() =>
      _passwordRecoveryController.add(DateTime.now());

  /// Releases the stream controller — call from a test's `tearDown` if it
  /// created a [FakeAuthService] directly (not required, since a leaked
  /// broadcast controller leaves no pending timer).
  void dispose() => _passwordRecoveryController.close();

  @override
  Future<bool> signUp({required String email, required String password}) async {
    if (_passwords.containsKey(email)) {
      throw const AuthServiceException(
        'An account with this email already exists.',
      );
    }
    _passwords[email] = password;
    profile = AccountProfile(email: email);
    if (requireSignUpConfirmation) return false;
    signedIn = true;
    lastSignedInEmail = email;
    return true;
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (_passwords[email] != password) {
      throw const AuthServiceException('Wrong email or password.');
    }
    signedIn = true;
    lastSignedInEmail = email;
    if (profile.email != email) profile = AccountProfile(email: email);
  }

  @override
  Future<void> sendSignInLink(String email) async {
    lastSignInLinkEmail = email;
  }

  @override
  Future<void> resendSignUpConfirmation(String email) async {
    lastResendConfirmationEmail = email;
  }

  @override
  Future<void> sendPasswordResetLink(String email) async {
    lastPasswordResetEmail = email;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    lastUpdatedPassword = newPassword;
    final email = lastSignedInEmail;
    if (email != null) _passwords[email] = newPassword;
  }

  @override
  Future<void> signInWithGoogle() async {
    if (failNextGoogleSignIn) {
      failNextGoogleSignIn = false;
      throw const AuthServiceException(
        'Google sign-in failed. Please try again.',
      );
    }
    signedIn = true;
    lastSignedInEmail ??= 'google-user@example.com';
    if (profile.email.isEmpty) {
      profile = AccountProfile(email: lastSignedInEmail!);
    }
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    signedIn = false;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalled = true;
    signedIn = false;
  }

  @override
  Future<AccountProfile> loadProfile() async {
    if (!signedIn) {
      throw const AuthServiceException('Not signed in.');
    }
    return profile;
  }

  @override
  Future<void> saveProfile(AccountProfile newProfile) async {
    profile = newProfile;
  }
}
