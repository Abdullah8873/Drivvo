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

  group('isPkceAuthCallback', () {
    bool check(String link) => isPkceAuthCallback(Uri.parse(link));

    test('PKCE code and error callbacks are handled', () {
      expect(
        check('com.abdullah8873.motolog://login-callback?code=abc'),
        isTrue,
      );
      expect(check('http://localhost:8085/?code=abc'), isTrue);
      expect(
        check(
          'com.abdullah8873.motolog://login-callback'
          '#error=access_denied&error_code=otp_expired',
        ),
        isTrue,
      );
      expect(check('http://localhost:8085/?error_description=Expired'), isTrue);
    });

    test("token links are refused (they'd be someone else's session)", () {
      expect(
        check(
          'com.abdullah8873.motolog://login-callback'
          '#access_token=x&refresh_token=y&expires_in=3600&token_type=bearer',
        ),
        isFalse,
      );
      expect(
        check('http://localhost:8085/?access_token=x&refresh_token=y'),
        isFalse,
      );
      // Even next to a code: nothing token-shaped gets in.
      expect(check('http://localhost:8085/?code=a#access_token=x'), isFalse);
    });

    test('ordinary links and malformed ones are ignored', () {
      expect(check('com.abdullah8873.motolog://login-callback'), isFalse);
      expect(check('http://localhost:8085/history?tab=1'), isFalse);
      expect(check('http://localhost:8085/?code=%E0%A4%A'), isFalse);
    });
  });
}
