import 'auth_service.dart';

/// In-memory [AuthService] for widget tests — no network, no Supabase
/// project needed. Override `authServiceProvider` with an instance of this
/// (like swapping in a mock `fetch` for an API client on the web).
///
/// The fixed 6-digit [code] stands in for whatever a real email would
/// contain; tests type it directly instead of reading an inbox.
class FakeAuthService implements AuthService {
  FakeAuthService({
    Map<String, String>? passwordsByEmail,
    this.profile = const AccountProfile(),
    this.code = '123456',
    this.requireSignUpConfirmation = false,
    this.failNextGoogleSignIn = false,
  }) : _passwords = {...?passwordsByEmail};

  final Map<String, String> _passwords;

  /// The signed-in user's profile, as [loadProfile]/[saveProfile] see it.
  AccountProfile profile;

  /// The code every `send*Code` call "sends" — [verifyEmailCode] and
  /// [resetPasswordWithCode] only succeed when given this value.
  final String code;

  /// When true, [signUp] never signs in immediately — tests must go through
  /// the code-confirmation step, like a project with "confirm email" on.
  final bool requireSignUpConfirmation;

  /// Consumed by the next [signInWithGoogle] call: throws once, then clears
  /// itself so later calls succeed.
  bool failNextGoogleSignIn;

  String? _pendingCodeEmail;
  bool signedIn = false;
  String? lastSignedInEmail;
  bool signOutCalled = false;
  bool deleteAccountCalled = false;

  @override
  Future<bool> signUp({required String email, required String password}) async {
    if (_passwords.containsKey(email)) {
      throw const AuthServiceException(
        'An account with this email already exists.',
      );
    }
    _passwords[email] = password;
    profile = AccountProfile(email: email);
    if (requireSignUpConfirmation) {
      _pendingCodeEmail = email;
      return false;
    }
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
  Future<void> sendEmailCode(String email) async {
    _pendingCodeEmail = email;
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
    bool signUpConfirmation = false,
  }) async {
    if (_pendingCodeEmail != email || code != this.code) {
      throw const AuthServiceException(
        'This code has expired or is invalid. Request a new one.',
      );
    }
    _pendingCodeEmail = null;
    signedIn = true;
    lastSignedInEmail = email;
  }

  @override
  Future<void> sendPasswordResetCode(String email) async {
    _pendingCodeEmail = email;
  }

  @override
  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (_pendingCodeEmail != email || code != this.code) {
      throw const AuthServiceException(
        'This code has expired or is invalid. Request a new one.',
      );
    }
    _pendingCodeEmail = null;
    _passwords[email] = newPassword;
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
