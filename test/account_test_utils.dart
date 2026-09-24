import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/cloud/auth_state.dart';
import 'package:motolog/core/cloud/cloud_config.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/features/account/auth_service.dart';
import 'package:motolog/features/account/fake_auth_service.dart';

import 'helpers.dart';

/// A build that looks cloud-configured to `cloudConfigProvider.isConfigured`
/// (and `hasGoogle`, unless [withGoogle] is false) without touching a real
/// Supabase project — every actual network call goes through [auth]
/// instead.
const _configuredWithGoogle = CloudConfig(
  supabaseUrl: 'https://example.supabase.co',
  supabasePublishableKey: 'sb_publishable_test',
  googleWebClientId: 'web-client-id.apps.googleusercontent.com',
);

const _configuredNoGoogle = CloudConfig(
  supabaseUrl: 'https://example.supabase.co',
  supabasePublishableKey: 'sb_publishable_test',
);

/// The full app wired to [db] with [auth] standing in for Supabase, and
/// [userId] driving `authUserIdProvider` directly (tests flip sign-in state
/// this way rather than through a real auth stream).
Widget accountTestApp(
  AppDatabase db, {
  required FakeAuthService auth,
  String? userId,
  bool configured = true,
  bool withGoogle = true,
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    cloudConfigProvider.overrideWithValue(
      !configured
          ? const CloudConfig()
          : withGoogle
          ? _configuredWithGoogle
          : _configuredNoGoogle,
    ),
    authServiceProvider.overrideWithValue(auth),
    authUserIdProvider.overrideWith((ref) => Stream.value(userId)),
    // Bypasses supabaseClientProvider (never set up in tests) and routes
    // through the same fake whose `firePasswordRecovery()` a test can call.
    passwordRecoveryEventProvider.overrideWith(
      (ref) => auth.passwordRecoveryEvents,
    ),
  ],
  child: const MotoLogApp(),
);

/// Pumps the app on a tall screen and opens More → My account.
Future<AppDatabase> openAccountScreen(
  WidgetTester tester, {
  required FakeAuthService auth,
  String? userId,
  bool configured = true,
  bool withGoogle = true,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = testDatabase();
  await tester.pumpWidget(
    accountTestApp(
      db,
      auth: auth,
      userId: userId,
      configured: configured,
      withGoogle: withGoogle,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('My account'));
  await tester.pumpAndSettle();
  return db;
}

/// Unmounts the app so drift's stream-cleanup timer fires, then closes [db].
Future<void> closeAccountApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
  await tester.runAsync(db.close);
}
