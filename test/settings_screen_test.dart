import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/files/file_sharer.dart';
import 'package:motolog/core/notifications/notification_providers.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/core/settings/app_settings.dart';
import 'package:motolog/features/settings/settings_screen.dart';

import 'catalog_test_utils.dart';
import 'helpers.dart';
import 'notification_controller_test.dart' show FakeNotificationScheduler;

Future<AppDatabase> openSettings(WidgetTester tester) =>
    openFromMore(tester, 'Settings');

/// Same flow as [openSettings], but with [fileSharerProvider] overridden so
/// "Create backup file" can be tested without touching a real share sheet.
Future<AppDatabase> openSettingsWithFakeSharer(
  WidgetTester tester,
  FakeFileSharer sharer,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = testDatabase();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileSharerProvider.overrideWithValue(sharer),
      ],
      child: const MotoLogApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
  return db;
}

/// Settings as stored in the database (proves the change was persisted).
Future<AppSettings> stored(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => loadSettings(db)))!;

void main() {
  testWidgets('shows sections and default values', (tester) async {
    final db = await openSettings(tester);
    for (final text in [
      'FORMATS',
      'UNITS',
      'REMINDERS',
      'Light',
      '1987-11-17',
      'PKR1,000,000.00',
      '42.357 L',
      'km/L',
      "Show reminder 500 km/mi in advance (in each vehicle's unit)",
      'Show reminder 30 days in advance',
      '10:30',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await closeApp(tester, db);
  });

  testWidgets('radio dialog changes theme and efficiency, and persists', (
    tester,
  ) async {
    final db = await openSettings(tester);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(find.text('Use system default'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Fuel efficiency'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('L/100km'));
    await tester.pumpAndSettle();
    expect(find.text('L/100km'), findsOneWidget);

    // CANCEL leaves the value alone.
    await tester.tap(find.text('Date format'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('1987-11-17'), findsOneWidget);

    final s = await stored(tester, db);
    expect(s.themeMode, ThemeMode.dark);
    expect(s.efficiencyFormat, EfficiencyFormat.litersPer100Km);
    await closeApp(tester, db);
  });

  testWidgets('currency picker, checkboxes and number dialog', (tester) async {
    final db = await openSettings(tester);

    await tester.tap(find.text('Currency format'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'us dollar');
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD - US Dollar'));
    await tester.pumpAndSettle();
    expect(find.text('USD1,000,000.00'), findsOneWidget);

    await tester.tap(find.text('Display decimal digits'));
    await tester.pumpAndSettle();
    expect(find.text('USD1,000,000'), findsOneWidget);

    await tester.tap(find.text('Vibrate when notifying'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Distance in advance'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '800');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      find.text("Show reminder 800 km/mi in advance (in each vehicle's unit)"),
      findsOneWidget,
    );

    final s = await stored(tester, db);
    expect(s.currencyCode, 'USD');
    expect(s.showDecimals, isFalse);
    expect(s.vibrate, isFalse);
    expect(s.reminderDistanceAhead, 800);
    await closeApp(tester, db);
  });

  testWidgets('distance unit row explains it is set per vehicle', (
    tester,
  ) async {
    final db = await openSettings(tester);
    await tester.tap(find.text('km / Mile / Time'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Distance unit is set per vehicle. Edit your vehicle to change it.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('currency picker shows the current currency selected', (
    tester,
  ) async {
    final db = await openSettings(tester);
    await tester.tap(find.text('Currency format'));
    await tester.pumpAndSettle();

    // Default currency (PKR) is checked in the picker.
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'PKR - Pakistani Rupee'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );

    // Picking a different currency and reopening moves the check mark.
    await tester.enterText(find.byType(TextField), 'us dollar');
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD - US Dollar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Currency format'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'USD - US Dollar'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await closeApp(tester, db);
  });

  testWidgets('number dialog rejects blank input with an inline error', (
    tester,
  ) async {
    final db = await openSettings(tester);
    await tester.tap(find.text('Distance in advance'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole number ≥ 0'), findsOneWidget);
    // Bad input doesn't close the dialog or change anything.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect((await stored(tester, db)).reminderDistanceAhead, 500);

    // Fixing the value clears the error and OK now applies it.
    await tester.enterText(find.byType(TextField), '250');
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole number ≥ 0'), findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect((await stored(tester, db)).reminderDistanceAhead, 250);
    await closeApp(tester, db);
  });

  testWidgets('send test notification row calls the scheduler', (tester) async {
    // Tall viewport so the row (near the bottom of a long list) doesn't
    // need scrolling into view first.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = testDatabase();
    addTearDown(db.close);
    final scheduler = FakeNotificationScheduler();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(scheduler.showNowCalled, isFalse);
    await tester.tap(find.text('Send test notification'));
    await tester.pumpAndSettle();
    expect(scheduler.showNowCalled, isTrue);
    await unmountApp(tester);
  });

  testWidgets('shows the Backup & restore section', (tester) async {
    final db = await openSettings(tester);
    expect(find.text('BACKUP & RESTORE'), findsOneWidget);
    expect(find.text('Create backup file'), findsOneWidget);
    expect(find.text('Restore from backup'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('Create backup file shares a .json file', (tester) async {
    final sharer = FakeFileSharer();
    final db = await openSettingsWithFakeSharer(tester, sharer);

    await tester.tap(find.text('Create backup file'));
    await tester.pumpAndSettle();

    expect(sharer.callCount, 1);
    expect(
      sharer.filename,
      matches(RegExp(r'^motolog-backup-\d{8}-\d{4}\.json$')),
    );
    expect(sharer.mimeType, 'application/json');
    expect(sharer.bytes, isNotNull);
    await closeApp(tester, db);
  });
}
