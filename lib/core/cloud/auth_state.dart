import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_config.dart';

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
  await for (final event in client.auth.onAuthStateChange) {
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
  await for (final event in client.auth.onAuthStateChange) {
    if (event.event == AuthChangeEvent.passwordRecovery) yield DateTime.now();
  }
});
