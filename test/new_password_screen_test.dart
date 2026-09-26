import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/features/account/fake_auth_service.dart';

import 'account_test_utils.dart';
import 'helpers.dart';

/// Pumps the full app already signed in, then simulates the app being
/// reopened from a password-reset email link.
Future<AppDatabase> _openViaPasswordRecovery(
  WidgetTester tester, {
  required FakeAuthService auth,
}) async {
  final db = testDatabase();
  await tester.pumpWidget(accountTestApp(db, auth: auth, userId: 'u1'));
  await tester.pumpAndSettle();

  auth.firePasswordRecovery();
  await tester.pumpAndSettle();
  return db;
}

void main() {
  testWidgets(
    'a password-recovery event routes to Set new password, and updating '
    'goes back to My account',
    (tester) async {
      final auth = FakeAuthService()..signedIn = true;
      final db = await _openViaPasswordRecovery(tester, auth: auth);

      expect(find.text('Set new password'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'new-password1');
      await tester.enterText(fields.at(1), 'new-password1');
      await tester.tap(find.text('UPDATE PASSWORD'));
      await tester.pumpAndSettle();

      expect(auth.lastUpdatedPassword, 'new-password1');
      expect(find.text('Password updated'), findsOneWidget);
      expect(find.text('My account'), findsOneWidget);

      await unmountApp(tester);
      await tester.runAsync(db.close);
    },
  );

  testWidgets('rejects a password shorter than 8 characters', (tester) async {
    final auth = FakeAuthService()..signedIn = true;
    final db = await _openViaPasswordRecovery(tester, auth: auth);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'short1');
    await tester.enterText(fields.at(1), 'short1');
    await tester.tap(find.text('UPDATE PASSWORD'));
    await tester.pumpAndSettle();

    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(auth.lastUpdatedPassword, isNull);

    await unmountApp(tester);
    await tester.runAsync(db.close);
  });

  testWidgets('rejects mismatched passwords', (tester) async {
    final auth = FakeAuthService()..signedIn = true;
    final db = await _openViaPasswordRecovery(tester, auth: auth);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'longenough1');
    await tester.enterText(fields.at(1), 'longenough2');
    await tester.tap(find.text('UPDATE PASSWORD'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(auth.lastUpdatedPassword, isNull);

    await unmountApp(tester);
    await tester.runAsync(db.close);
  });
}
