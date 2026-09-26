import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_config.dart';

/// Supabase's auth event stream with errors removed.
///
/// Why: when an emailed link fails (expired, already used, or opened in a
/// different browser than the one that asked for it), supabase_flutter
/// pushes the `AuthException` into `onAuthStateChange`. That stream is a
/// replay stream, so every later listener gets the error too — and an
/// `await for` loop stops at the first error. Without this filter one bad
/// link left the app blind to later sign-ins until a page reload. The
/// errors themselves are surfaced once by [authLinkErrorProvider].
Stream<AuthState> authEventsIgnoringErrors(Stream<AuthState> events) =>
    events.handleError((Object _) {});

/// The signed-in Supabase user's id, or null when signed out or when the
/// build has no cloud config. The one shared "who is logged in" value —
/// like an auth context in React. Login screens change it (through the
/// Supabase client); sync and account screens watch it.
///
/// Tests override it: `authUserIdProvider.overrideWith((ref) => Stream.value('u1'))`.
final authUserIdProvider = StreamProvider<String?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    yield null;
    return;
  }
  yield client.auth.currentUser?.id;
  await for (final event in authEventsIgnoringErrors(
    client.auth.onAuthStateChange,
  )) {
    yield event.session?.user.id;
  }
});

/// Fires each time Supabase reports `AuthChangeEvent.passwordRecovery` —
/// i.e. the app was just opened from a password-reset email link, which
/// leaves the user in a short-lived recovery session. `app.dart` listens to
/// this to navigate to the "Set new password" screen; the Flutter
/// equivalent of a web app watching for a magic-link callback event once
/// the URL has been parsed.
///
/// Emits the event's timestamp (rather than `void`) so two recoveries in a
/// row are never treated as "no change" and silently dropped. No-op (never
/// emits) without a cloud config; tests override it directly, e.g. with
/// `FakeAuthService.passwordRecoveryEvents`.
final passwordRecoveryEventProvider = StreamProvider<DateTime>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return;
  await for (final event in authEventsIgnoringErrors(
    client.auth.onAuthStateChange,
  )) {
    if (event.event == AuthChangeEvent.passwordRecovery) yield DateTime.now();
  }
});

/// Emits a user-facing sentence each time an emailed auth link fails to
/// sign the user in (see [authLinkErrorMessage]); `app.dart` shows it in a
/// SnackBar. Never emits without a cloud config.
final authLinkErrorProvider = StreamProvider<String>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return;
  yield* authLinkErrors(client.auth.onAuthStateChange);
});

/// The error half of an auth event stream, mapped to friendly messages —
/// the counterpart of [authEventsIgnoringErrors]. Only `AuthException`s
/// are reported (those are what a failed link produces).
Stream<String> authLinkErrors(Stream<AuthState> events) => events.transform(
  StreamTransformer<AuthState, String>.fromHandlers(
    handleData: (_, _) {},
    handleError: (error, _, sink) {
      if (error is AuthException) sink.add(authLinkErrorMessage(error));
    },
  ),
);

/// Maps the ways an emailed link (sign-in, sign-up confirmation, password
/// reset) can fail to a sentence the user can act on.
///
/// Links use PKCE: the browser that *requested* the link keeps a secret
/// ("code verifier") that the link's code is exchanged with. Opening the
/// link in another browser — or another browser profile — can't finish the
/// sign-in. A sign-up confirmation still counts, though: Supabase confirms
/// the email before redirecting, so the user can simply sign in.
String authLinkErrorMessage(AuthException e) {
  final text = '${e.code ?? ''} ${e.statusCode ?? ''} ${e.message}'
      .toLowerCase();
  if (text.contains('code verifier')) {
    return 'This link was opened in a different browser than the one you '
        'requested it from. If you were confirming your email, it is '
        'confirmed — just sign in. Otherwise open the link in the same '
        'browser, or sign in with your password.';
  }
  if (text.contains('otp_expired') ||
      text.contains('expired') ||
      text.contains('invalid flow state') ||
      text.contains('flow_state')) {
    return 'This link has expired or was already used. Request a new one.';
  }
  return 'Could not sign in from the link: ${e.message}';
}
