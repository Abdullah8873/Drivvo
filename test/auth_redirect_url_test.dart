import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/cloud/cloud_config.dart';

void main() {
  group('authRedirectUrl', () {
    test('web returns the page origin (whatever port it runs on)', () {
      expect(
        authRedirectUrl(
          isWeb: true,
          base: Uri.parse('http://localhost:8086/history?x=1'),
        ),
        'http://localhost:8086',
      );
    });

    test('web wins even when the host OS is Android (mobile browser)', () {
      expect(
        authRedirectUrl(
          isWeb: true,
          platform: TargetPlatform.android,
          base: Uri.parse('https://motolog.example'),
        ),
        'https://motolog.example',
      );
    });

    test('Android and iOS apps use the custom-scheme deep link', () {
      for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(
          authRedirectUrl(isWeb: false, platform: p),
          'com.abdullah8873.motolog://login-callback',
        );
      }
      expect(
        mobileAuthRedirectUrl,
        'com.abdullah8873.motolog://login-callback',
      );
    });

    test('desktop has no deep link, so Supabase uses the Site URL', () {
      for (final p in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        expect(authRedirectUrl(isWeb: false, platform: p), isNull);
      }
    });
  });
}
