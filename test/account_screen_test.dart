import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/features/account/auth_service.dart';
import 'package:motolog/features/account/fake_auth_service.dart';

import 'account_test_utils.dart';

void main() {
  testWidgets('offline build shows the "not configured" explanation', (
    tester,
  ) async {
    final db = await openAccountScreen(
      tester,
      auth: FakeAuthService(),
      configured: false,
    );
    expect(find.textContaining('not configured in this build'), findsOneWidget);
    expect(find.text('SIGN IN'), findsNothing);
    await closeAccountApp(tester, db);
  });

  testWidgets('signed-out account screen explains cloud is optional', (
    tester,
  ) async {
    final db = await openAccountScreen(tester, auth: FakeAuthService());
    expect(
      find.textContaining('The app works fully without an account'),
      findsOneWidget,
    );
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    await closeAccountApp(tester, db);
  });

  testWidgets('signed-in view loads the profile and saves edits', (
    tester,
  ) async {
    final auth = FakeAuthService(
      profile: const AccountProfile(firstName: 'Ada', email: 'ada@example.com'),
    )..signedIn = true;
    final db = await openAccountScreen(tester, auth: auth, userId: 'u1');

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);

    final lastNameField = find.ancestor(
      of: find.text('Last name'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(lastNameField, 'Lovelace');
    await tester.pumpAndSettle();

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(auth.profile.lastName, 'Lovelace');
    await closeAccountApp(tester, db);
  });

  testWidgets('sign out asks for confirmation then signs out', (tester) async {
    final auth = FakeAuthService()..signedIn = true;
    final db = await openAccountScreen(tester, auth: auth, userId: 'u1');

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.text('SIGN OUT'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalled, isTrue);
    await closeAccountApp(tester, db);
  });

  testWidgets('delete account requires typing DELETE', (tester) async {
    final auth = FakeAuthService()..signedIn = true;
    final db = await openAccountScreen(tester, auth: auth, userId: 'u1');

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    final confirmButton = find.widgetWithText(TextButton, 'DELETE ACCOUNT');
    expect(tester.widget<TextButton>(confirmButton).onPressed, isNull);

    // Scoped to the dialog's own field — the screen behind it also has
    // several TextFormFields (each wrapping a TextField internally).
    final typeField = find.ancestor(
      of: find.text('Type DELETE'),
      matching: find.byType(TextField),
    );
    await tester.enterText(typeField, 'delete');
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(confirmButton).onPressed, isNull);

    await tester.enterText(typeField, 'DELETE');
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(confirmButton).onPressed, isNotNull);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(auth.deleteAccountCalled, isTrue);
    expect(auth.signOutCalled, isTrue);
    await closeAccountApp(tester, db);
  });
}
