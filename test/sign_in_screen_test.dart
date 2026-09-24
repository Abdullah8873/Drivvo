import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/features/account/fake_auth_service.dart';

import 'account_test_utils.dart';

void main() {
  testWidgets('Google button hidden when the build has no Google client', (
    tester,
  ) async {
    final db = await openAccountScreen(
      tester,
      auth: FakeAuthService(),
      withGoogle: false,
    );
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsNothing);
    await closeAccountApp(tester, db);
  });

  testWidgets('Google button shown when the build has a Google client', (
    tester,
  ) async {
    final db = await openAccountScreen(tester, auth: FakeAuthService());
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    await closeAccountApp(tester, db);
  });

  testWidgets('password sign-in succeeds and pops back to My account', (
    tester,
  ) async {
    final auth = FakeAuthService(
      passwordsByEmail: {'ada@example.com': 'correcthorse'},
    );
    final db = await openAccountScreen(tester, auth: auth);
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'ada@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'correcthorse');
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(auth.signedIn, isTrue);
    expect(auth.lastSignedInEmail, 'ada@example.com');
    // Popped back to the (still signed-out, since authUserIdProvider is
    // fixed in this test) My account screen.
    expect(find.text('My account'), findsOneWidget);
    await closeAccountApp(tester, db);
  });

  testWidgets('wrong password shows an inline error and stays put', (
    tester,
  ) async {
    final auth = FakeAuthService(
      passwordsByEmail: {'ada@example.com': 'correcthorse'},
    );
    final db = await openAccountScreen(tester, auth: auth);
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'ada@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(auth.signedIn, isFalse);
    // Still on the sign-in screen.
    expect(find.text('Forgot password?'), findsOneWidget);
    await closeAccountApp(tester, db);
  });

  testWidgets(
    'email-a-link flow: sending shows the "check your email" state, with '
    'resend',
    (tester) async {
      final auth = FakeAuthService();
      final db = await openAccountScreen(tester, auth: auth);
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'coder@example.com',
      );
      await tester.tap(find.text('Email me a sign-in link'));
      await tester.pumpAndSettle();

      expect(auth.lastSignInLinkEmail, 'coder@example.com');
      expect(
        find.textContaining('Check your email — we sent a sign-in link to'),
        findsOneWidget,
      );
      // Not signed in yet — that only happens once the link is opened.
      expect(auth.signedIn, isFalse);

      // Resend cooldown starts disabled; only the countdown label shows.
      expect(find.textContaining('Resend email ('), findsOneWidget);

      await tester.tap(find.text('Use a different email'));
      await tester.pumpAndSettle();
      expect(find.text('Forgot password?'), findsOneWidget);
      await closeAccountApp(tester, db);
    },
  );

  testWidgets('empty email shows an inline error instead of sending', (
    tester,
  ) async {
    final auth = FakeAuthService();
    final db = await openAccountScreen(tester, auth: auth);
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Email me a sign-in link'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email first.'), findsOneWidget);
    expect(auth.lastSignInLinkEmail, isNull);
    await closeAccountApp(tester, db);
  });
}
