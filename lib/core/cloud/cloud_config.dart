import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloud (Supabase + Google sign-in) settings, baked in at build time with
/// `--dart-define-from-file=env/cloud.json` — the Flutter version of a
/// `.env` file read by the bundler (`import.meta.env.VITE_...`).
///
/// `env/cloud.json` is git-ignored; `env/cloud.example.json` shows the keys.
/// Only public values belong here: the Supabase URL and **publishable** key
/// (`sb_publishable_...`, or a legacy "anon" key; safe in a client because
/// row-level security protects the data) and Google OAuth **client IDs**.
/// The Supabase secret / service-role key and the Google client secret
/// never go in the app.
///
/// With no config the app runs fully offline and hides every cloud feature
/// (login is optional — see docs/PLAN.md, M6).
class CloudConfig {
  const CloudConfig({
    this.supabaseUrl = '',
    this.supabasePublishableKey = '',
    this.googleWebClientId = '',
    this.googleAndroidClientId = '',
  });

  /// Reads the `--dart-define` values compiled into this build.
  const CloudConfig.fromEnvironment()
    : supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey = const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      googleWebClientId = const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      googleAndroidClientId = const String.fromEnvironment(
        'GOOGLE_ANDROID_CLIENT_ID',
      );

  final String supabaseUrl;
  final String supabasePublishableKey;

  /// OAuth client of type "Web application" — also the `serverClientId`
  /// for native Android sign-in (Supabase verifies the ID token against it).
  final String googleWebClientId;

  /// OAuth client of type "Android" (package name + SHA-1).
  final String googleAndroidClientId;

  /// True when this build can talk to Supabase at all.
  bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// True when Google sign-in can be offered.
  bool get hasGoogle => isConfigured && googleWebClientId.isNotEmpty;
}

/// The build's cloud config. Tests override it (e.g. with a configured
/// `CloudConfig(...)` plus fake auth/remote providers).
final cloudConfigProvider = Provider<CloudConfig>(
  (ref) => const CloudConfig.fromEnvironment(),
);

/// The Supabase client, or null when the build has no cloud config (or in
/// tests). Everything cloud-related must handle null = "offline-only build".
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!ref.watch(cloudConfigProvider).isConfigured) return null;
  return Supabase.instance.client;
});

/// Call once in `main()` before `runApp`. No-op without config.
Future<void> initCloud(CloudConfig config) async {
  if (!config.isConfigured) return;
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
  );
}

/// Where Supabase should send the browser back after a sign-in link,
/// sign-up confirmation link, or password-reset link is clicked — the
/// `emailRedirectTo`/`redirectTo` argument every link-sending call needs.
///
/// On web this is the app's own origin (`Uri.base.origin`), so it resolves
/// to whichever allow-listed preview port (8085 or 8086) the link was
/// requested from — the Flutter equivalent of `window.location.origin`.
/// supabase_flutter then picks the session up from the URL automatically
/// when the app reloads there (`detectSessionInUri`, on by default).
///
/// On other platforms there's no app link registered yet, so this returns
/// null and Supabase falls back to the project's Site URL.
// TODO(android): deep link — register an app link (e.g.
// `https://motolog.app/auth-callback` or a custom scheme) and return it
// here so a link opened on Android returns straight to the app.
String? authRedirectUrl() => kIsWeb ? Uri.base.origin : null;
