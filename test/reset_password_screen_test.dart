import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/features/account/fake_auth_service.dart';

import 'account_test_utils.dart';

void main() {
  testWidgets(
    'sending a reset link shows the "check your email" state, with resend',
    (tester) async {
      final auth = FakeAuthService(
        passwordsByEmail: {'ada@example.com': 'old-password'},
      );
      final db = await openAccountScreen(tester, auth: auth);
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'ada@example.com',
      );
      await tester.tap(find.text('SEND RESET LINK'));
      await tester.pumpAndSettle();

      expect(auth.lastPasswordResetEmail, 'ada@example.com');
      expect(
        find.textContaining('Check your email for a reset link'),
        findsOneWidget,
      );
      // The password is untouched until the link is opened and the "Set
      // new password" screen submits (see new_password_screen_test.dart).
      expect(
        await _signInWorks(auth, 'ada@example.com', 'old-password'),
        isTrue,
      );

      // Resend cooldown starts disabled; only the countdown label shows.
      expect(find.textContaining('Resend email ('), findsOneWidget);
      await closeAccountApp(tester, db);
    },
  );

  testWidgets('invalid email shows a validation error and does not send', (
    tester,
  ) async {
    final auth = FakeAuthService();
    final db = await openAccountScreen(tester, auth: auth);
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.text('SEND RESET LINK'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(auth.lastPasswordResetEmail, isNull);
    await closeAccountApp(tester, db);
  });
}

Future<bool> _signInWorks(
  FakeAuthService auth,
  String email,
  String password,
) async {
  try {
    await auth.signInWithPassword(email: email, password: password);
    return true;
  } catch (_) {
    return false;
  }
}
