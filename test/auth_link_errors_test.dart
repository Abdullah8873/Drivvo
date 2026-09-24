import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/cloud/auth_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  /// A stream shaped like Supabase's after a failed link: an error, then a
  /// later sign-in event.
  Stream<AuthState> errorThenSignIn() {
    final controller = StreamController<AuthState>();
    controller
      ..addError(
        AuthException('Code verifier could not be found in local storage.'),
      )
      ..add(const AuthState(AuthChangeEvent.signedIn, null))
      ..close();
    return controller.stream;
  }

  test('auth events keep flowing after a link error', () async {
    final events = await authEventsIgnoringErrors(errorThenSignIn()).toList();
    expect(events.map((e) => e.event), [AuthChangeEvent.signedIn]);
  });

  test('link errors are reported once, as friendly text', () async {
    final messages = await authLinkErrors(errorThenSignIn()).toList();
    expect(messages, hasLength(1));
    expect(messages.single, contains('different browser'));
  });

  test('non-auth errors are not reported', () async {
    final controller = StreamController<AuthState>()
      ..addError(StateError('boom'))
      ..close();
    expect(await authLinkErrors(controller.stream).toList(), isEmpty);
  });

  group('authLinkErrorMessage', () {
    test('expired link from the URL error params', () {
      final e = AuthException(
        'Email link is invalid or has expired',
        statusCode: 'otp_expired',
      );
      expect(authLinkErrorMessage(e), contains('expired or was already used'));
    });

    test('reused code (flow state gone)', () {
      final e = AuthException(
        'invalid flow state, no valid flow state found',
        code: 'flow_state_not_found',
      );
      expect(authLinkErrorMessage(e), contains('expired or was already used'));
    });

    test('anything else keeps the server message', () {
      final e = AuthException('Something odd');
      expect(authLinkErrorMessage(e), contains('Something odd'));
    });
  });
}
