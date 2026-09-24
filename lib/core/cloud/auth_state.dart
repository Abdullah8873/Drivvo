import 'package:flutter_riverpod/flutter_riverpod.dart';

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
