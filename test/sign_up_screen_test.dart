import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/features/account/fake_auth_service.dart';

import 'account_test_utils.dart';

/// Opens More → My account → Create account (from the signed-out view).
Future<AppDatabase> _openSignUp(
  WidgetTester tester, {
  required FakeAuthService auth,
}) async {
  final db = await openAccountScreen(tester, auth: auth);
  await tester.tap(find.text('CREATE ACCOUNT'));
  await tester.pumpAndSettle();
  return db;
}

void main() {
  testWidgets('rejects a password shorter than 8 characters', (tester) async {
    final auth = FakeAuthService();
    final db = await _openSignUp(tester, auth: auth);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'new@example.com');
    await tester.enterText(fields.at(1), 'short1');
    await tester.enterText(fields.at(2), 'short1');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(auth.signedIn, isFalse);
    await closeAccountApp(tester, db);
  });

  testWidgets('rejects mismatched passwords', (tester) async {
    final auth = FakeAuthService();
    final db = await _openSignUp(tester, auth: auth);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'new@example.com');
    await tester.enterText(fields.at(1), 'longenough1');
    await tester.enterText(fields.at(2), 'longenough2');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(auth.signedIn, isFalse);
    await closeAccountApp(tester, db);
  });

  testWidgets(
    'sign-up with no confirmation required signs in immediately and pops '
    'back',
    (tester) async {
      final auth = FakeAuthService();
      final db = await _openSignUp(tester, auth: auth);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'new@example.com');
      await tester.enterText(fields.at(1), 'longenough1');
      await tester.enterText(fields.at(2), 'longenough1');
      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();

      expect(auth.signedIn, isTrue);
      expect(auth.lastSignedInEmail, 'new@example.com');
      expect(find.text('My account'), findsOneWidget);
      await closeAccountApp(tester, db);
    },
  );

  testWidgets('sign-up requiring confirmation shows "confirm your email", with '
      'resend', (tester) async {
    final auth = FakeAuthService(requireSignUpConfirmation: true);
    final db = await _openSignUp(tester, auth: auth);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'confirm@example.com');
    await tester.enterText(fields.at(1), 'longenough1');
    await tester.enterText(fields.at(2), 'longenough1');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(auth.signedIn, isFalse);
    expect(find.textContaining('Confirm your email'), findsOneWidget);
    expect(
      find.textContaining("After confirming you'll be signed in"),
      findsOneWidget,
    );

    // Resend starts on a 60s cooldown — fast-forward the fake test clock
    // past it before tapping.
    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.text('Resend email'));
    await tester.pumpAndSettle();
    expect(auth.lastResendConfirmationEmail, 'confirm@example.com');
    // Still not signed in — nothing short of opening the emailed link
    // completes this flow.
    expect(auth.signedIn, isFalse);
    await closeAccountApp(tester, db);
  });
}
