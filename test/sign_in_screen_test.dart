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

  testWidgets('email-code flow: send, then verify signs in', (tester) async {
    final auth = FakeAuthService(code: '654321');
    final db = await openAccountScreen(tester, auth: auth);
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'coder@example.com',
    );
    await tester.tap(find.text('Email me a code instead'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Enter the 6-digit code we emailed to'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).first, '654321');
    await tester.tap(find.text('VERIFY'));
    await tester.pumpAndSettle();

    expect(auth.signedIn, isTrue);
    expect(auth.lastSignedInEmail, 'coder@example.com');
    await closeAccountApp(tester, db);
  });

  testWidgets('wrong code shows an error and does not sign in', (tester) async {
    final auth = FakeAuthService(code: '654321');
    final db = await openAccountScreen(tester, auth: auth);
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'coder@example.com',
    );
    await tester.tap(find.text('Email me a code instead'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '000000');
    await tester.tap(find.text('VERIFY'));
    await tester.pumpAndSettle();

    expect(
      find.text('This code has expired or is invalid. Request a new one.'),
      findsOneWidget,
    );
    expect(auth.signedIn, isFalse);
    await closeAccountApp(tester, db);
  });
}
