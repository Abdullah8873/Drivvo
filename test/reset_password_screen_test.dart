import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/features/account/fake_auth_service.dart';

import 'account_test_utils.dart';

void main() {
  testWidgets('email → code → new password resets the password', (
    tester,
  ) async {
    final auth = FakeAuthService(
      passwordsByEmail: {'ada@example.com': 'old-password'},
      code: '999888',
    );
    final db = await openAccountScreen(tester, auth: auth);
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'ada@example.com');
    await tester.tap(find.text('SEND CODE'));
    await tester.pumpAndSettle();

    expect(find.textContaining('choose a new password'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '999888');
    await tester.enterText(fields.at(1), 'new-password1');
    await tester.tap(find.text('RESET PASSWORD'));
    await tester.pumpAndSettle();

    // Old password no longer works; the new one does.
    expect(
      await _signInWorks(auth, 'ada@example.com', 'old-password'),
      isFalse,
    );
    expect(
      await _signInWorks(auth, 'ada@example.com', 'new-password1'),
      isTrue,
    );
    await closeAccountApp(tester, db);
  });

  testWidgets('an invalid code shows an inline error', (tester) async {
    final auth = FakeAuthService(
      passwordsByEmail: {'ada@example.com': 'old-password'},
      code: '999888',
    );
    final db = await openAccountScreen(tester, auth: auth);
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'ada@example.com');
    await tester.tap(find.text('SEND CODE'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '000000');
    await tester.enterText(fields.at(1), 'new-password1');
    await tester.tap(find.text('RESET PASSWORD'));
    await tester.pumpAndSettle();

    expect(
      find.text('This code has expired or is invalid. Request a new one.'),
      findsOneWidget,
    );
    expect(await _signInWorks(auth, 'ada@example.com', 'old-password'), isTrue);
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
